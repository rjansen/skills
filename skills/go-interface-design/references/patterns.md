# Advanced Interface Patterns

## Standard Library Interface Catalog

These interfaces are worth knowing — they appear everywhere and set the standard for interface design:

| Interface | Package | Methods | Usage |
|---|---|---|---|
| `Reader` | `io` | `Read([]byte) (int, error)` | Streaming input: files, HTTP bodies, buffers |
| `Writer` | `io` | `Write([]byte) (int, error)` | Streaming output: files, HTTP responses, buffers |
| `Closer` | `io` | `Close() error` | Resource cleanup |
| `ReadCloser` | `io` | `Read` + `Close` | HTTP response bodies, file handles |
| `Stringer` | `fmt` | `String() string` | Custom string representation for `%s` formatting |
| `Handler` | `net/http` | `ServeHTTP(ResponseWriter, *Request)` | HTTP request handling |
| `HandlerFunc` | `net/http` | (function type) | Convert function to Handler |
| `Marshaler` | `encoding/json` | `MarshalJSON() ([]byte, error)` | Custom JSON serialization |
| `Unmarshaler` | `encoding/json` | `UnmarshalJSON([]byte) error` | Custom JSON deserialization |
| `TextMarshaler` | `encoding` | `MarshalText() ([]byte, error)` | Custom text representation (used by JSON for map keys) |
| `Interface` | `sort` | `Len`, `Less`, `Swap` | Custom sorting (prefer `slices.SortFunc` in Go 1.21+) |
| `error` | builtin | `Error() string` | All error types |

**Pattern to notice:** Most stdlib interfaces have 1-2 methods. The largest (`sort.Interface`) has 3.

## Composition Patterns

### Embedding interfaces

Build larger interfaces from smaller ones:

```go
type ReadWriteCloser interface {
    io.Reader
    io.Writer
    io.Closer
}
```

### Extending with additional methods

Add methods on top of an embedded interface:

```go
type ResettableReader interface {
    io.Reader
    Reset() // additional method
}
```

### Intersection at the consumer

When a function needs capabilities from multiple packages:

```go
// The consumer defines exactly what it needs
type ReadSaver interface {
    io.Reader
    Save(path string) error
}
```

## Testing with Interfaces

### Function-field mocks (hand-written, no dependencies)

For interfaces with 1-3 methods, a struct with function fields is the simplest mock:

```go
type mockStore struct {
    GetFunc    func(id string) (*User, error)
    CreateFunc func(u *User) error
}

func (m *mockStore) Get(id string) (*User, error) {
    return m.GetFunc(id)
}

func (m *mockStore) Create(u *User) error {
    return m.CreateFunc(u)
}

// In test
store := &mockStore{
    GetFunc: func(id string) (*User, error) {
        return &User{ID: id, Name: "test"}, nil
    },
}
```

### Function injection for simple seams

When only one function needs to be swapped (e.g., time.Now, uuid generation):

```go
type Service struct {
    now func() time.Time // injectable for tests
}

func NewService() *Service {
    return &Service{now: time.Now}
}
```

### Generated mocks

For larger interfaces or when call verification matters:

| Tool | Style | Best for |
|---|---|---|
| `gomock` / `mockgen` | Expectation-based | Verifying call order and arguments |
| `moq` | Function-field structs | Simple, readable mocks |
| `counterfeiter` | Recorded calls | Inspecting calls after the fact |

**Rule of thumb:** Hand-write mocks for interfaces with 1-3 methods. Use generators for larger interfaces or when verifying call sequences.

### What NOT to mock

- **Value objects** — structs with no behavior (just data)
- **Standard library types** — `*sql.DB`, `*http.Client` (wrap them behind your own interface first)
- **Same-package code** — if the mock is in the same package as the real implementation, the interface is likely premature
- **Pure functions** — functions without side effects can be called directly in tests

## Sealed Interface Pattern (Sum Types)

Go lacks sum types, but an unexported method on an interface restricts implementations to the
same package — effectively sealing it:

```go
type Shape interface {
    area() float64 // unexported — only this package can implement
}

type Circle struct{ Radius float64 }
func (c Circle) area() float64 { return math.Pi * c.Radius * c.Radius }

type Rectangle struct{ Width, Height float64 }
func (r Rectangle) area() float64 { return r.Width * r.Height }

// External packages cannot implement Shape — area() is unexported
```

Use this when exhaustive type switches are needed and new implementations should not be added
externally.

## Generics and Interfaces (Go 1.18+)

### Type constraints are interfaces

Generics use interfaces as type constraints:

```go
type Number interface {
    ~int | ~int32 | ~int64 | ~float32 | ~float64
}

func Sum[T Number](values []T) T {
    var total T
    for _, v := range values {
        total += v
    }
    return total
}
```

### When to use generics vs interfaces

| Use case | Prefer |
|---|---|
| Different behavior per type | Interface (polymorphism) |
| Same algorithm, different data types | Generics |
| Return type varies with input type | Generics |
| Need runtime dispatch | Interface |
| Need compile-time type safety | Generics |

### `any` is the empty interface

`any` is an alias for `interface{}`. Use it sparingly — prefer a specific constraint:

```go
// Weak — accepts anything
func Process(data any) { ... }

// Strong — accepts only comparable types
func Deduplicate[T comparable](items []T) []T { ... }
```

## Refactoring: Producer-Side to Consumer-Side

### Before (Java-style producer interface)

```go
// package storage — defines both interface and implementation
type UserRepository interface {
    FindByID(id string) (*User, error)
    FindByEmail(email string) (*User, error)
    Create(u *User) error
    Update(u *User) error
    Delete(id string) error
    List(limit, offset int) ([]*User, error)
}

type PostgresUserRepository struct { db *sql.DB }
// implements all 6 methods...
```

```go
// package auth — consumer forced to depend on full interface
func NewAuthService(repo storage.UserRepository) *AuthService { ... }
// only uses FindByEmail!
```

### After (consumer-side interfaces)

```go
// package storage — exports only the concrete type
type PostgresUserRepository struct { db *sql.DB }
// implements all 6 methods...
```

```go
// package auth — defines only what it needs
type UserByEmailFinder interface {
    FindByEmail(email string) (*User, error)
}

func NewAuthService(users UserByEmailFinder) *AuthService { ... }
```

```go
// package admin — defines its own interface
type UserLister interface {
    List(limit, offset int) ([]*User, error)
}

func NewAdminPanel(users UserLister) *AdminPanel { ... }
```

**Result:** Each consumer depends on exactly what it needs. `PostgresUserRepository` satisfies both interfaces implicitly. Testing each consumer requires mocking only 1 method instead of 6.
