# Breaking Change Detection

Patterns for identifying breaking changes across languages and frameworks.
When a breaking change is detected, annotate the commit with `!` suffix on the type
(e.g., `feat!(api): remove legacy endpoint`) and add a `BREAKING CHANGE:` footer
describing what consumers need to change.

## What Constitutes a Breaking Change

A breaking change is any modification to a **public API surface** that would cause
existing consumers (callers, importers, clients) to fail at compile time, runtime,
or produce different results without their knowledge.

## Detection Patterns

### Removed or Renamed Exports

**Signal**: A public function, type, constant, or variable that existed before the
diff is no longer present (deleted or renamed).

**Go:**
- Exported identifier (starts with uppercase) removed from a package
- `func ProcessOrder(...)` deleted or renamed to `func HandleOrder(...)`
- Exported type field removed or renamed

**TypeScript/JavaScript:**
- Named export removed from module
- `export function` or `export const` deleted
- `export default` changed to a different entity

**Python:**
- Public function/class (no `_` prefix) removed from module
- Entry in `__all__` removed
- Public method removed from a class

**Rust:**
- `pub fn`, `pub struct`, `pub enum` removed
- Public trait method removed

**Java/Kotlin:**
- `public` method or class removed
- Interface method signature changed

### Changed Function Signatures

**Signal**: Parameters added, removed, reordered, or types changed on a public function.

- Required parameter added (breaks all existing callers)
- Parameter removed (callers passing it will fail)
- Parameter type changed (type mismatch)
- Return type changed (callers expecting old type will break)
- Error type changed (error handling may break)

**Go-specific:**
- Return value added/removed (e.g., `func Get() User` → `func Get() (User, error)`)
- Context parameter added as first argument (common but still breaking)
- Variadic changed to/from slice

**TypeScript-specific:**
- Optional parameter becoming required
- Union type narrowed (removes accepted types)
- Generic constraints tightened

### Interface / Protocol Changes

**Signal**: Methods added to or removed from an interface that external code implements.

- New method added to interface → all implementors must add it
- Method signature changed → all implementors must update
- Method removed → implementors have dead code (less critical)

**Go**: Adding a method to an exported interface is always breaking.
**TypeScript**: Adding a required property to an interface type is breaking.
**Java**: Adding an abstract method to an interface (without default) is breaking.

### Schema / Data Changes

**Signal**: Database migrations, API schemas, or serialization formats changed in
incompatible ways.

- **Database**: Column dropped, column renamed, NOT NULL added without default,
  type changed, table dropped
- **API (REST/GraphQL)**: Required field added to request, field removed from response,
  field type changed, endpoint removed, HTTP method changed
- **Protobuf/gRPC**: Field number reused, required field added, field type changed,
  service method removed
- **Config files**: Required key added, key renamed/removed, value type changed

### Behavioral Changes

Harder to detect automatically but worth flagging when obvious:

- Default value changed for a public parameter
- Error handling changed (e.g., function that previously never returned error now does)
- Sort order changed
- Nil/null handling changed (previously accepted nil, now panics)
- Concurrency behavior changed (previously safe for concurrent use, now not)

## Annotation Rules

### When to Use `!` Suffix

Add `!` after the type (or after scope) when the commit contains a breaking change:

```
feat!: remove support for legacy auth tokens
feat(api)!: change response format for /users endpoint
refactor(db)!: rename user_id column to account_id
```

### When to Use `BREAKING CHANGE:` Footer

Always include a `BREAKING CHANGE:` footer that explains:
1. **What changed** — the specific API/behavior that broke
2. **What consumers must do** — migration path or required changes

```
feat(api)!: change user response to include nested profile

- Restructure GET /users/:id response with nested profile object
- Move email, avatar, bio fields under profile key

BREAKING CHANGE: GET /users/:id response shape changed.
Fields `email`, `avatar`, `bio` are now nested under `profile`.
Update client code: `user.email` → `user.profile.email`.
```

### When NOT to Flag as Breaking

- Changes to unexported/private identifiers
- Internal refactoring that preserves the public API
- Adding new exports (purely additive)
- Adding optional parameters with defaults
- Adding new enum values (unless consumers have exhaustive switches)
- Test-only changes
- Documentation changes

## Severity Assessment

When multiple breaking changes are detected, group them by severity:

| Severity | Description | Example |
|----------|-------------|---------|
| **High** | Compile/import fails | Removed export, changed signature |
| **Medium** | Runtime fails | Changed behavior, nil handling |
| **Low** | Subtle differences | Default value changed, sort order |

Report severity in the commit body to help reviewers prioritize.

## Practical Heuristic

For quick detection without deep analysis:

1. Check `git diff` for removed lines starting with `func `, `export `, `public `, `pub fn`
2. Check for renamed files (often indicates renamed exports)
3. Check for migration files with `DROP`, `ALTER ... DROP`, `RENAME`
4. Check for changed method counts in interface definitions
5. Check for removed entries in `.proto`, `.graphql`, or OpenAPI spec files

If any of these fire, investigate further before committing. When in doubt,
flag as breaking — it is better to over-annotate than to miss a breaking change.
