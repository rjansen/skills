---
name: go-test-quality
description: >
  This skill should be used when the user asks to "write Go tests",
  "improve test quality", "add tests for this function", "set up test helpers",
  "mock a dependency", "write integration tests", "fuzz test this",
  "use httptest", "set up testcontainers", "organize test files",
  or mentions t.Helper, t.Cleanup, t.Parallel, TestMain, golden files,
  subtests, test fixtures, or test design patterns. Covers all Go testing
  patterns except table-driven tests (use go-test-table-driven for those).
---

# Go Test Quality

Tests are production code that happen to run with `go test`. Apply the same design discipline:
clear naming, focused scope, maintainable structure. This skill covers test design philosophy,
helpers, fixtures, HTTP testing, and organization patterns.

## Test Design Philosophy

**Test behavior, not implementation.** A test that breaks when internal method names change but
the behavior is unchanged is testing the wrong thing. Assert on observable outcomes: return
values, state changes, side effects.

**Name tests like bug reports.** The test name should describe the scenario and expected outcome
so a failure message immediately tells what broke:

```go
func TestOrderService_Create_ReturnsErrorWhenInventoryInsufficient(t *testing.T) { ... }
func TestParseConfig_EmptyInput_ReturnsDefault(t *testing.T) { ... }
```

Pattern: `Test<Unit>_<Scenario>_<Expected>` or `Test<Unit>/<Scenario>` with subtests.

**One logical assertion per test.** A test may have multiple `assert` calls, but they should
verify one logical concept. If a test fails, it should be obvious which behavior is broken.

## Subtests with t.Run

Group related scenarios under a parent test for organization and selective execution:

```go
func TestUserService_Create(t *testing.T) {
    t.Run("valid user", func(t *testing.T) {
        // ...
    })
    t.Run("duplicate email returns ErrAlreadyExists", func(t *testing.T) {
        // ...
    })
    t.Run("empty name returns validation error", func(t *testing.T) {
        // ...
    })
}
```

Run a specific subtest: `go test -run TestUserService_Create/duplicate_email`

Subtests share parent setup but have independent failure reporting. For data-driven variations
of the same test, use table-driven tests instead (see go-test-table-driven skill).

## Test Helpers

### t.Helper()

Always call `t.Helper()` in helper functions so failure messages point to the test, not the
helper:

```go
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

### Factory functions

Create test fixtures with sensible defaults and functional options for overrides:

```go
func newTestUser(t *testing.T, opts ...func(*User)) *User {
    t.Helper()
    u := &User{
        ID:    "test-id",
        Name:  "Test User",
        Email: "test@example.com",
    }
    for _, opt := range opts {
        opt(u)
    }
    return u
}

// Usage — override only what matters for this test
u := newTestUser(t, func(u *User) { u.Email = "duplicate@example.com" })
```

### t.Cleanup over defer

Prefer `t.Cleanup()` over `defer` — cleanups registered with `t.Cleanup` run after the test
and all its subtests complete, and they run even if `t.Fatal` is called:

```go
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("postgres", testDSN)
    if err != nil {
        t.Fatalf("connect: %v", err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}
```

## Golden File Testing

Store expected complex output in `testdata/` files. Use an `-update` flag to regenerate:

```go
var update = flag.Bool("update", false, "update golden files")

func TestRender(t *testing.T) {
    got := render(input)
    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        os.WriteFile(golden, got, 0o644)
        return
    }

    want, err := os.ReadFile(golden)
    if err != nil {
        t.Fatalf("read golden: %v", err)
    }
    if diff := cmp.Diff(string(want), string(got)); diff != "" {
        t.Errorf("mismatch (-want +got):\n%s", diff)
    }
}
```

Run `go test -update` to regenerate. Commit golden files to version control.

Use golden files when expected output is large (JSON, HTML, multi-line text) — inline
assertions would be unreadable.

## HTTP Handler Testing

### Unit tests with httptest.NewRecorder

Test handlers in isolation without starting a server:

```go
func TestGetUser(t *testing.T) {
    store := &mockStore{
        GetFunc: func(id string) (*User, error) {
            return &User{ID: id, Name: "Alice"}, nil
        },
    }
    h := NewHandler(store)

    req := httptest.NewRequest("GET", "/users/123", nil)
    rec := httptest.NewRecorder()
    h.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
    }
}
```

### Integration tests with httptest.NewServer

Test the full HTTP stack including routing, middleware, and serialization:

```go
func TestAPI_Integration(t *testing.T) {
    srv := httptest.NewServer(setupRouter())
    t.Cleanup(srv.Close)

    resp, err := http.Get(srv.URL + "/users/123")
    // assert on resp...
}
```

## Parallel Tests and TestMain

### t.Parallel

Mark tests as safe to run concurrently:

```go
func TestA(t *testing.T) {
    t.Parallel()
    // ...
}
```

**When to parallelize:** Tests with no shared mutable state — pure function tests, tests
with isolated fixtures.

**When NOT to parallelize:** Tests that share a database, write to the same file, or depend
on global state. Prefer fixing the shared state issue over skipping `t.Parallel`.

### TestMain

Use `TestMain` for expensive one-time setup shared across all tests in a package:

```go
func TestMain(m *testing.M) {
    // Setup
    pool := setupDockerDB()

    code := m.Run()

    // Teardown
    pool.Purge()
    os.Exit(code)
}
```

Reserve `TestMain` for setup that is too expensive to repeat per test (Docker containers,
compiled binaries). For lighter setup, use helper functions with `t.Cleanup`.

## Coverage

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out          # visual report
go tool cover -func=coverage.out          # per-function summary
```

**Meaningful targets:**
- 80%+ for business logic and domain packages
- 60%+ for handlers and adapters
- Do not chase 100% — untested code should be unreachable code or trivial getters, not missed edge cases

## Anti-Patterns Checklist

- [ ] Tests without assertions (test runs but verifies nothing)
- [ ] `time.Sleep()` for synchronization (use channels, sync primitives, or polling with timeout)
- [ ] Order-dependent tests (test B passes only if test A runs first)
- [ ] Excessive mocking (more mock setup than actual test logic)
- [ ] Testing private functions directly (test through the public API instead)
- [ ] Ignoring test errors with `_ =` (use `t.Fatal` or `t.Error`)
- [ ] Shared mutable state between tests without `t.Cleanup`
- [ ] Snapshot/golden files not committed to version control

## Additional Resources

### Reference Files

For in-depth coverage of specific testing topics:
- **`references/mocking-strategies.md`** — Function-field mocks, function injection, generated mocks comparison (gomock vs moq vs counterfeiter), fake vs mock vs stub, what NOT to mock
- **`references/integration-testing.md`** — Testcontainers setup, build tags vs testing.Short(), database fixtures, fuzz testing deep dive
