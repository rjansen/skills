# Grouping Strategies

Detailed rules for organizing changed files into commit groups based on granularity mode.

## Default Mode

Group by **architectural layer or module boundary**. This is the coarsest grouping and
maps to how most projects organize code conceptually.

### Layer Ordering

Apply these groups in order, skipping any with no changed files:

1. **Domain / Entities** — pure business objects, enums, value types, domain errors
   (no framework or infrastructure dependencies)
2. **Application / Ports** — interfaces, protocols, use cases, service contracts,
   application-level errors, DTOs
3. **Infrastructure / Adapters** — framework integrations, DB adapters, external clients,
   repositories, migrations, generated code, config files
4. **Wiring / Entry points** — composition roots, CLI entry points, HTTP routers,
   dependency manifests (`go.mod`, `package.json`, `pyproject.toml`, `pubspec.yaml`),
   build configs (`Makefile`, `Dockerfile`, CI pipelines)
5. **Tests** — test files not tightly coupled to a single layer above
6. **Documentation** — READMEs, CLAUDE.md, guides, changelogs, comments-only changes

### When Clean Architecture Does Not Apply

If the project does not follow layered architecture (e.g., flat structure, feature folders,
microservices), group by **module or feature** instead — one commit per logical unit of change.

Indicators of non-layered structure:
- No `domain/`, `internal/`, `pkg/`, `src/`, `lib/` directories
- Feature-based folders (e.g., `auth/`, `billing/`, `notifications/`)
- Flat project with all files at root

### Tightly Coupled Tests

When a test file is clearly paired with a source file in the same change (e.g., both
`user.go` and `user_test.go` are modified together), include the test in the same
commit as its source file rather than in the Tests group.

## Fine Mode

Group by **package, submodule, or feature within each layer**. This produces more commits
with narrower scope than default mode.

### Strategy

1. Start with the same layer detection as default mode
2. Within each layer, subdivide by the **nearest package boundary**:
   - Go: each directory with `.go` files is a package
   - Node/TypeScript: each directory with `package.json` or `index.ts`
   - Python: each directory with `__init__.py` or each top-level module
   - Rust: each `mod.rs` or `lib.rs` boundary
   - Java/Kotlin: each package directory
   - General: each immediate subdirectory within the layer

3. Each sub-package becomes its own commit group
4. Cross-package changes within the same layer get their own group

### Example

Given these changed files in a Go project:
```
internal/domain/user/entity.go
internal/domain/user/errors.go
internal/domain/order/entity.go
internal/app/user/service.go
internal/app/order/service.go
internal/infra/postgres/user_repo.go
internal/infra/postgres/order_repo.go
cmd/server/main.go
```

Fine mode produces:
1. `feat(user): add user domain entity and errors`
2. `feat(order): add order domain entity`
3. `feat(user): add user application service`
4. `feat(order): add order application service`
5. `feat(postgres): add user repository adapter`
6. `feat(postgres): add order repository adapter`
7. `chore(server): wire new services in entry point`

Compared to default mode which would produce:
1. `feat(domain): add user and order entities`
2. `feat(app): add user and order services`
3. `feat(infra): add postgres repositories`
4. `chore(server): wire new services`

### Merging Small Groups

If fine mode produces groups with only 1 file and those files share the same parent
package, consider merging them into a single commit to avoid excessive noise.
Use judgment: 2-3 related one-file changes in the same package can merge;
unrelated changes should stay separate.

## Atomic Mode

Group by **individual logical change**. Each semantically independent modification
becomes its own commit. This is the most granular mode.

### Strategy

1. Analyze the full diff at the hunk level
2. Identify **logical units of change** — a logical unit is the smallest set of
   modifications that makes sense on its own:
   - A new function and its direct callers' updates
   - A bug fix (the fix + the regression test)
   - A renamed variable across all its usages
   - A configuration change and its corresponding code adaptation
   - A single new dependency and its integration

3. Each logical unit becomes its own commit
4. Never split changes that would leave the codebase in a broken intermediate state

### Constraints

- Each commit must leave the codebase **compilable and test-passing** (if tests existed before)
- If two hunks in the same file serve different logical purposes, they belong to
  different commits — use `git add -p` or stage specific files strategically
- When atomic splitting would be impractical (e.g., a single file with deeply
  interleaved changes), fall back to fine mode for that file

### Example

Given a diff that adds user validation:
```
internal/domain/user/entity.go      (added Validate method)
internal/domain/user/errors.go      (added ErrInvalidEmail)
internal/app/user/service.go        (calls Validate before save)
internal/app/user/service_test.go   (tests validation in service)
internal/infra/postgres/user_repo.go (added email unique constraint)
migrations/003_email_unique.sql     (migration file)
```

Atomic mode produces:
1. `feat(user): add email validation to user entity` — entity.go + errors.go
2. `feat(user): validate user before save in service` — service.go + service_test.go
3. `feat(postgres): add email uniqueness constraint` — user_repo.go + migration

## Scope Detection Rules

For all modes, determine commit scope using these rules in priority order:

1. **Single package** — use the package/module name (e.g., `user`, `postgres`, `auth`)
2. **Single layer, multiple packages** — use the layer name (e.g., `domain`, `infra`)
3. **Single feature, multiple layers** — use the feature name (e.g., `user`, `billing`)
4. **Cross-cutting** — omit scope entirely

To detect the package name:
- Go: directory name containing the changed `.go` files
- Node/TS: `name` field in nearest `package.json`, or directory name
- Python: directory name containing `__init__.py`, or module name
- Rust: crate name from `Cargo.toml`, or module directory name
- Java/Kotlin: last segment of the package declaration
- General fallback: immediate parent directory name
