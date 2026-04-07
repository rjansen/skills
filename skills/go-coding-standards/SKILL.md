---
name: go-coding-standards
description: >
  This skill should be used when the user asks to "check Go style",
  "fix Go formatting", "review naming conventions", "apply Go conventions",
  "clean up Go code style", "fix import ordering", "review variable declarations",
  or mentions goimports, golangci-lint, MixedCaps, receiver naming, struct
  initialization, or Go coding idioms. Provides conventions grounded in
  Effective Go and Go Code Review Comments. NOT for architecture decisions
  (use go-architecture-review), error handling patterns (use go-error-handling),
  or interface design (use go-interface-design).
---

# Go Coding Standards

Idiomatic Go conventions for daily coding. All code must pass `goimports`, `go vet`, and
`golangci-lint` without errors. This skill covers the style and formatting rules that keep
Go code consistent — naming, declarations, structure, and idioms.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/go-coding-standards/references/*.md`

This returns the absolute path for `style-details.md`. Store this path —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/go-coding-standards/references/*.md`

## Import Ordering

Group imports in three blocks separated by blank lines:

```go
import (
    // 1. Standard library
    "context"
    "fmt"
    "net/http"

    // 2. External packages
    "github.com/gorilla/mux"
    "go.uber.org/zap"

    // 3. Internal/project packages
    "github.com/myorg/myproject/internal/service"
)
```

- Never use dot imports (`import . "pkg"`)
- Alias only to resolve naming conflicts between packages
- `goimports` enforces this ordering automatically — run it on save

## Naming Conventions

### Packages

Short, lowercase, single-word names. The package name is part of every qualified reference
— design for how it reads at the call site:

| Good | Bad | Why |
|---|---|---|
| `store` | `dataStore` | No camelCase in package names |
| `auth` | `authentication` | Short is better |
| `order` | `utils` | Describes what it provides, not a grab bag |

### Functions and Methods

- `MixedCaps` for exported, `mixedCaps` for unexported. No underscores (except test files).
- **Getters:** `Name()`, not `GetName()`. **Setters:** `SetName()`.
- **Constructors:** `NewFoo()` returning `*Foo`. Single-type packages: `New()`.

### Variables

| Scope | Style | Example |
|---|---|---|
| Tight (loop, short function) | Short | `i`, `n`, `err`, `ctx`, `u` |
| Wide (package-level, long function) | Descriptive | `userCount`, `retryTimeout` |
| Unexported package-level | `_` prefix | `var _defaultTimeout = 5 * time.Second` |

Never shadow built-in identifiers: `error`, `len`, `cap`, `new`, `make`, `close`, `copy`,
`delete`, `append`.

### Acronyms

Fully capitalize standard acronyms: `ID` not `Id`, `URL` not `Url`, `HTTP` not `Http`,
`JSON` not `Json`, `SQL` not `Sql`, `API` not `Api`.

### Receivers

- 1-2 letter abbreviation of the type name, consistent across all methods
- `s` for `*Server`, `c` for `*Client`, `tx` for `*Transaction`
- Never `this` or `self`

## Variable Declarations

### Package-level

Use `var` without redundant type annotation:

```go
// Good — type inferred
var _defaultPort = 8080
var _logger = zap.NewNop()

// Bad — redundant type
var _defaultPort int = 8080
```

### Local

Prefer `:=` for local variables. Use `var` only when the zero value is intentional and
meaningful:

```go
// Zero value is meaningful — bytes.Buffer is usable without initialization
var buf bytes.Buffer

// Assignment — use short declaration
name := getUserName()
count := len(items)
```

### Constants

Group related constants. Use `iota` for enums, starting with an explicit sentinel for the
zero value:

```go
type Status int

const (
    StatusUnknown Status = iota // zero value = unset
    StatusActive
    StatusInactive
)
```

Starting at `iota` (0) with a named sentinel is preferred over starting at 1. The zero value
should represent "not set" or "unknown", making it safe as a default.

## Struct Initialization

Always use field names. Never rely on positional order:

```go
// Good — resilient to field reordering
user := User{
    Name:  "Alice",
    Email: "alice@example.com",
}

// Bad — breaks silently when fields are reordered
user := User{"Alice", "alice@example.com", 30}
```

Omit zero-value fields unless including them adds clarity:

```go
// Good — Active defaults to false (zero value)
user := User{
    Name: "Alice",
}
```

## Reduce Nesting

### Early returns

Handle errors and special cases first. The happy path should be at the lowest indentation level:

```go
func process(items []Item) error {
    for _, v := range items {
        if !v.IsValid() {
            continue
        }
        if err := v.Process(); err != nil {
            return fmt.Errorf("process item %s: %w", v.ID, err)
        }
        v.Send()
    }
    return nil
}
```

### Eliminate unnecessary else

When the `if` block returns or continues, the `else` is unnecessary:

```go
// Good
a := defaultValue
if condition {
    a = overrideValue
}

// Bad — unnecessary else
var a int
if condition {
    a = 20
} else {
    a = 10
}
```

## File Organization

Order declarations within a file by visibility and role:

1. Package comment (if `doc.go` is not used)
2. Constants and package-level variables
3. Types (structs, interfaces)
4. `New()` / constructor functions
5. Exported methods (grouped by receiver type)
6. Unexported methods
7. Helper functions

Place receiver methods immediately after their type declaration — do not scatter methods of
the same type across the file.

## Line Length and Formatting

Soft limit of 99 characters. Break long function signatures at parameters:

```go
func (s *Store) CreateUser(
    ctx context.Context,
    name string,
    email string,
    opts ...CreateOption,
) (*User, error) {
```

Let `gofmt` handle all other formatting decisions — do not fight the formatter.

## Defer

Use `defer` for cleanup immediately after resource acquisition:

```go
mu.Lock()
defer mu.Unlock()

f, err := os.Open(path)
if err != nil {
    return err
}
defer f.Close()
```

Defer runs in LIFO order. Be aware that deferred function arguments are evaluated immediately,
not when the deferred function executes.

## Time Package

Use `time.Duration` for durations, `time.Time` for instants. Never use raw integers for time:

```go
// Good — self-documenting
func poll(interval time.Duration) { ... }
poll(10 * time.Second)

// Bad — what unit? seconds? milliseconds?
func poll(intervalSecs int) { ... }
poll(10)
```

Use `time.Since(start)` instead of `time.Now().Sub(start)`.

## Verification Checklist

- [ ] `goimports` runs clean (or `gofmt` + manual import ordering)
- [ ] `go vet ./...` passes
- [ ] `golangci-lint run` passes (if configured)
- [ ] No shadowed built-in identifiers
- [ ] Imports grouped: stdlib → external → internal
- [ ] Struct initializations use field names
- [ ] No unnecessary nesting or else blocks
- [ ] Receiver names are 1-2 letters and consistent
- [ ] Acronyms fully capitalized (`ID`, `URL`, `HTTP`)
- [ ] Package-level vars use `_` prefix for unexported globals

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read when needed:
- **`references/style-details.md`** — Comprehensive rules for comments and documentation, error message formatting, slice and map initialization idioms, type assertion patterns, and common golangci-lint configuration
