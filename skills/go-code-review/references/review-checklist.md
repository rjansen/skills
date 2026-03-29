# Detailed Review Checklist

## Correctness and Safety

### Error Handling

- [ ] Every function that returns an error has its error checked by callers
- [ ] No `_ = fn()` where `fn` returns an error (unless explicitly documented as safe)
- [ ] Errors are wrapped with `%w` when callers need to inspect them, `%v` when hiding internals
- [ ] Error context includes enough information to locate the failure: function name, entity ID, operation
- [ ] No double handling — errors are either logged OR returned, never both
- [ ] Sentinel errors use `errors.Is` for comparison, custom types use `errors.As`
- [ ] `errors.Join` used for aggregating independent errors (Go 1.20+)
- [ ] Named returns used correctly with deferred error annotation (no accidental shadowing)

### Nil Safety

- [ ] Interface values checked for nil before method calls (interfaces can be non-nil with nil underlying value)
- [ ] Map values checked: `v, ok := m[key]` before using `v` when zero value is not acceptable
- [ ] Pointer receiver methods handle nil receiver gracefully or document the contract
- [ ] Slice operations check `len(s)` before indexing
- [ ] Type assertions use comma-ok form: `v, ok := x.(Type)` instead of `v := x.(Type)` which panics

### Resource Cleanup

- [ ] `defer Close()` immediately after successful `Open()` / `Dial()` / `Begin()`
- [ ] `defer rows.Close()` after `db.Query()` (not needed for `db.QueryRow()`)
- [ ] `defer resp.Body.Close()` after `http.Get()` / `client.Do()`
- [ ] `defer mu.Unlock()` immediately after `mu.Lock()` (in most cases)
- [ ] File descriptors, network connections, and database connections have finite lifetimes
- [ ] `t.Cleanup()` used in tests instead of `defer` for guaranteed cleanup order

### Context Propagation

- [ ] `context.Context` is the first parameter in functions that do I/O or long-running work
- [ ] Context is passed through the call chain, not replaced with `context.Background()` or `context.TODO()` in request handlers
- [ ] Context values used sparingly — prefer explicit parameters over `context.WithValue`
- [ ] `ctx.Done()` checked in loops and long-running operations

## Concurrency

### Goroutine Lifecycle

- [ ] Every `go func()` has a documented shutdown mechanism (context, done channel, WaitGroup)
- [ ] Goroutines started in constructors have a `Close()` or `Shutdown()` method
- [ ] No goroutine leaks — every goroutine eventually exits
- [ ] `sync.WaitGroup.Add()` called before `go func()`, not inside it
- [ ] Error channels or `errgroup.Group` used to collect goroutine errors

### Data Races

- [ ] Shared mutable state protected by `sync.Mutex`, `sync.RWMutex`, or channels
- [ ] No concurrent map read/write (use `sync.Map` or mutex-protected map)
- [ ] Closure variables in goroutines are captured correctly (pre-Go 1.22: copy loop vars)
- [ ] `sync.Once` used for one-time initialization, not manual boolean flags
- [ ] `-race` flag used in test runs: `go test -race ./...`

### Channel Patterns

- [ ] Channels closed by the sender, never the receiver
- [ ] Unbuffered channels used for synchronization, buffered for decoupling
- [ ] `select` with `ctx.Done()` case for cancellable operations
- [ ] No sends to closed channels (causes panic)
- [ ] Channel direction specified in function signatures: `chan<-` (send-only), `<-chan` (receive-only)

## API Design

### Naming Conventions

- [ ] Exported names do not stutter with package name: `http.Server` not `http.HTTPServer`
- [ ] Acronyms are fully capitalized: `ID`, `URL`, `HTTP`, `JSON`, `XML`, `SQL`
- [ ] Interface names end in `-er` for single-method interfaces: `Reader`, `Writer`, `Closer`
- [ ] Boolean fields/functions read naturally: `IsValid`, `HasPermission`, `CanDelete`
- [ ] Receiver names are 1-2 letters, consistent across all methods: `s` for `*Server`, not `srv` then `server`
- [ ] Unexported by default — only export what consumers need

### Function Signatures

- [ ] `context.Context` is the first parameter (not embedded in a struct)
- [ ] Functions accept interfaces, return concrete types
- [ ] Error is the last return value
- [ ] Variadic options (`...Option`) for optional configuration
- [ ] No more than 5 parameters — use a config struct beyond that

### Documentation

- [ ] Every exported function, type, method, and constant has a doc comment
- [ ] Doc comments start with the name: `// Server represents...` not `// This is a server`
- [ ] Package comment in one file (usually `doc.go` for large packages)
- [ ] Examples in `_test.go` files for complex APIs

## Idiomatic Patterns

- [ ] `:=` used for short variable declarations inside functions
- [ ] Early returns on error reduce nesting depth
- [ ] `switch` preferred over long `if/else if/else` chains
- [ ] `range` used for iteration (not C-style `for i := 0; i < len; i++`)
- [ ] `make` with capacity hint for slices when final size is known: `make([]T, 0, n)`
- [ ] String building uses `strings.Builder` for loops, `fmt.Sprintf` for single formatting
- [ ] Type assertions use comma-ok form
- [ ] Blank identifier `_` only for intentionally unused values, never for errors

## Package Structure

- [ ] Imports organized: stdlib → blank line → external → blank line → internal
- [ ] Package names are short, lowercase, singular nouns
- [ ] No `utils/`, `common/`, `helpers/` packages
- [ ] `internal/` used for private packages
- [ ] No circular dependencies (even indirect via shared types packages)
- [ ] Test files use `_test` package suffix for black-box testing when possible

## Testing

- [ ] New/changed functions have corresponding test coverage
- [ ] Edge cases tested: nil, empty, zero, boundary values, error paths
- [ ] Test names describe scenarios: `TestParse_EmptyInput_ReturnsError`
- [ ] No `time.Sleep` for synchronization — use channels, sync primitives, or polling
- [ ] Mocks are minimal — only mock what the test needs
- [ ] Table-driven tests for 3+ cases with same assertion pattern
- [ ] `t.Helper()` called in test helper functions
- [ ] `t.Parallel()` used for independent tests
- [ ] Golden files committed to `testdata/`
- [ ] Integration tests gated by build tag or `testing.Short()`

## Dependencies

- [ ] `go.sum` committed and up to date
- [ ] No unused dependencies in `go.mod` (run `go mod tidy`)
- [ ] Standard library preferred over external packages where equivalent
- [ ] Deprecated packages identified and flagged for replacement
- [ ] Side-effect imports (`import _ "pkg"`) are documented with a comment
- [ ] No vendored code that duplicates stdlib functionality
- [ ] Security: no known vulnerabilities (run `govulncheck ./...`)
