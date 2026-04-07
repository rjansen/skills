---
name: go-code-review
description: >
  This skill should be used when the user asks to "review Go code",
  "review my changes", "check this Go code", "find issues in Go code",
  "do a code review", "review this PR", "check code quality", or mentions
  code review, Go best practices audit, or code quality analysis.
  Provides a structured review process with severity classification and
  confidence-based filtering. NOT for architecture-level review (use
  go-architecture-review) or for writing tests (use go-test-quality).
---

# Go Code Review

Structured code review for Go projects. The process follows four phases: gather changed files,
read the code, analyze against Go-specific categories, and produce a severity-rated report.
Only report findings with high confidence — speculative issues create noise.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/go-code-review/references/*.md`

This returns the absolute path for `review-checklist.md`. Store this path —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/go-code-review/references/*.md`

## Review Process

### Phase 1: Gather

Identify the scope of changes:

```bash
# Recent uncommitted changes
git diff --name-only -- '*.go'

# Changes in a branch vs main
git diff --name-only main...HEAD -- '*.go'

# Specific commit
git show --name-only <sha> -- '*.go'
```

Read project conventions from `CLAUDE.md` or `CONTRIBUTING.md` if present — project-specific
rules override general Go conventions.

### Phase 2: Read

Read each changed `.go` file. For large diffs, focus on:
- New functions and types (highest risk of design issues)
- Changed error handling paths (common source of bugs)
- Modified concurrency code (goroutines, channels, mutexes)
- Public API changes (breaking changes, naming)

### Phase 3: Analyze

Evaluate against the seven review categories below. Apply confidence-based filtering:

- **HIGH confidence** → Report it (clear violation with specific fix)
- **MEDIUM confidence** → Report only if the fix is concrete and actionable
- **LOW confidence** → Do not report (speculation is noise)

### Phase 4: Report

Produce a structured report using the output format template below.

## Severity Classification

| Level | Meaning | Examples |
|---|---|---|
| **BLOCKER** | Correctness, security, or data integrity issue | Nil dereference, data race, SQL injection, error silently discarded |
| **WARNING** | Maintainability or Go convention violation | Missing error context, fat interface, name stuttering, exported function without doc |
| **SUGGESTION** | Style improvement or minor optimization | Variable naming, redundant else, import ordering |

**Rule:** A review with 0 blockers and 0 warnings is a positive outcome. Do not manufacture
warnings to fill the report.

## Review Categories

### 1. Correctness and Safety

- **Nil safety** — check for nil pointer dereference on interface values, map access without
  nil check, slice indexing without bounds check
- **Error handling** — every `if err != nil` must return, log, or handle; no `_ = fn()` discarding
  errors; `%w` for wrappable errors, `%v` for opaque errors
- **Resource cleanup** — `defer Close()` after successful `Open()`, `defer rows.Close()` after
  query, `defer mu.Unlock()` after `Lock()`
- **Context propagation** — functions accepting `context.Context` pass it to downstream calls;
  no `context.Background()` in request handlers

### 2. Concurrency

- **Goroutine lifecycle** — every `go func()` has a clear shutdown path (context cancellation,
  done channel, WaitGroup)
- **Data races** — shared mutable state protected by mutex or channel; check for goroutine
  closures capturing loop variables (pre-Go 1.22)
- **Channel usage** — buffered vs unbuffered choice is intentional; channels are closed by the
  sender; select with default for non-blocking operations
- **Context cancellation** — long-running operations check `ctx.Done()`

### 3. API Design

- **Naming** — exported names are clear without package prefix (no stuttering); acronyms are
  consistent (`ID` not `Id`, `URL` not `Url`, `HTTP` not `Http`)
- **Function signatures** — accept interfaces, return concrete types; `context.Context` is the
  first parameter; options use functional options or config struct
- **Exported documentation** — every exported type, function, and constant has a doc comment
  starting with the name

### 4. Idiomatic Patterns

- **Short variable declarations** — use `:=` inside functions, not `var x Type = value`
- **Early returns** — reduce nesting by returning early on error; avoid deep `if/else` chains
- **Receiver naming** — short (1-2 letters), consistent across methods of the same type; not
  `this` or `self`
- **Zero value usefulness** — types should be usable without explicit initialization when possible

### 5. Package Structure

- **Import organization** — stdlib, blank line, external, blank line, internal
- **Package naming** — short, lowercase, no underscores; no `utils/common/helpers`
- **Internal visibility** — unexported by default; export only what consumers need

### 6. Testing

- **Test coverage of changed code** — new functions have corresponding tests; edge cases
  (nil, empty, zero, boundary) are covered
- **Test quality** — tests assert behavior, not implementation; test names describe scenarios;
  no `time.Sleep` for synchronization

### 7. Dependencies

- **Minimal imports** — no unused imports (compiler-enforced, but check for side-effect imports
  that are no longer needed)
- **Standard library preference** — prefer stdlib over external packages for common tasks
  (`slices` over `golang.org/x/exp/slices`, `slog` over `logrus` for new code)
- **Version pinning** — `go.sum` is committed; indirect dependencies are reviewed for security

## Output Format Template

```markdown
## Code Review Summary

[2-3 sentence overview of the changes and overall assessment]

### Blockers

- `file.go:42` — **[Category]** [Description]. Fix: [specific code or approach].

### Warnings

- `file.go:78` — **[Category]** [Description]. Consider: [specific suggestion].

### Suggestions

- `file.go:15` — **[Category]** [Description].

### Positive Observations

- [Highlight good patterns, clean code, or smart design decisions]

### Overall

[APPROVE / REQUEST CHANGES / NEEDS DISCUSSION]
- Blockers: N | Warnings: N | Suggestions: N
```

**Rules for the report:**
- Every finding includes `file.go:line` reference
- Every BLOCKER and WARNING includes a specific fix, not just a description
- Limit to top 10 findings if too many (prioritize by severity)
- Balance criticism with positive observations — note good patterns
- When no issues found, state "No issues found" with positive observations
- Do not report style preferences that contradict project conventions in CLAUDE.md

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read when needed:
- **`references/review-checklist.md`** — Comprehensive checklist items for each review category with Go-specific checks for error handling, nil safety, goroutine lifecycle, context propagation, race conditions, and dependency hygiene
