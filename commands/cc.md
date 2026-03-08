Create well-structured conventional commits for all current changes. Follow these steps exactly:

## Step 1 — Inspect

Run these commands in parallel to understand the current state:

- `git status` (never use `-uall`)
- `git diff --stat` (staged + unstaged overview)
- `git log --oneline -5` (recent commit style reference)

If there are no changes to commit, inform me and stop.

## Step 2 — Analyze the codebase

Read `CLAUDE.md` (if present) and scan the top-level directory structure to understand:

- Module/package boundaries (monorepo vs single project)
- Architectural layers (domain, application, infrastructure, etc.)
- Language and framework conventions

This analysis must be **language-agnostic** — infer grouping from what actually exists, never assume a specific stack.

## Step 3 — Group changes

Organize changed files into logical commits using these grouping principles, ordered by dependency (commit earlier groups first):

1. **Domain / Entities** — pure business objects, enums, value types (no framework dependencies)
2. **Application / Ports** — interfaces, protocols, use cases, service contracts
3. **Infrastructure / Adapters** — framework integrations, DB adapters, external clients, migrations, generated code, config files
4. **Wiring / Entry points** — composition roots, CLI entry points, dependency manifests (`go.mod`, `package.json`, `pyproject.toml`, `pubspec.yaml`, etc.), build configs (`Makefile`, `Dockerfile`, CI)
5. **Tests** — test files not tightly coupled to a single layer above
6. **Documentation** — READMEs, CLAUDE.md, guides, changelogs

Skip any group with no changed files. If the project does not follow Clean Architecture, group by **feature or module** instead — one commit per logical unit of change.

When a file clearly belongs to a single layer, put it there. When a test is tightly coupled to the code it tests (e.g., added alongside a new port), include it in that layer's commit instead of the Tests group.

## Step 4 — Commit each group

For every group, do the following:

1. **Stage only that group's files** — use `git add <file1> <file2> ...` with explicit paths. Never use `git add -A` or `git add .`.
2. **Skip sensitive files** — never commit `.env`, credentials, secrets, or API keys. Warn me and exclude them.
3. **Write a Conventional Commits message** using HEREDOC format:

```
git commit -m "$(cat <<'EOF'
type(scope): imperative lowercase description

- Bullet explaining what changed and why
- Another bullet if needed
EOF
)"
```

**Title rules** (first line):
- Format: `type(scope): description`
- Max 72 characters
- Imperative mood: "add", "wire", "update" — not "adds", "added"
- Type: `feat` | `fix` | `refactor` | `docs` | `chore` | `test` | `perf` | `style` | `build` | `ci` — pick the best match
- Scope: module or package name when changes are scoped to one area; omit for cross-cutting changes

**Body rules** (after blank line):
- Explain *why* and *what*, not *how*
- Use `- ` bullet points for multiple items
- Keep it concise but informative

## Step 5 — Verify

After all commits, run `git status` to confirm the working tree is clean.

## Hard rules

- Always create **new** commits — never `--amend` unless I explicitly ask
- Never use `--no-verify` or skip pre-commit hooks
- Never push — only create local commits
- If a pre-commit hook fails, fix the issue, re-stage, and create a **new** commit (do not amend)
- Infer scope and grouping from the actual project structure — do not hardcode any paths or languages
