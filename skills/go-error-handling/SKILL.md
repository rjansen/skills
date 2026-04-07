---
name: go-error-handling
description: >
  This skill should be used when the user asks to "handle errors in Go",
  "create a custom error type", "wrap errors", "use sentinel errors",
  "choose between %w and %v", "fix error handling", "propagate errors",
  or mentions errors.Is, errors.As, errors.Join, fmt.Errorf, error wrapping,
  or single-handling principle. Provides a decision tree for choosing the right
  error pattern and Go-specific idioms for error propagation, naming, and handling.
  NOT for panic/recover in HTTP middleware (use go-code-review) or test assertion
  errors (use go-test-quality).
---

# Go Error Handling

Go's explicit error handling requires choosing the right pattern for each situation. This skill
provides a decision framework and idiomatic patterns for error creation, wrapping, inspection,
and propagation.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/go-error-handling/references/*.md`

This returns the absolute path for `patterns.md`. Store this path —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/go-error-handling/references/*.md`

## Error Decision Tree

When creating or returning an error, follow this decision path:

1. **Simple failure message, no inspection needed** → `errors.New("message")` or `fmt.Errorf("context: %v", err)`
2. **Callers need to check for a specific condition** → sentinel error (`var ErrNotFound = errors.New(...)`)
3. **Callers need structured data from the error** → custom error type implementing `error` interface
4. **Preserving the original error for inspection** → `fmt.Errorf("context: %w", err)`
5. **Multiple independent errors to aggregate** → `errors.Join(err1, err2, ...)` (Go 1.20+)
6. **Intentionally hiding the original error** → `fmt.Errorf("context: %v", err)` (breaks the chain)

## Sentinel Errors

Define package-level error variables for conditions callers need to detect programmatically.

```go
var (
    ErrNotFound   = errors.New("user: not found")
    ErrDuplicate  = errors.New("user: duplicate email")
    ErrValidation = errors.New("user: validation failed")
)
```

**Naming rules:**
- Prefix with `Err` — `ErrNotFound`, not `NotFoundError`
- Include package context in the message — `"user: not found"` not just `"not found"`
- Declare as `var`, not `const` (errors are compared by identity, not value)

**Inspection:** Always use `errors.Is(err, ErrNotFound)` — never `err == ErrNotFound`. The `Is` function traverses wrapped error chains.

## Custom Error Types

Define a struct when callers need to extract structured data from an error.

```go
type ValidationError struct {
    Field   string
    Message string
    Err     error // underlying cause
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}

func (e *ValidationError) Unwrap() error {
    return e.Err
}
```

**Naming rules:**
- Suffix with `Error` — `ValidationError`, `TimeoutError`
- Implement `Unwrap() error` when the type wraps another error — this enables `errors.Is` and `errors.As` to traverse the chain

**Inspection:** Use `errors.As` to extract the typed error:

```go
var ve *ValidationError
if errors.As(err, &ve) {
    log.Printf("field %s failed: %s", ve.Field, ve.Message)
}
```

## Error Wrapping with fmt.Errorf

Add context at each layer of the call stack using `%w` or `%v`.

### Use `%w` (preserves the chain)

When callers should be able to inspect the underlying error:

```go
func GetUser(id string) (*User, error) {
    u, err := db.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return u, nil
}
```

### Use `%v` (breaks the chain)

When the underlying error is an implementation detail that should not leak:

```go
func (s *Service) Process(r Request) error {
    if err := s.thirdPartyClient.Call(r); err != nil {
        return fmt.Errorf("process request: %v", err) // hide vendor error
    }
    return nil
}
```

### Multiple wrapping (Go 1.20+)

Wrap multiple errors in a single `fmt.Errorf`:

```go
return fmt.Errorf("operation failed: %w and %w", err1, err2)
```

Both errors are accessible via `errors.Is` and `errors.As`.

## Error Aggregation with errors.Join

Aggregate independent errors from batch operations or parallel work (Go 1.20+):

```go
func ValidateAll(items []Item) error {
    var errs []error
    for _, item := range items {
        if err := validate(item); err != nil {
            errs = append(errs, err)
        }
    }
    return errors.Join(errs...) // returns nil if all nil
}
```

Each joined error is individually reachable via `errors.Is` and `errors.As`.

## Single Handling Principle

Each error must be handled exactly once. Handle means: log it, return it to the caller, or convert it to a different error. Never do more than one.

**Correct — return with context:**
```go
if err != nil {
    return fmt.Errorf("save user: %w", err)
}
```

**Correct — log at the boundary and stop propagation:**
```go
if err := s.Process(ctx, req); err != nil {
    log.Printf("processing failed: %v", err)
    http.Error(w, "internal error", http.StatusInternalServerError)
    return
}
```

**Wrong — log AND return (double handling):**
```go
if err != nil {
    log.Printf("failed: %v", err)  // handled once
    return err                       // handled twice — duplicates in logs
}
```

The boundary (HTTP handler, CLI entry point, goroutine top) is where errors are logged or converted to user-facing responses. Interior code wraps and returns.

## Panic Rules

Panic is reserved for three cases:

1. **Initialization failures** — `regexp.MustCompile`, `template.Must` in `init()` or package-level `var`
2. **Programmer errors** — impossible states that indicate a bug (e.g., switch default on an exhaustive enum)
3. **Violated preconditions** — functions prefixed with `Must` that document panicking behavior

Never panic in library code for recoverable conditions. Never use `recover` to silently swallow panics — if recovering (e.g., in HTTP middleware), log the panic and re-raise or return a 500.

## Verification Checklist

Before completing error handling work, verify:

- [ ] Every `if err != nil` either returns the error (with context) or handles it at a boundary
- [ ] No `_ = someFunc()` discarding errors silently
- [ ] Sentinel errors use `var Err...` naming and `errors.Is` for comparison
- [ ] Custom error types implement `Unwrap()` when they wrap another error
- [ ] `%w` is used when callers need to inspect the cause; `%v` when hiding internals
- [ ] `errors.Join` is used for aggregating independent errors, not `multierr` packages
- [ ] No double handling (log + return) anywhere in the call chain
- [ ] Panic usage is limited to initialization, programmer errors, and documented `Must` functions

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read when needed:
- **`references/patterns.md`** — Deferred error annotation, multi-error inspection chains, domain error hierarchies, HTTP boundary mapping, and common pitfalls
