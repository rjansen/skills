# Dependency Ordering

Rules for ordering commit groups so that dependencies are committed before dependents,
ensuring each commit leaves the codebase in a consistent state.

## Import Graph Analysis

### Building the Dependency Map

For each changed file, extract import/dependency statements and check if they reference
other changed files. Build a directed graph: an edge from A to B means "A depends on B"
(A imports B).

### Language-Specific Import Patterns

**Go:**
```
import "github.com/project/internal/domain/user"
import . "github.com/project/internal/app"
```
Map import paths to directories. A file in `internal/app/` importing `internal/domain/user`
creates an edge: `app → domain/user`.

**TypeScript / JavaScript:**
```
import { User } from '../domain/user'
import { UserRepo } from '@project/infra'
const { handler } = require('./handler')
```
Resolve relative and aliased paths to actual files.

**Python:**
```
from domain.user import User
import infrastructure.postgres as db
from . import service
```
Map dotted paths and relative imports to file locations.

**Rust:**
```
use crate::domain::user::User;
mod repository;
```
Map `crate::` paths to `src/` directories.

**Java / Kotlin:**
```
import com.project.domain.user.User;
import com.project.infra.UserRepository;
```
Map package declarations to directory structure.

### Handling Circular Dependencies

If the import graph has cycles between commit groups:
1. Merge the cyclic groups into a single commit
2. Use the most descriptive scope that covers all files
3. Note the circular dependency in the commit body

## Topological Sort

Once the dependency graph is built between commit groups:

1. Identify groups with **no incoming edges** (leaf dependencies) — commit these first
2. Remove committed groups from the graph
3. Repeat until all groups are committed
4. If multiple groups have no incoming edges at the same step, order by convention (below)

## Convention-Based Ordering

When no dependency relationship exists between groups, apply this ordering:

| Priority | Category | Rationale |
|----------|----------|-----------|
| 1 | Domain / Entities | Foundation — no dependencies on other layers |
| 2 | Application / Ports | Depends on domain, depended on by infra |
| 3 | Infrastructure / Adapters | Implements application ports |
| 4 | Wiring / Entry points | Composes everything together |
| 5 | Tests (standalone) | Validates existing code |
| 6 | Documentation | Describes what was built |
| 7 | Build / CI | Configures how to build/deploy |

Within the same priority level, order alphabetically by scope.

## Cross-Module Dependencies

In monorepos with multiple independent modules:

1. Identify which modules changed
2. Check if any module depends on another changed module (via `go.work`, npm workspaces,
   Cargo workspace, etc.)
3. Commit dependency modules before dependent modules
4. Within each module, apply the standard layer ordering

### Example: Go Monorepo

```
libs/shared/          (shared library, changed)
services/api/         (depends on libs/shared, changed)
services/worker/      (depends on libs/shared, changed)
```

Commit order:
1. `libs/shared` changes first (dependency)
2. `services/api` and `services/worker` changes (dependents, no order between them)

## Dependency Manifest Files

Files like `go.mod`, `go.sum`, `package.json`, `package-lock.json`, `Cargo.lock`,
`requirements.txt`, `pubspec.lock`:

- If a dependency was added/updated to support new code, commit the manifest change
  **with** or **before** the code that uses it
- If the manifest change is a standalone dependency bump (e.g., security update),
  commit it separately as `chore(deps): update X`
- Lock files (`go.sum`, `package-lock.json`, `Cargo.lock`) always accompany their
  manifest file in the same commit

## Practical Shortcut

For small changesets (fewer than 10 files), building a full import graph may be
unnecessary overhead. Instead:

1. Check if any changed file obviously imports another changed file
2. If yes, order the imported file's group first
3. If no clear dependencies, use convention-based ordering
4. Reserve full graph analysis for large changesets or monorepos
