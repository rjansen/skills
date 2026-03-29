# Advanced Error Handling Patterns

## Deferred Error Annotation

Use named returns to add context in deferred cleanup, avoiding repetitive wrapping at every return site:

```go
func (s *Store) UpdateUser(ctx context.Context, u *User) (err error) {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("update user: %w", err)
    }
    defer func() {
        if err != nil {
            _ = tx.Rollback() // rollback on any error
            err = fmt.Errorf("update user: %w", err)
        } else {
            err = tx.Commit()
            if err != nil {
                err = fmt.Errorf("update user commit: %w", err)
            }
        }
    }()

    // multiple operations — errors are automatically annotated
    if err = s.updateProfile(tx, u); err != nil {
        return err
    }
    if err = s.updatePermissions(tx, u); err != nil {
        return err
    }
    return nil
}
```

This pattern is particularly useful for transaction-scoped functions with multiple operations that all need the same context prefix.

## Multi-Error Inspection Chains

When errors are joined or multiply wrapped, inspection traverses all branches:

```go
err := errors.Join(
    fmt.Errorf("step 1: %w", ErrNotFound),
    fmt.Errorf("step 2: %w", &ValidationError{Field: "email"}),
)

// Both succeed — Join creates a tree, and Is/As walk all branches
errors.Is(err, ErrNotFound)          // true
var ve *ValidationError
errors.As(err, &ve)                  // true, ve.Field == "email"
```

**Custom Is/As methods:** Implement these on custom error types to control matching behavior:

```go
func (e *AppError) Is(target error) bool {
    t, ok := target.(*AppError)
    if !ok {
        return false
    }
    return e.Code == t.Code // match by code, ignore message
}
```

## Domain Error Hierarchies

Compose sentinels and custom types to build a domain error vocabulary:

```go
// Base domain errors (sentinels)
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrForbidden     = errors.New("forbidden")
    ErrConflict      = errors.New("conflict")
)

// Rich domain error (custom type wrapping a sentinel)
type DomainError struct {
    Entity  string // "user", "order", "product"
    Op      string // "create", "update", "delete"
    Err     error  // underlying sentinel or cause
}

func (e *DomainError) Error() string {
    return fmt.Sprintf("%s %s: %v", e.Op, e.Entity, e.Err)
}

func (e *DomainError) Unwrap() error {
    return e.Err
}

// Usage
func (s *UserService) Create(u *User) error {
    if exists, _ := s.repo.Exists(u.Email); exists {
        return &DomainError{Entity: "user", Op: "create", Err: ErrAlreadyExists}
    }
    // ...
}

// Inspection works at both levels
errors.Is(err, ErrAlreadyExists)  // true
var de *DomainError
errors.As(err, &de)               // true, de.Entity == "user"
```

## HTTP Boundary Error Mapping

At HTTP handler boundaries, map domain errors to status codes. Keep the mapping in one place — typically a middleware or helper:

```go
func statusFromError(err error) int {
    switch {
    case errors.Is(err, ErrNotFound):
        return http.StatusNotFound
    case errors.Is(err, ErrAlreadyExists):
        return http.StatusConflict
    case errors.Is(err, ErrForbidden):
        return http.StatusForbidden
    default:
        var ve *ValidationError
        if errors.As(err, &ve) {
            return http.StatusBadRequest
        }
        return http.StatusInternalServerError
    }
}

func handleError(w http.ResponseWriter, err error) {
    status := statusFromError(err)
    if status >= 500 {
        log.Printf("internal error: %v", err) // log only server errors
    }
    http.Error(w, http.StatusText(status), status)
}
```

**Key principle:** Domain code never imports `net/http`. The HTTP boundary is where errors are translated, logged, and consumed — never deeper.

## gRPC Boundary Error Mapping

The same principle applies to gRPC services — map domain errors to gRPC status codes:

```go
func grpcStatusFromError(err error) codes.Code {
    switch {
    case errors.Is(err, ErrNotFound):
        return codes.NotFound
    case errors.Is(err, ErrAlreadyExists):
        return codes.AlreadyExists
    case errors.Is(err, ErrForbidden):
        return codes.PermissionDenied
    default:
        var ve *ValidationError
        if errors.As(err, &ve) {
            return codes.InvalidArgument
        }
        return codes.Internal
    }
}
```

## Error Shadowing in if-else Chains

A common bug — `:=` inside an `if` block shadows the outer `err`:

```go
// BUG: err inside the if block shadows the function-level err
var err error
if condition {
    result, err := doSomething() // new err, shadows outer
    _ = result
}
// outer err is still nil here!
```

**Fix:** Use `=` instead of `:=`, or restructure to avoid the scope issue:

```go
var err error
if condition {
    var result Result
    result, err = doSomething() // assigns to outer err
    _ = result
}
```

## Wrapping nil Errors

Never wrap a nil error — it creates a non-nil error with a nil cause:

```go
// BUG: returns a non-nil error even when err is nil
func process() error {
    err := doWork()
    return fmt.Errorf("process: %w", err) // non-nil even if err == nil!
}

// CORRECT: check before wrapping
func process() error {
    if err := doWork(); err != nil {
        return fmt.Errorf("process: %w", err)
    }
    return nil
}
```

## Comparing Error Strings

Never compare error messages as strings — they are fragile and break across versions:

```go
// WRONG
if err.Error() == "not found" { ... }

// CORRECT — use sentinels or types
if errors.Is(err, ErrNotFound) { ... }
```

## Error Context Best Practices

When adding context to wrapped errors, include enough information to locate the failure without the stack trace:

```go
// Too vague — which user? which operation?
return fmt.Errorf("failed: %w", err)

// Good — identifies the entity and operation
return fmt.Errorf("get user %s: %w", userID, err)

// Excessive — don't repeat what the caller already knows
return fmt.Errorf("GetUser called with id=%s from handler at line 42: %w", userID, err)
```

Use lowercase context without trailing punctuation. The full error message is built by concatenating all wrapped contexts: `"get user abc123: query row: sql: no rows"`.
