# Target Template

The gold-standard CLAUDE.md structure. Every output must follow this 5-section format.
Target: 30-40 lines, under 1.5KB.

## Canonical Structure

```markdown
# ProjectName

One-line stack description: language, framework, database, key libraries.

## Commands

- `make build` — compile/build
- `make test` — run all tests
- `make lint` — check formatting and lint rules
- `make fmt` — auto-format code
- `make run` — start development server
- `make migrate` — apply database migrations
- `docker compose up -d` — start infrastructure (PostgreSQL, Redis, etc.)

## Architecture

- `/cmd/` or `/src/app/` — entry point, wiring
- `/internal/` or `/src/domain/` — business logic
- `/pkg/` or `/src/shared/` — shared utilities
- `/sql/migrations/` or `/src/data/` — database layer
- `/tests/` — test suites

## Code Style

- Convention 1 that would surprise a new developer
- Convention 2 (non-obvious naming, formatting, or pattern rule)
- Convention 3 (framework-specific idiom)

## Important

- NEVER do X — use Y instead
- NEVER do Z — use W instead
- See `docs/ARCHITECTURE.md` for design decisions
- See `docs/TESTING.md` for test strategy and patterns
- See `docs/DATABASE.md` for schema and migrations
```

## Example: Go API Project

```markdown
# IndabandAPI

Go 1.25 REST API with Gin, pgx, Elasticsearch, and Google Cloud PubSub.

## Commands

- `make run` — start dev environment with Docker Compose
- `make build` — build Go binary
- `make test` — run integration tests (requires `make apitest-build && make migration-up`)
- `make migration-up` — apply database migrations
- `make migration-status` — check migration status
- `make dbconsole` — connect to PostgreSQL

## Architecture

- `cmd/indaband/main.go` — entry point, dependency injection
- `internal/` — domain modules (session, user, auth, feed, awards, chat, circles)
- `pkg/` — shared utilities and infrastructure
- `sql/migrations/` — Goose database migrations

## Code Style

- Repository pattern: each domain has `repository/`, `usecase/`, `api/` layers
- Event-driven: local PubSub + Google Cloud PubSub for cross-domain communication
- Subscribers registered in main.go, not in domain packages

## Important

- NEVER run tests without `make apitest-build && make migration-up` first
- NEVER access database directly — always use repository layer
- See `docs/ARCHITECTURE.md` for domain boundaries and PubSub patterns
- See `docs/TESTING.md` for integration test setup and fixtures
- See `docs/AUTH.md` for Keycloak and JWT configuration
```

## Example: .NET API Project (Gold Standard from @juliocasal)

```markdown
# GameStore

ASP.NET Core 10 Web API with EF Core, Vertical Slice Architecture, FluentValidation, and xUnit.

## Commands

- `dotnet build --configuration Release`
- `dotnet test` — run all xUnit tests
- `dotnet format --verify-no-changes` — check formatting
- `dotnet ef migrations add <Name> --project src/GameStore.Api --startup-project src/GameStore.Api`
- `dotnet run --project src/GameStore.Api`
- `docker compose up -d` — PostgreSQL, Redis, RabbitMQ

## Architecture

- `/src/GameStore.Api/` — host, endpoints, Program.cs
- `/src/GameStore.Api/Features/` — one folder per slice (request, handler, response, validator)
- `/src/GameStore.Api/Data/` — DbContext, configurations
- `/src/GameStore.Api/Shared/` — cross-cutting concerns
- `/tests/` — WebApplicationFactory + Testcontainers

## Code Style

- Nullable reference types enabled
- Primary constructors, collection expressions
- Async all the way — no .Result or .Wait()
- Record types for DTOs, no repository wrappers

## Important

- NEVER use DateTime.Now — use TimeProvider
- NEVER use new HttpClient() — use IHttpClientFactory
- Always IOptions<T> — no raw config["Key"]
- See `docs/auth-flow.md` for identity setup
```

## Example: Monorepo

```markdown
# Platform

TypeScript monorepo: Next.js frontend, Express API, shared packages. PostgreSQL + Redis.

## Commands

- `make dev` — start all services
- `make test` — run all workspace tests
- `make lint` — ESLint + Prettier check
- `make build` — build all packages
- `make db:migrate` — run Prisma migrations
- `make db:seed` — seed development data

## Architecture

- `apps/web/` — Next.js frontend (App Router)
- `apps/api/` — Express REST API
- `packages/shared/` — shared types, validators, utils
- `packages/db/` — Prisma schema and client
- `packages/ui/` — shared React components

## Code Style

- Strict TypeScript, no `any`
- Zod schemas as single source of truth for validation
- Server components by default, `"use client"` only when needed

## Important

- NEVER import from `apps/` in `packages/` — dependency flows one way
- NEVER use raw SQL — always Prisma client
- See `docs/ARCHITECTURE.md` for package boundaries
- See `docs/TESTING.md` for test strategy per workspace
```

## Reference Syntax Options

Choose the style that matches the project's existing convention:

| Style | Syntax | When to use |
|-------|--------|-------------|
| See reference | `See docs/TESTING.md for test strategy` | Most common, works everywhere |
| Markdown link | `See [TESTING](docs/TESTING.md) for test strategy` | When rendered markdown is expected |
| @ include | `@docs/TESTING.md` | Claude Code native include syntax |

Default to `See docs/X.md` unless the project already uses another style.
