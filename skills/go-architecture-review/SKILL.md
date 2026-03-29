---
name: go-architecture-review
description: >
  This skill should be used when the user asks to "review Go project architecture",
  "design package layout", "organize Go project structure", "fix dependency direction",
  "refactor Go packages", "set up clean architecture in Go", "review module boundaries",
  "fix circular dependencies", or mentions cmd/internal/pkg layout, composition root,
  dependency flow, package design, or module organization. Provides a concrete review
  procedure and severity-rated checklist. NOT for code-level style (use go-code-review)
  or API endpoint design.
---

# Go Architecture Review

Reviewing Go project architecture follows a systematic procedure: scan the project structure,
trace dependency direction, and check against known anti-patterns. Good architecture makes
the next change easy — the goal is to identify structural issues that increase the cost of change.

## Review Process: Scan → Trace → Check

### Step 1: Scan

Read `go.mod` for the module path. List top-level directories. Identify which layout pattern
the project uses:

| Directory | Purpose | Required? |
|---|---|---|
| `cmd/<app>/` | Application entry points (thin `main.go`) | For multi-binary projects |
| `internal/` | Private packages (compiler-enforced) | Recommended |
| `pkg/` | Public packages (importable by other modules) | Rarely needed |

For single-binary projects, `cmd/` may be omitted with `main.go` at the root.

### Step 2: Trace Dependency Direction

Map the import graph. Dependencies must flow inward:

```
handlers/routes → services/usecases → domain/models
                                           ↑
                                    repositories (interfaces)
                                           ↑
                                    adapters (implementations)
```

**The rule:** Domain types import nothing from the project. Services import domain.
Handlers and adapters import services and domain. Never the reverse.

To verify, grep for import paths that violate the direction:

```bash
# Domain importing infrastructure is a violation
grep -rn '"mymodule/internal/handler' internal/domain/
grep -rn '"mymodule/internal/store' internal/domain/
```

### Step 3: Check Against Patterns

Apply the review checklist below, categorizing findings by severity.

## Dependency Direction Rules

1. **Domain has zero project imports** — Only stdlib and value types
2. **Interfaces at the consumer** — The package that calls a method defines the interface, not the package that implements it
3. **No circular imports** — If package A imports B, B cannot import A (compiler-enforced, but often worked around via shared types packages — that is also a smell)
4. **Infrastructure wraps external dependencies** — Database drivers, HTTP clients, and third-party SDKs are wrapped behind interfaces defined by the consuming service

## Standard Layout Quick Reference

```
project/
├── cmd/
│   └── server/
│       └── main.go          # composition root — wires everything
├── internal/
│   ├── domain/              # pure business types, no framework imports
│   │   ├── user.go
│   │   └── order.go
│   ├── service/             # use cases, business logic
│   │   └── order_service.go
│   ├── handler/             # HTTP/gRPC handlers (adapters)
│   │   └── order_handler.go
│   └── store/               # data access implementations (adapters)
│       └── postgres_order.go
├── go.mod
└── go.sum
```

Not every project needs all layers. A small CLI tool may have just `main.go` and one `internal/` package. Match complexity to project size.

## Package Design Principles

**One package, one purpose.** A package should do one thing well. If describing the package requires "and", consider splitting it.

**No generic packages.** `utils/`, `common/`, `helpers/`, `shared/` — these attract unrelated code and become dependency magnets. Move each function to the package that owns the concept.

**No name stuttering.** The package name is part of the qualified name. `storage.StorageClient` stutters — use `storage.Client`. `http.HTTPServer` stutters — use `http.Server`.

**Short, lowercase names.** Single word preferred: `store`, `auth`, `notify`. No underscores, no camelCase in package names.

**Cohesion over size.** A 20-file package with high cohesion is better than 20 single-file packages with scattered responsibilities.

## Composition Root Wiring

The `main.go` function (or a dedicated `wire()` function called from main) is the composition root — the only place that knows about all concrete types:

```go
func main() {
    cfg := config.Load()
    db := postgres.Connect(cfg.DatabaseURL)
    store := store.NewOrderStore(db)
    svc := service.NewOrderService(store)
    handler := handler.NewOrderHandler(svc)
    srv := http.NewServer(handler)
    srv.ListenAndServe(cfg.Port)
}
```

**Rules:**
- `main.go` is a thin wiring file — no business logic
- Explicit instantiation — no DI frameworks, no reflection-based wiring
- Dependency injection via constructor parameters, not globals

## Configuration

- Centralize configuration in a `config` package or struct
- Load from environment variables (12-factor methodology)
- Validate at startup — fail fast on missing or invalid values
- Pass config values to constructors, not the entire config struct

```go
// WRONG — leaks entire config to the store
store := NewStore(cfg)

// CORRECT — pass only what the store needs
store := NewStore(cfg.DatabaseURL, cfg.MaxConnections)
```

## Review Checklist

### Blockers (must fix)

- [ ] Circular dependency between packages (even indirect via shared types)
- [ ] Domain package imports infrastructure, framework, or handler packages
- [ ] Business logic in `main.go` or handler layer
- [ ] Global mutable state accessed across packages
- [ ] `init()` functions with side effects (DB connections, HTTP clients)

### Warnings (should fix)

- [ ] Generic `utils/`, `common/`, `helpers/` packages
- [ ] Fat interfaces (6+ methods) defined at the producer
- [ ] Package name stuttering (`user.UserService`)
- [ ] Config struct passed whole instead of needed values
- [ ] Concrete types in function signatures where interfaces would decouple

### Suggestions (nice to have)

- [ ] `internal/` not used (private packages exposed as `pkg/`)
- [ ] Single `main.go` doing wiring + flag parsing + signal handling (split wiring into `run()`)
- [ ] Missing compile-time interface checks (`var _ Interface = (*Type)(nil)`)
- [ ] Test files in separate `_test` package (preferred for black-box testing)

## Additional Resources

### Reference Files

For detailed layout patterns, migration strategies, and anti-pattern resolution:
- **`references/layout-patterns.md`** — Monorepo vs single-module, when to use `pkg/`, migration from flat to layered, example composition root with graceful shutdown
- **`references/anti-patterns.md`** — Eliminating utils packages, refactoring init() side effects, resolving circular dependencies, fixing domain leakage
