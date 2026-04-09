---
name: cc
description: >
  This skill should be used when the user asks to "commit changes", "create conventional commits",
  "cc", "commit my changes", "split changes into commits", "commit with granularity",
  or wants to organize uncommitted work into well-structured conventional commits.
  NOT for amending existing commits or interactive rebasing.
---

# Conventional Commits

Create well-structured conventional commits from all current uncommitted changes.
Analyze the codebase structure, detect breaking changes, group files by logical
units, order commits by dependency, and produce clean conventional commit messages.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/cc/references/*.md`

This returns absolute paths for three files: `grouping-strategies.md`,
`dependency-ordering.md`, and `breaking-changes.md`. Store these paths —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/cc/references/*.md`

## Granularity Modes

Parse `$ARGUMENTS` to determine the grouping strategy:

| Argument | Mode | Behavior |
|----------|------|----------|
| *(empty)* or `atomic` | **Atomic** | Each logically independent change becomes its own commit |
| `fine` | **Fine** | Split within layers by package, submodule, or feature |
| `bundled` | **Bundled** | Group by architectural layer or module boundary (coarsest) |

Read **`references/grouping-strategies.md`** (resolved above) for detailed rules per mode.

## Workflow

### Step 1 — Inspect

Run these commands in parallel to understand the current state:

- `git status` (never use `-uall`)
- `git diff --stat` (staged + unstaged overview)
- `git diff` (full diff for content analysis)
- `git log --oneline -5` (recent commit style reference)

If there are no changes to commit, inform the user and stop.

### Step 2 — Analyze Codebase

Read `CLAUDE.md` (if present) and scan the top-level directory structure to understand:

- **Module/package boundaries** — monorepo vs single project, Go modules, npm workspaces, Python packages
- **Architectural layers** — domain, application, infrastructure, wiring
- **Import relationships** — which changed files import/depend on other changed files
- **Language and framework conventions** — infer from file extensions, build configs, directory names

This analysis must be **language-agnostic** — infer grouping from what actually exists.

For import analysis, scan changed files for import/require/include statements that reference
other changed files. Build a lightweight dependency map to inform ordering in Step 5.

### Step 3 — Detect Breaking Changes

Scan the diff for breaking change signals. Read **`references/breaking-changes.md`** (resolved above) for
the full detection pattern catalog. Key signals:

- **Removed or renamed public exports** — functions, types, constants
- **Changed function signatures** — parameters added/removed/reordered, return types changed
- **Schema modifications** — database migrations that drop columns/tables, API response shape changes
- **Configuration format changes** — renamed or removed config keys
- **Protocol/interface changes** — modified interface methods, changed gRPC/protobuf definitions

Flag each detected breaking change with the affected files. These will be annotated
in commit messages using `!` suffix (e.g., `feat!`) or `BREAKING CHANGE:` footer.

### Step 4 — Group Changes

Apply the grouping strategy based on the selected granularity mode.

**For all modes**, these principles apply:
- When a test is tightly coupled to the code it tests (e.g., added alongside a new function), include it in that group's commit
- Skip any group with no changed files
- Never split a single logical change across groups (e.g., an interface and its only implementation)
- **A refactoring is NOT one logical change.** A refactoring that splits a class, creates a
  new module, updates build configs, and adds docker services contains at least 4 distinct
  logical changes. Group by purpose (what each change achieves independently), not by the
  user story that motivated the work.
- **New files, deleted files, and modified files rarely belong in the same commit** unless
  the modification is a direct consequence of the addition/deletion (e.g., updating an import
  after adding a new module). Build configs, docker files, and documentation are almost always
  separate commits.

Read **`references/grouping-strategies.md`** (resolved above) for the complete grouping rules per mode.

### Step 5 — Order by Dependency

Order commit groups so that dependencies are committed before dependents.

1. Use the import map from Step 2 to identify which groups depend on others
2. Apply topological ordering — leaf modules (no dependencies on other changed groups) commit first
3. When no dependency relationship exists between groups, order by convention:
   - Domain/entities before application/ports
   - Application before infrastructure
   - Infrastructure before wiring/entry points
   - Source code before tests (unless tightly coupled)
   - Code before documentation

Read **`references/dependency-ordering.md`** (resolved above) for detailed ordering rules and
language-specific import analysis patterns.

### Step 5.5 — Validate Groups (MANDATORY — never skip)

**Before committing, you MUST output the proposed commit plan** as a numbered list.
For each group, print:

```
Group N: type(scope): description
  Files: file1, file2, ...
  Validation:
    - "and" test: PASS/FAIL
    - mixed types: PASS/FAIL
    - file count: N (limit: 5 for atomic, 10 for fine)
    - single-purpose: PASS/FAIL
```

Then apply each check below. If **any** check FAILs for **any** group, you MUST
return to Step 4 and re-split before proceeding. Do NOT commit with failures.

1. **Mixed intent** — does the group's description need "and" to join unrelated items?
   If yes → FAIL. Split into separate groups.
2. **Mixed commit types** — does the group contain both additions (`feat`) and removals
   (`refactor`/`chore`)? If yes → FAIL. Split by type. This applies to **all modes**.
3. **Oversized scope** — in atomic mode, does the group touch more than 5 files?
   In fine mode, more than 10? → FAIL. Split further — a large file count almost
   always signals multiple logical changes bundled together.
4. **Single-purpose test** (atomic and fine) — could you write a one-sentence description
   of what the commit does without using conjunctions? If not → FAIL. It contains
   multiple logical changes that must be separated.
5. **Multi-bullet body test** — would the commit body need multiple bullets describing
   unrelated changes? If yes → FAIL. Each bullet likely represents a separate commit.

After re-splitting, output the updated plan and re-validate. Repeat until all groups PASS.
Only then proceed to Step 6.

### Step 6 — Commit Each Group

For every group, in dependency order:

1. **Stage only that group's files** — use `git add <file1> <file2> ...` with explicit paths.
   Never use `git add -A` or `git add .`.
   - **Shared files across groups**: when a file has hunks belonging to different groups,
     you cannot use `git add -p` (it is interactive and not supported in this environment).
     Instead, use a **patch-based approach**:
     1. Generate the file's diff: `git diff -- <file> > /tmp/full.patch`
     2. Manually construct a partial patch containing only the relevant hunks
     3. Apply it to the index: `git apply --cached /tmp/partial.patch`
     Or alternatively, stage the whole file and use `git reset -p` is also interactive —
     so if hunks cannot be cleanly separated, prefer grouping files that share hunks
     into the same commit rather than leaving changes partially committed.
2. **Skip sensitive files** — never commit `.env`, credentials, secrets, or API keys. Warn and exclude.
3. **Write a Conventional Commits message** using HEREDOC format:

```
git commit -m "$(cat <<'EOF'
type(scope): imperative lowercase description

- Bullet explaining what changed and why
- Another bullet if needed

BREAKING CHANGE: description of what breaks (only if applicable)
EOF
)"
```

**Title rules** (first line):
- Format: `type(scope): description` — max 72 characters
- Imperative mood: "add", "wire", "update" — not "adds", "added"
- Types: `feat` | `fix` | `refactor` | `docs` | `chore` | `test` | `perf` | `style` | `build` | `ci`
- Append `!` after scope for breaking changes: `feat(api)!: remove legacy endpoint`
- **Scope detection**: derive from the actual package/module name the changes belong to.
  Use the nearest `go.mod`, `package.json`, directory name, or namespace. For cross-cutting
  changes spanning multiple scopes, omit the scope.

**Body rules** (after blank line):
- Explain *why* and *what*, not *how*
- Use `- ` bullet points for multiple items
- Keep it concise but informative
- Add `BREAKING CHANGE:` footer when Step 3 flagged breaking changes in this group

### Step 7 — Verify

After all commits, run `git status` to confirm the working tree is clean.
Report a summary: number of commits created, any breaking changes flagged,
any sensitive files excluded.

## Hard Rules

- Always create **new** commits — never `--amend` unless explicitly asked
- Never use `--no-verify` or skip pre-commit hooks
- Never push — only create local commits
- If a pre-commit hook fails, fix the issue, re-stage, and create a **new** commit (do not amend)
- Infer scope and grouping from the actual project structure — never hardcode paths or languages
- Never commit `.env`, credentials, or secrets — warn and exclude

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read each file when needed:
- **`references/grouping-strategies.md`** — Complete grouping rules for default, fine, and atomic modes with examples
- **`references/dependency-ordering.md`** — Import graph analysis, topological sorting, and language-specific patterns
- **`references/breaking-changes.md`** — Full catalog of breaking change detection patterns across languages
