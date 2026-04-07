---
name: go-interface-design
description: >
  This skill should be used when the user asks to "design a Go interface",
  "define an interface", "decouple Go packages", "accept interfaces return structs",
  "verify interface compliance", "refactor for testability", "compose interfaces",
  "use functional options", or mentions consumer-side interfaces, implicit satisfaction,
  interface segregation, or interface anti-patterns in Go. NOT for HTTP handler
  patterns (use go-code-review) or general code review (use go-code-review).
---

# Go Interface Design

Go interfaces are implicit — a type satisfies an interface by implementing its methods, with no
`implements` keyword. This fundamental difference from Java/C# changes where interfaces are
defined, how large they should be, and when to introduce them.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/go-interface-design/references/*.md`

This returns the absolute path for `patterns.md`. Store this path —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/go-interface-design/references/*.md`

## The Cardinal Rule: Consumer Defines the Interface

The single most important Go interface principle: define interfaces where they are used, not
where they are implemented.

```go
// WRONG — producer-side definition (Java style)
// package storage
type UserStore interface {
    Get(id string) (*User, error)
    Create(u *User) error
    Update(u *User) error
    Delete(id string) error
    List(filter Filter) ([]*User, error)
}

type PostgresUserStore struct { ... }
```

```go
// CORRECT — consumer-side definition
// package notification (the consumer)
type UserGetter interface {
    Get(id string) (*User, error)
}

func NewNotifier(users UserGetter) *Notifier { ... }
```

**Why this matters:**
- The consumer knows exactly what it needs — usually 1-2 methods, not the full API
- The producer (PostgresUserStore) satisfies the interface without importing or knowing about it
- No coupling between consumer and producer packages
- Easy to test — mock only the methods the consumer actually calls

## Size Rule: 1-3 Methods

"The bigger the interface, the weaker the abstraction." — Rob Pike

| Methods | Quality | Example |
|---------|---------|---------|
| 1 | Excellent | `io.Reader`, `fmt.Stringer`, `http.Handler` |
| 2-3 | Good | `io.ReadWriter`, `io.ReadCloser` |
| 4-5 | Acceptable if cohesive | `sort.Interface` (Len, Less, Swap) |
| 6+ | Almost certainly too large | Split into smaller, composed interfaces |

Compose small interfaces via embedding:

```go
type ReadCloser interface {
    Reader
    Closer
}
```

## Accept Interfaces, Return Structs

Function signatures should accept interfaces (flexibility) and return concrete types (usability):

```go
// Accept interface — any Reader works
func Parse(r io.Reader) (*Config, error) { ... }

// Return concrete — caller gets full API
func NewStore(db *sql.DB) *PostgresStore { ... }
```

**Exception:** Factory functions that select implementations at runtime may return an interface.

## Compile-Time Verification

Verify interface compliance at compile time using a blank identifier assignment:

```go
var _ http.Handler = (*MyHandler)(nil)
var _ io.ReadCloser = (*MyFile)(nil)
```

Place these declarations near the type definition. The compiler fails if the type does not
satisfy the interface — catching missing methods early instead of at runtime.

## Interface Discovery Heuristic

Do not design with interfaces — discover them. Follow this workflow:

1. **Start concrete.** Write functions that accept concrete types. Ship it.
2. **Notice a seam.** A second caller needs the same behavior, or tests need a fake.
3. **Extract the interface at the consumer.** Define only the methods that consumer uses.
4. **Name it for the behavior.** `Reader`, `Validator`, `Notifier` — not `IService` or `UserStoreInterface`.

If a package has only one implementation of an interface and no tests that mock it, the
interface is premature. Delete it and use the concrete type.

## Functional Options Pattern

For constructors with multiple optional parameters, use functional options instead of config
structs or builder patterns:

```go
type Option func(*Server)

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{addr: addr, port: 8080, timeout: 30 * time.Second}
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
srv := NewServer("localhost", WithPort(9090), WithTimeout(5*time.Second))
```

**When NOT to use functional options:**
- Constructor has 1-2 required parameters and no optional ones — just use regular parameters
- All parameters are required — use a config struct
- The API is internal and stability is not a concern — simpler is better

## Anti-Patterns Quick Reference

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Producer-side interface | Couples consumer to producer's full API | Move interface to consumer package |
| Fat interface (6+ methods) | Weak abstraction, hard to mock | Split into focused 1-3 method interfaces |
| Pointer to interface | `*io.Reader` is never correct — interfaces are already reference types | Remove the pointer: `io.Reader` |
| Premature interface | One implementation, no tests using it | Delete interface, use concrete type |
| Interface for enums | Using interface where `iota` const suffices | Use typed constants with `iota` |
| `interface{}` / `any` everywhere | Loses type safety | Use generics (Go 1.18+) for type-safe polymorphism |
| Stuttering names | `storage.StorageInterface` | `storage.Store` — drop the package name prefix |

## Decision Checklist

Before introducing an interface, answer these questions:

1. **Is there a second consumer or implementation?** If no, wait. Concrete types are simpler.
2. **Is the interface at the consumer?** If it is at the producer, move it.
3. **Is it 1-3 methods?** If larger, split it.
4. **Does the name describe behavior?** `-er` suffix for single-method interfaces (`Reader`, `Writer`, `Closer`). Noun for multi-method (`Store`, `Cache`).
5. **Does the function return the interface or the concrete type?** Return concrete unless selecting implementations at runtime.
6. **Is there a compile-time check?** Add `var _ Interface = (*Type)(nil)`.

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read when needed:
- **`references/patterns.md`** — Stdlib interface catalog, sealed interface pattern, generics interplay, mock strategies, and a worked refactoring example (producer→consumer)
