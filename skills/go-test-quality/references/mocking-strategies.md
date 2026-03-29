# Mocking Strategies

## The Mocking Spectrum

From simplest to most capable:

| Strategy | Complexity | Best for |
|---|---|---|
| Function injection | Lowest | Single function seams (time.Now, uuid) |
| Function-field mock | Low | Interfaces with 1-3 methods |
| Hand-written fake | Medium | Complex behavior (in-memory DB) |
| Generated mock | Higher | Large interfaces, call verification |

Default to the simplest strategy that meets the test's needs.

## Function Injection

Swap a single function dependency without creating an interface:

```go
type Service struct {
    now    func() time.Time
    newID  func() string
}

func NewService() *Service {
    return &Service{
        now:   time.Now,
        newID: func() string { return uuid.New().String() },
    }
}

// In test
svc := &Service{
    now:   func() time.Time { return time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC) },
    newID: func() string { return "fixed-id" },
}
```

Use this when the dependency is a single function, not a service with multiple methods.

## Function-Field Mocks

For interfaces with 1-3 methods, a struct with function fields is the simplest approach — no
external dependencies, fully transparent:

```go
type UserStore interface {
    Get(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, u *User) error
}

type mockUserStore struct {
    GetFunc    func(ctx context.Context, id string) (*User, error)
    CreateFunc func(ctx context.Context, u *User) error
}

func (m *mockUserStore) Get(ctx context.Context, id string) (*User, error) {
    return m.GetFunc(ctx, id)
}

func (m *mockUserStore) Create(ctx context.Context, u *User) error {
    return m.CreateFunc(ctx, u)
}
```

In tests, set only the functions needed:

```go
store := &mockUserStore{
    GetFunc: func(_ context.Context, id string) (*User, error) {
        if id == "not-found" {
            return nil, ErrNotFound
        }
        return &User{ID: id, Name: "Alice"}, nil
    },
}
```

Unused methods panic with a nil function call — this is a feature, not a bug. It catches
unexpected calls immediately.

## Hand-Written Fakes

When mock behavior is complex (stateful, multiple interactions), write a fake:

```go
type fakeUserStore struct {
    mu    sync.Mutex
    users map[string]*User
}

func newFakeUserStore() *fakeUserStore {
    return &fakeUserStore{users: make(map[string]*User)}
}

func (f *fakeUserStore) Get(_ context.Context, id string) (*User, error) {
    f.mu.Lock()
    defer f.mu.Unlock()
    u, ok := f.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return u, nil
}

func (f *fakeUserStore) Create(_ context.Context, u *User) error {
    f.mu.Lock()
    defer f.mu.Unlock()
    if _, exists := f.users[u.ID]; exists {
        return ErrAlreadyExists
    }
    f.users[u.ID] = u
    return nil
}
```

Fakes implement real behavior (in-memory). They are more work to write but more realistic
than mocks, especially for integration-style tests.

## Generated Mocks

For interfaces with 4+ methods or when verifying call sequences, use a code generator:

### gomock / mockgen

```bash
go install go.uber.org/mock/mockgen@latest
mockgen -source=store.go -destination=mock_store_test.go -package=service_test
```

```go
func TestService_Create(t *testing.T) {
    ctrl := gomock.NewController(t)
    store := NewMockUserStore(ctrl)

    store.EXPECT().
        Create(gomock.Any(), gomock.Any()).
        Return(nil)

    svc := NewService(store)
    err := svc.CreateUser(context.Background(), &User{})
    if err != nil {
        t.Fatal(err)
    }
}
```

**Pros:** Verifies call expectations, supports ordered calls
**Cons:** Verbose setup, tests become tightly coupled to call sequences

### moq

```bash
go install github.com/matryer/moq@latest
moq -out mock_store_test.go . UserStore
```

Generates function-field structs automatically — same pattern as hand-written mocks but
auto-generated. Includes call recording for inspection.

### counterfeiter

```bash
go install github.com/maxbrunsfeld/counterfeiter/v6@latest
counterfeiter -o fakes/fake_store.go . UserStore
```

Records all calls for post-hoc inspection:

```go
store.CreateCallCount()           // how many times Create was called
args := store.CreateArgsForCall(0) // arguments of first call
```

### Comparison

| Feature | gomock | moq | counterfeiter |
|---|---|---|---|
| Expectation-based | Yes | No | No |
| Call recording | Limited | Yes | Yes |
| Generated code style | Interface-based | Function fields | Struct with recorders |
| Learning curve | Higher | Lower | Medium |
| Best for | Strict call verification | Simple mocking | Call inspection |

## What NOT to Mock

### Value objects

Structs that hold data with no behavior — pass them directly:

```go
// Don't mock this — just construct it
user := &User{ID: "123", Name: "Alice"}
```

### Standard library concrete types

Do not mock `*sql.DB`, `*http.Client`, or `*os.File` directly. Wrap them behind an interface
at the consumer:

```go
// Instead of mocking *http.Client, define what you need
type HTTPDoer interface {
    Do(req *http.Request) (*http.Response, error)
}
```

### Same-package implementations

If the mock lives in the same package as the real type, the interface is likely premature.
Either the test can use the real implementation or the interface should be at the consumer.

### Pure functions

Functions without side effects produce deterministic output — test them directly:

```go
// Don't mock this — just call it
result := calculateDiscount(price, quantity)
```

## Fake vs Mock vs Stub

| Type | Has behavior? | Verifies calls? | Example |
|---|---|---|---|
| **Stub** | Returns fixed values | No | `GetFunc: func() { return fixedUser, nil }` |
| **Mock** | Returns fixed values | Yes (expectations) | gomock with `EXPECT()` |
| **Fake** | Real behavior (simplified) | No | In-memory store |

Prefer stubs for unit tests (simplest), fakes for integration-style tests (most realistic),
and mocks only when verifying call sequences is essential to the test's purpose.
