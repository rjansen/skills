# Architecture Anti-Patterns

## Eliminating utils/common/helpers Packages

Generic packages attract unrelated code and become dependency magnets that everything imports,
creating implicit coupling.

### Diagnosis

```bash
# Count how many packages import the utils package
grep -rn '"mymodule/internal/utils"' --include='*.go' | wc -l
```

If the count is high, every change to `utils` risks breaking many packages.

### Resolution

Move each function to the package that owns the concept:

| Before (utils/) | After |
|---|---|
| `utils.FormatMoney(amount)` | `money.Format(amount)` in `internal/money/` |
| `utils.HashPassword(pw)` | `auth.HashPassword(pw)` in `internal/auth/` |
| `utils.ParseDate(s)` | `timeutil.Parse(s)` in `internal/timeutil/` |
| `utils.Contains(slice, item)` | Delete — use `slices.Contains` (Go 1.21+) |
| `utils.Map(slice, fn)` | Delete — use `slices` package or inline loop |

**Rule:** If a utility function is used by exactly one package, move it into that package as
an unexported function. If used by 2+ packages, create a small focused package named for the
concept (not `utils2`).

## Refactoring init() Side Effects

`init()` functions that create database connections, start HTTP clients, or register handlers
make code untestable and create hidden dependencies.

### Diagnosis

```bash
grep -rn 'func init()' --include='*.go'
```

### Acceptable init() uses

- Registering `database/sql` drivers: `import _ "github.com/lib/pq"` (convention)
- Registering `encoding/gob` types
- Setting `log` flags

### Unacceptable init() uses

```go
// BAD — side effect in init
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }
}
```

### Resolution

Replace with explicit initialization in the composition root:

```go
// Good — explicit, testable, configurable
func NewStore(db *sql.DB) *Store {
    return &Store{db: db}
}
```

## God Packages (50+ files)

A single package with dozens of files usually indicates multiple responsibilities collapsed
together.

### Diagnosis

```bash
# Count .go files per package (excluding tests)
find internal/ -name '*.go' ! -name '*_test.go' | awk -F/ '{print $1"/"$2"/"$3}' | sort | uniq -c | sort -rn
```

### Resolution

1. Identify clusters of types that are used together
2. Check which types are referenced by external packages (public API)
3. Extract cohesive clusters into new packages
4. Keep the original package as a facade if needed for backward compatibility

## Circular Dependency Detection and Resolution

Go's compiler prevents direct circular imports, but developers work around this with shared
types packages — which is itself a smell.

### Pattern: Shared types package

```
internal/types/   ← everything imports this
internal/user/    ← imports types/
internal/order/   ← imports types/ and user/
```

The `types/` package becomes a dumping ground. User and order types are co-located despite
being different domains.

### Resolution strategies

**Strategy 1: Dependency inversion with interfaces**

If package A needs to call package B, define an interface in A:

```go
// package order
type UserGetter interface {
    Get(id string) (*User, error)
}

type Service struct {
    users UserGetter
}
```

Package `order` no longer imports `user` — it defines what it needs.

**Strategy 2: Extract shared types into domain package**

If both packages need the same type, that type belongs in a domain package:

```go
// internal/domain/user.go — pure type, no dependencies
type User struct {
    ID    string
    Name  string
    Email string
}
```

Both `user/` and `order/` import `domain/` — dependencies flow inward.

**Strategy 3: Merge packages**

If two packages are tightly coupled and splitting them creates more complexity than it solves,
merge them. A larger cohesive package is better than two coupled small packages.

## Domain Leaking to HTTP Layer

When domain types contain HTTP-specific concerns (JSON tags for API responses, validation
annotations), the domain is coupled to the transport layer.

### Diagnosis

```go
// BAD — domain type with HTTP concerns
type User struct {
    ID       string `json:"id"`
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"-"`
}
```

### Resolution

Separate domain types from transport types:

```go
// internal/domain/user.go — pure domain
type User struct {
    ID       string
    Email    string
    Password string
}

// internal/handler/user_dto.go — HTTP-specific
type UserResponse struct {
    ID    string `json:"id"`
    Email string `json:"email"`
}

func toUserResponse(u *domain.User) UserResponse {
    return UserResponse{ID: u.ID, Email: u.Email}
}
```

**When to tolerate JSON tags on domain types:** Small projects where the domain type IS the API
response. Premature separation adds complexity without benefit when the shapes are identical.
Split only when domain and API shapes diverge.

## Missing Error Context in Layers

Each architectural layer should add context when propagating errors:

```go
// Store layer
func (s *Store) GetUser(id string) (*User, error) {
    // ...
    return nil, fmt.Errorf("get user %s: %w", id, err) // adds store context
}

// Service layer
func (s *Service) ProcessOrder(userID string) error {
    u, err := s.store.GetUser(userID)
    if err != nil {
        return fmt.Errorf("process order: %w", err) // adds service context
    }
    // ...
}

// Handler layer — this is where the error is handled (logged, returned to client)
```

Result: `"process order: get user abc123: sql: no rows in result set"` — readable, traceable, no duplicates.
