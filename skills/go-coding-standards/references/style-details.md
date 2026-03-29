# Style Details

## Comments and Documentation

### Package comments

Every package should have a package comment. For multi-file packages, place it in `doc.go`:

```go
// Package auth provides authentication and authorization primitives
// for HTTP services.
package auth
```

Start with "Package <name>" followed by a description of what the package provides.

### Exported symbol comments

Every exported type, function, method, constant, and variable must have a doc comment
starting with the identifier name:

```go
// User represents an authenticated user in the system.
type User struct { ... }

// NewUser creates a User with the given name and email.
// Returns an error if the email format is invalid.
func NewUser(name, email string) (*User, error) { ... }

// ErrNotFound is returned when a requested entity does not exist.
var ErrNotFound = errors.New("not found")
```

### Comment style

- Complete sentences with proper capitalization and punctuation
- Start with the name being documented
- Use `//` for all comments (not `/* */`)
- No trailing period on single-line comments for variables and constants
- Blank line between the comment and the next declaration creates a paragraph break

### TODO comments

Format: `// TODO(username): description` — include who is responsible:

```go
// TODO(alice): Replace with database lookup after migration is complete.
```

## Error Message Formatting

Error messages should be lowercase, without trailing punctuation, and without prefixes like
"error:" or "failed to":

```go
// Good
return fmt.Errorf("connect to database: %w", err)
return errors.New("invalid email format")

// Bad — starts with uppercase
return fmt.Errorf("Failed to connect: %w", err)

// Bad — redundant "error" prefix
return fmt.Errorf("error connecting to database: %w", err)

// Bad — trailing punctuation
return errors.New("invalid email format.")
```

This convention ensures that wrapped errors read naturally when concatenated:
`"process order: get user abc123: connect to database: connection refused"`

## Slice and Map Initialization

### Slices

```go
// Nil slice — preferred when unsure if elements will be added
var items []string

// Empty slice — use when the result must be non-nil (e.g., JSON serialization)
items := []string{}

// Known capacity — pre-allocate to avoid repeated growing
items := make([]string, 0, expectedCount)

// Known length — pre-allocate with zero values
items := make([]string, fixedCount)
```

**When to pre-allocate:**
- The final length is known or can be estimated
- Appending in a loop with more than ~10 iterations
- Performance-sensitive code paths

**When NOT to pre-allocate:**
- The slice might remain empty in the common case
- The capacity is a wild guess (wastes memory)

### Maps

```go
// Nil map — safe to read but panics on write
var m map[string]int

// Empty map — safe to read and write
m := make(map[string]int)

// Known size — hint for initial capacity
m := make(map[string]int, expectedCount)

// Literal initialization
m := map[string]int{
    "a": 1,
    "b": 2,
}
```

Always initialize a map before writing to it. Reading from a nil map returns zero values
safely, but writing panics.

## Type Assertion Patterns

### Comma-ok form (safe)

Always use the comma-ok form unless the type is guaranteed:

```go
v, ok := x.(string)
if !ok {
    return fmt.Errorf("expected string, got %T", x)
}
```

### Type switch

Preferred for multiple type checks:

```go
switch v := x.(type) {
case string:
    process(v)
case int:
    processInt(v)
case nil:
    handleNil()
default:
    return fmt.Errorf("unsupported type: %T", x)
}
```

### Single-type assertion (panics on failure)

Only use when the type is guaranteed by the program's logic:

```go
// Safe — the interface was checked at creation time
handler := middleware.(http.Handler)
```

## String Building

| Approach | Use when |
|---|---|
| `fmt.Sprintf` | Single formatting with mixed types |
| `+` operator | Concatenating 2-3 known strings |
| `strings.Builder` | Building strings in a loop |
| `strings.Join` | Joining a slice with a separator |

```go
// Loop — use Builder
var b strings.Builder
for _, item := range items {
    b.WriteString(item)
    b.WriteByte('\n')
}
result := b.String()

// Known parts — use Join
result := strings.Join(parts, ", ")

// Single format — use Sprintf
result := fmt.Sprintf("user %s (%d)", name, id)
```

Never use `fmt.Sprintf` in a loop for string concatenation — `strings.Builder` is
significantly faster.

## Common golangci-lint Configuration

A reasonable starting configuration for `.golangci.yml`:

```yaml
linters:
  enable:
    - errcheck       # unchecked errors
    - govet          # go vet checks
    - staticcheck    # comprehensive static analysis
    - unused         # unused code detection
    - gosimple       # simplification suggestions
    - ineffassign    # detects useless assignments
    - typecheck      # type checking
    - gocritic       # opinionated style checks
    - revive         # replacement for golint
    - misspell       # spelling in comments
    - nilerr         # returning nil when err is not nil
    - errorlint      # error wrapping checks (errors.Is/As)

linters-settings:
  gocritic:
    enabled-tags:
      - diagnostic
      - style
      - performance
  revive:
    rules:
      - name: unexported-return
        disabled: true  # too noisy for internal packages

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck    # test error checking is less strict
```

Run with: `golangci-lint run ./...`

## Blank Identifier Usage

The blank identifier `_` is for intentionally unused values:

```go
// Discard a return value intentionally
_, err := fmt.Fprintf(w, "hello")

// Verify interface compliance at compile time
var _ http.Handler = (*MyHandler)(nil)

// Import for side effects only
import _ "github.com/lib/pq"
```

Never use `_` to discard errors unless the function is documented as safe to ignore (rare).

## Embedding

Embed types for promoted methods, not for field access:

```go
// Good — promoting Logger methods into Server
type Server struct {
    *log.Logger
    addr string
}

// Usage — methods are promoted
srv.Printf("listening on %s", srv.addr)
```

**Rules:**
- Embed interfaces in interfaces (composition)
- Embed structs in structs (method promotion)
- Do not embed to get at fields — use a named field instead
- Embedded types become part of the public API — unexported embeds leak through exported methods

## Range Loop Patterns

```go
// Iterate values only (ignore index)
for _, item := range items {
    process(item)
}

// Iterate indices only (ignore value)
for i := range items {
    items[i].Normalize()
}

// Iterate both
for i, item := range items {
    fmt.Printf("%d: %s\n", i, item)
}

// Iterate map (order is non-deterministic)
for key, value := range m {
    fmt.Printf("%s = %v\n", key, value)
}

// Iterate string (runes, not bytes)
for i, r := range "héllo" {
    fmt.Printf("%d: %c\n", i, r)
}
```

Go 1.22+: `range` over integers:

```go
for i := range 10 {
    fmt.Println(i) // 0..9
}
```
