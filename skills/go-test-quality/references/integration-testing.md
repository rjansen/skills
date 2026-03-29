# Integration Testing

## Testcontainers

Testcontainers-go spins up real databases in Docker for integration tests:

```go
import (
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func setupPostgres(t *testing.T) *sql.DB {
    t.Helper()
    ctx := context.Background()

    pgContainer, err := postgres.Run(ctx,
        "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("ready to accept connections").
                WithOccurrence(2).
                WithStartupTimeout(30*time.Second),
        ),
    )
    if err != nil {
        t.Fatalf("start postgres: %v", err)
    }
    t.Cleanup(func() { pgContainer.Terminate(ctx) })

    connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
    if err != nil {
        t.Fatalf("connection string: %v", err)
    }

    db, err := sql.Open("postgres", connStr)
    if err != nil {
        t.Fatalf("connect: %v", err)
    }
    t.Cleanup(func() { db.Close() })

    return db
}
```

### Share container across tests

Use `TestMain` to start the container once for all tests in the package:

```go
var testDB *sql.DB

func TestMain(m *testing.M) {
    ctx := context.Background()
    pgContainer, _ := postgres.Run(ctx, "postgres:16-alpine", ...)
    connStr, _ := pgContainer.ConnectionString(ctx, "sslmode=disable")
    testDB, _ = sql.Open("postgres", connStr)

    code := m.Run()

    pgContainer.Terminate(ctx)
    os.Exit(code)
}
```

### Other container modules

Testcontainers has modules for Redis, MySQL, MongoDB, Kafka, Elasticsearch, and more:

```go
import "github.com/testcontainers/testcontainers-go/modules/redis"

redisContainer, _ := redis.Run(ctx, "redis:7-alpine")
```

## Build Tags vs testing.Short()

Two approaches to gate integration tests:

### Build tags

```go
//go:build integration

package store_test

func TestPostgresStore_Create(t *testing.T) { ... }
```

```bash
go test ./...                          # skips integration tests
go test -tags=integration ./...        # includes integration tests
```

### testing.Short()

```go
func TestPostgresStore_Create(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }
    // ...
}
```

```bash
go test -short ./...   # skips integration tests
go test ./...          # runs everything
```

**Recommendation:** Use build tags for clean separation — integration test files are completely
excluded from normal builds. Use `testing.Short()` when the distinction is less strict.

## Database Test Fixtures

### Transaction rollback pattern

Wrap each test in a transaction that rolls back — guarantees clean state:

```go
func withTestTx(t *testing.T, db *sql.DB, fn func(tx *sql.Tx)) {
    t.Helper()
    tx, err := db.Begin()
    if err != nil {
        t.Fatalf("begin tx: %v", err)
    }
    t.Cleanup(func() { tx.Rollback() })
    fn(tx)
}

func TestStore_Create(t *testing.T) {
    withTestTx(t, testDB, func(tx *sql.Tx) {
        store := NewStore(tx)
        err := store.Create(ctx, &User{Name: "Alice"})
        // assert...
    })
}
```

### Seed data helpers

Create reusable seed functions for common test scenarios:

```go
func seedUsers(t *testing.T, tx *sql.Tx, count int) []*User {
    t.Helper()
    users := make([]*User, count)
    for i := range count {
        u := &User{
            ID:   fmt.Sprintf("user-%d", i),
            Name: fmt.Sprintf("User %d", i),
        }
        _, err := tx.Exec("INSERT INTO users (id, name) VALUES ($1, $2)", u.ID, u.Name)
        if err != nil {
            t.Fatalf("seed user: %v", err)
        }
        users[i] = u
    }
    return users
}
```

### Migration in tests

Run migrations before tests to ensure schema is up to date:

```go
func TestMain(m *testing.M) {
    // ... start container, connect ...
    if err := runMigrations(testDB); err != nil {
        log.Fatalf("migrations: %v", err)
    }
    os.Exit(m.Run())
}
```

## Full-Stack HTTP Integration Tests

Test the complete request/response cycle including routing, middleware, serialization:

```go
func TestAPI(t *testing.T) {
    db := setupPostgres(t)
    store := store.New(db)
    svc := service.New(store)
    handler := handler.New(svc)

    srv := httptest.NewServer(handler.Routes())
    t.Cleanup(srv.Close)

    t.Run("create and get user", func(t *testing.T) {
        // Create
        body := `{"name": "Alice", "email": "alice@example.com"}`
        resp, err := http.Post(srv.URL+"/users", "application/json", strings.NewReader(body))
        if err != nil {
            t.Fatal(err)
        }
        if resp.StatusCode != http.StatusCreated {
            t.Fatalf("create status = %d, want %d", resp.StatusCode, http.StatusCreated)
        }

        var created User
        json.NewDecoder(resp.Body).Decode(&created)
        resp.Body.Close()

        // Get
        resp, err = http.Get(srv.URL + "/users/" + created.ID)
        if err != nil {
            t.Fatal(err)
        }
        if resp.StatusCode != http.StatusOK {
            t.Fatalf("get status = %d, want %d", resp.StatusCode, http.StatusOK)
        }
        resp.Body.Close()
    })
}
```

## CI Configuration

Integration tests in CI typically need Docker:

```yaml
# GitHub Actions
jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go test -tags=integration -v ./...
```

Docker is available by default on GitHub Actions `ubuntu-latest` runners.

## Fuzz Testing

Fuzz testing generates random inputs to find edge cases in parsers and validators.

### Basic fuzz test

```go
func FuzzParseConfig(f *testing.F) {
    // Seed corpus — representative inputs
    f.Add([]byte(`{"key": "value"}`))
    f.Add([]byte(`{}`))
    f.Add([]byte(``))

    f.Fuzz(func(t *testing.T, data []byte) {
        cfg, err := ParseConfig(data)
        if err != nil {
            return // expected for random input
        }
        // Invariant: if parsing succeeds, re-serialization should round-trip
        out, err := json.Marshal(cfg)
        if err != nil {
            t.Fatalf("marshal succeeded parse but failed serialize: %v", err)
        }
        cfg2, err := ParseConfig(out)
        if err != nil {
            t.Fatalf("round-trip failed: %v", err)
        }
        if !reflect.DeepEqual(cfg, cfg2) {
            t.Fatalf("round-trip mismatch")
        }
    })
}
```

### Running fuzz tests

```bash
go test -fuzz=FuzzParseConfig -fuzztime=30s   # fuzz for 30 seconds
go test -fuzz=FuzzParseConfig -fuzztime=1000x  # run 1000 iterations
```

### Corpus management

Failing inputs are saved to `testdata/fuzz/<FuzzTestName>/`:

```
testdata/fuzz/FuzzParseConfig/
├── seed/               # manually added seed inputs
└── corpus/             # auto-discovered failing inputs
```

Commit the `testdata/fuzz/` directory — failing inputs become regression tests that run with
every `go test` invocation.

### When to fuzz

- Parsers (JSON, YAML, custom formats)
- Validators (email, URL, custom rules)
- Encoders/decoders (serialization round-trips)
- Functions handling untrusted input

### When NOT to fuzz

- Business logic with well-known inputs
- CRUD operations
- UI handlers
