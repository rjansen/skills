# Layout Patterns

## Monorepo vs Single-Module

### Single module (most projects)

One `go.mod` at the root. All packages share the same dependency set.

```
myproject/
├── go.mod          # module github.com/org/myproject
├── cmd/server/
├── internal/
└── ...
```

### Multi-module monorepo

Multiple `go.mod` files for independently versioned components. Use when different parts of the repo have different release cycles or conflicting dependencies.

```
monorepo/
├── services/
│   ├── auth/
│   │   ├── go.mod  # module github.com/org/monorepo/services/auth
│   │   └── ...
│   └── billing/
│       ├── go.mod  # module github.com/org/monorepo/services/billing
│       └── ...
└── libs/
    └── shared/
        ├── go.mod  # module github.com/org/monorepo/libs/shared
        └── ...
```

**Trade-offs:**
- Multi-module adds tooling complexity (go workspace, replace directives during dev)
- Single module is simpler but couples all components to the same dependency versions
- Default to single module unless independently versioned releases are required

### Go Workspaces (go.work)

For multi-module development, `go.work` enables local development without `replace` directives:

```
// go.work
go 1.22

use (
    ./services/auth
    ./services/billing
    ./libs/shared
)
```

Never commit `go.work` — it is a local development convenience. CI builds each module independently.

## When to Use pkg/

Almost never. The `pkg/` directory signals "this code is safe for external import." Before creating `pkg/`:

1. Is this a library meant for other Go modules to import? → Consider `pkg/`
2. Is this an application where all code is internal? → Use `internal/` exclusively
3. Is this a small library (one public package)? → Put it at the module root, no `pkg/` needed

**Rule:** If the module is an application (has `cmd/`), use `internal/`. If the module is a library, put public packages at the root or in `pkg/`.

## Migration: Flat to Layered Architecture

### Phase 1: Identify domains

Map existing code to domain concepts. A flat project with `user.go`, `order.go`, `handler.go`, `db.go` likely has two domains (user, order) with cross-cutting handler and storage concerns.

### Phase 2: Extract domain types

Move pure business types (no framework imports) into `internal/domain/`:

```bash
# Before
user.go       # User struct + UserService + UserHandler + UserStore
order.go      # Order struct + OrderService + OrderHandler + OrderStore

# After phase 2
internal/domain/user.go    # User struct only
internal/domain/order.go   # Order struct only
user.go                    # everything else (temporary)
order.go                   # everything else (temporary)
```

### Phase 3: Extract services

Move business logic into `internal/service/`. Services depend on domain types and interfaces:

```go
// internal/service/order_service.go
type OrderCreator interface {
    Create(ctx context.Context, o *domain.Order) error
}

type OrderService struct {
    store OrderCreator
}
```

### Phase 4: Extract infrastructure

Move implementations (database, HTTP, external clients) into adapter packages:

```
internal/store/postgres_order.go    # implements OrderCreator
internal/handler/order_handler.go   # HTTP handlers calling OrderService
```

### Phase 5: Wire in main

Create the composition root:

```go
func main() {
    db := connectDB()
    store := store.NewOrderStore(db)
    svc := service.NewOrderService(store)
    handler := handler.NewOrderHandler(svc)
    // ...
}
```

**Key:** Each phase is independently deployable. Do not attempt all phases in one PR.

## Composition Root with Graceful Shutdown

A production-ready composition root handles signals and drains connections:

```go
func main() {
    ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer cancel()

    cfg := config.MustLoad()
    db := postgres.MustConnect(cfg.DatabaseURL)
    defer db.Close()

    store := store.New(db)
    svc := service.New(store)
    handler := handler.New(svc)

    srv := &http.Server{
        Addr:    fmt.Sprintf(":%d", cfg.Port),
        Handler: handler.Routes(),
    }

    // Start server in goroutine
    go func() {
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            log.Fatalf("server error: %v", err)
        }
    }()

    log.Printf("server started on :%d", cfg.Port)

    // Wait for interrupt
    <-ctx.Done()
    log.Println("shutting down...")

    // Graceful shutdown with timeout
    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer shutdownCancel()

    if err := srv.Shutdown(shutdownCtx); err != nil {
        log.Fatalf("shutdown error: %v", err)
    }
    log.Println("server stopped")
}
```
