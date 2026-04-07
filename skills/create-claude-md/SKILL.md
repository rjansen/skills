---
name: create-claude-md
description: >
  This skill should be used when the user asks to "create a CLAUDE.md",
  "improve CLAUDE.md", "refactor CLAUDE.md", "slim down CLAUDE.md",
  "optimize CLAUDE.md", "make CLAUDE.md shorter", "reduce CLAUDE.md size",
  "generate CLAUDE.md", "set up CLAUDE.md", "bootstrap CLAUDE.md",
  "split CLAUDE.md into companion docs", "extract from CLAUDE.md",
  or mentions CLAUDE.md being too long, bloated, or needing companion docs.
  NOT for editing CLAUDE.md content directly without restructuring.
argument-hint: "[path-to-project]"
allowed-tools: "Read, Write, Edit, Glob, Grep, Bash(wc:*), Bash(find:*), Bash(ls:*), Bash(head:*)"
---

# Create or Improve CLAUDE.md

Create minimal, high-signal CLAUDE.md files by keeping only what applies to every task
and extracting everything else to companion docs. The goal: a file Claude can absorb
in seconds, not paragraphs of context it rarely needs.

## Arguments

Parse `$ARGUMENTS` to determine the target project path. If empty, use the current
working directory.

## Workflow

### Phase 1 — Detect Mode

Check whether `CLAUDE.md` exists at the project root.

**If it exists (refactor mode):**
1. Read the file
2. Measure current size: `wc -l CLAUDE.md` and `wc -c CLAUDE.md`
3. Record baseline measurements for the final report

**If it does not exist (create mode):**
1. Set mode to create
2. Proceed to Phase 2

In both modes, scan for existing companion docs:
- `docs/` directory
- `.claude/docs/` directory
- Any `@` or `See docs/` references already present

### Phase 2 — Analyze Codebase

Run these in parallel to understand the project:

- `ls` the top-level directory structure
- Read manifest files (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`, `Makefile`, `Taskfile`, `justfile`) to detect stack and available commands
- Read `README.md` if present for project name and description
- Glob for `.claude/` directory to detect plugin/skill/agent references
- If refactor mode: parse existing CLAUDE.md into sections by H2 headings and classify each

Consult **`references/codebase-analysis.md`** for language-specific detection patterns
and command discovery heuristics.

### Phase 3 — Plan Extraction

Apply the extraction decision matrix to each content block.
Consult **`references/extraction-rules.md`** for the complete matrix.

**Content that ALWAYS stays inline:**
- Project name + tech stack (1-2 lines)
- Build/test/lint/run commands with exact flags
- Folder/package structure map (brief, one line per entry)
- Non-obvious code style conventions (3-5 bullets max)
- NEVER/landmine rules
- Skill/agent/plugin references (preserved verbatim)
- Single-line references to companion docs

**Content that ALWAYS gets extracted:**
- Testing strategies, patterns, checklists → `TESTING.md`
- Database schemas, migrations, ORM config → `DATABASE.md`
- Architecture deep-dives, design decisions → `ARCHITECTURE.md`
- Auth/security setup details → `AUTH.md`
- Environment variables, config details → `ENV.md`
- Dependency explanations → `DEPENDENCIES.md`
- API endpoint catalogs → `API.md`
- Domain model explanations → `DOMAIN.md`

**Threshold rule:** Any single section longer than 10 lines is a candidate for extraction.

### Phase 4 — Create Companion Docs

For each extraction target identified in Phase 3:

1. Determine the companion doc path — use the project's existing convention:
   - If `.claude/docs/` exists → place there
   - If `docs/` exists → place there
   - Otherwise → create `docs/` at project root
2. If the companion doc already exists, read it and **merge** new content — never overwrite
3. Write the companion doc with a clear H1 title and organized sections
4. One topic per file — never combine unrelated content

### Phase 5 — Write CLAUDE.md

Compose the final file following the 5-section template.
Consult **`references/target-template.md`** for the exact format and examples.

The 5 required sections: **H1 Project** (name + stack, 2 lines), **Commands** (full flags,
prefer make targets), **Architecture** (folder map, one line each), **Code Style** (3-5
non-obvious bullets), **Important** (NEVER rules + `See docs/X.md` references).

**Rules for writing:**
- Prefer `make` targets over raw commands when a Makefile exists
- Architecture section: only top-level folders, one line each
- Code Style: only conventions that would surprise a developer familiar with the stack
- Important: every extracted doc gets a `See docs/X.md` reference line
- Preserve any existing skill/agent/plugin references from the original file

### Phase 6 — Measure and Report

Run `wc -l` and `wc -c` on the final CLAUDE.md. Present a size report:

```
## Size Report
| Metric | Before | After  | Change |
|--------|--------|--------|--------|
| Lines  | 106    | 38     | -64%   |
| Bytes  | 4.2KB  | 1.4KB  | -67%   |
| Status | OVER   | PASS   |        |

Companion docs created:
- docs/ARCHITECTURE.md — extracted architecture details
- docs/TESTING.md — extracted testing strategy
```

**Budget thresholds:**

| Metric | GREEN | YELLOW | RED |
|--------|-------|--------|-----|
| Lines  | <40   | 40-60  | >60 |
| Bytes  | <1.5KB| 1.5-2KB| >2KB|

If status is RED after writing, identify the largest section and extract more content.
Re-measure. Maximum one additional iteration before accepting with a warning.

For create mode, report "N/A — created from scratch" in the Before column.

## Hard Rules

- Never delete content — always extract to a companion doc before removing from CLAUDE.md
- Never remove skill/agent/plugin references from an existing CLAUDE.md
- Never create a CLAUDE.md longer than 80 lines (hard ceiling)
- Always report size before and after
- Always use the project's existing doc path convention
- Prefer `make` targets over raw commands when Makefile exists
- One topic per companion doc — never combine unrelated content

## Additional Resources

### Reference Files

For detailed patterns and heuristics, consult:
- **`references/target-template.md`** — Gold-standard 5-section template with annotated examples for Go, Node, and monorepo projects
- **`references/extraction-rules.md`** — Complete decision matrix for what stays inline vs what gets extracted, with detection signals and merge strategies
- **`references/codebase-analysis.md`** — Language-specific detection patterns, command discovery heuristics, and architecture mapping strategies
