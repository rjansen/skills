# Codebase Analysis Heuristics

Strategies for detecting project stack, discovering commands, mapping architecture,
and identifying conventions when creating CLAUDE.md from scratch.

## Stack Detection

Identify the project stack by checking for manifest files in priority order:

| File | Stack | Language |
|------|-------|----------|
| `go.mod` | Go module | Go |
| `package.json` | Node.js / JavaScript / TypeScript | JS/TS |
| `Cargo.toml` | Rust | Rust |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | Python |
| `*.csproj` / `*.sln` | .NET | C# |
| `pom.xml` / `build.gradle` | Java/Kotlin | Java/Kotlin |
| `pubspec.yaml` | Dart/Flutter | Dart |
| `Gemfile` | Ruby | Ruby |
| `mix.exs` | Elixir | Elixir |
| `composer.json` | PHP | PHP |

For framework detection, read the manifest contents:
- Go: check imports in `main.go` (gin, echo, chi, fiber, huma)
- Node: check `dependencies` in `package.json` (next, express, fastify, nest)
- Python: check `[project.dependencies]` or `requirements.txt` (django, flask, fastapi)
- .NET: check `<PackageReference>` in `.csproj` (ASP.NET, EF Core, MediatR)
- Rust: check `[dependencies]` in `Cargo.toml` (actix, axum, rocket)

For database detection, scan for:
- ORM configs: `gorm`, `prisma`, `sqlalchemy`, `entity framework`, `diesel`
- Driver imports: `pgx`, `mysql2`, `sqlite3`, `mongodb`
- Migration directories: `migrations/`, `sql/`, `db/migrate/`
- Docker compose services: `postgres`, `mysql`, `redis`, `mongodb`, `elasticsearch`

## Command Discovery

Check these sources in order. Prefer `make` targets when available:

### Makefile / Makefile.* / GNUmakefile

Parse targets: `grep -E '^[a-zA-Z_-]+:' Makefile | cut -d: -f1`

Common targets to look for: `build`, `test`, `lint`, `fmt`, `run`, `dev`,
`migrate`, `docker`, `clean`, `install`, `deploy`

### package.json scripts

Parse: read `scripts` object from `package.json`

Common scripts: `dev`, `build`, `test`, `lint`, `start`, `format`, `migrate`

### Taskfile.yml / justfile

Parse task names from these alternative task runners.

### Docker Compose

Check `docker-compose.yml` or `compose.yaml` for infrastructure services.
Document the compose command if infrastructure is required.

### Fallback: Language-native commands

If no task runner exists, use language-native commands:
- Go: `go build ./...`, `go test ./...`, `golangci-lint run`
- Node: `npm run build`, `npm test`, `npx eslint .`
- Python: `pytest`, `ruff check .`, `mypy .`
- .NET: `dotnet build`, `dotnet test`, `dotnet format`
- Rust: `cargo build`, `cargo test`, `cargo clippy`

## Architecture Mapping

Map top-level directories. Focus on the first two levels only.

### Go Projects
- `cmd/` — entry points (one sub-dir per binary)
- `internal/` — private application code (domains, services)
- `pkg/` — public shared libraries
- `api/` or `proto/` — API definitions (OpenAPI, gRPC)
- `sql/` or `migrations/` — database migrations

### Node/TypeScript Projects
- `src/` — source code root
- `src/app/` or `src/pages/` — framework entry (Next.js, etc.)
- `src/components/` — UI components
- `src/lib/` or `src/utils/` — shared utilities
- `src/api/` or `src/routes/` — API handlers
- `prisma/` — Prisma schema and migrations

### Python Projects
- `src/` or project name dir — source root
- `tests/` — test suites
- `alembic/` or `migrations/` — database migrations
- `app/` — application package (FastAPI, Django)

### .NET Projects
- `src/ProjectName/` — main project
- `src/ProjectName/Features/` — feature slices
- `src/ProjectName/Data/` — database context
- `tests/` — test projects

### Monorepo Detection

Signals: multiple `package.json` with `workspaces`, `pnpm-workspace.yaml`,
multiple `go.mod` files, `turbo.json`, `nx.json`, `lerna.json`.

For monorepos, map `apps/` and `packages/` directories at top level.

## Convention Detection

Scan a few source files to identify non-obvious patterns:

- **Naming**: check 3-5 files for naming style (camelCase, snake_case, PascalCase)
- **Error handling**: check for custom error types, sentinel errors, Result types
- **Testing style**: check test files for table-driven tests, mocks, fixtures
- **Import ordering**: check for grouped imports, blank line separators
- **Code organization**: check for barrel files, index re-exports, package-per-feature

Only document conventions that deviate from the language's standard style guide.
If the project follows standard Go, Node, or Python conventions, note only the exceptions.

## Plugin/Skill Detection

Check for Claude Code integration:
- `.claude/` directory → may contain settings, plugins, skills
- `.claude-plugin/` directory → this project is a Claude Code plugin
- `CLAUDE.md` references to skills → preserve these verbatim
- `agents/`, `skills/`, `commands/`, `hooks/` directories → plugin components
