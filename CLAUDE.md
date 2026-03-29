# rjansen-skills

Claude Code plugin with personal skills, agents, and commands for Go development and DS3 game data workflows.

**Dependency:** This plugin uses [plugin-dev](https://github.com/anthropics/claude-code-plugins) (Anthropic) for scaffolding and validation. Enable it in settings: `"plugin-dev@claude-plugins-official": true`.

## Install

```bash
make install   # copy new/updated files to ~/.claude/
make mirror    # full sync (deletes extras at destination)
```

## Commands

Plain markdown files in `commands/`. Filename becomes the slash command (e.g., `cc.md` → `/cc`).

```markdown
# Command Name — Brief description

## When to use
...

## How it works
...
```

- Commands are **instructions for Claude**, not messages to users
- Use `$ARGUMENTS`, `$1`, `$2` for dynamic input
- Use `` !`command` `` for inline bash execution
- Frontmatter is optional — see [docs/frontmatter-reference.md](docs/frontmatter-reference.md)

## Agents

Markdown files with YAML frontmatter in `agents/`.

```yaml
---
name: my-agent
model: sonnet
color: blue
tools: ["Read", "Grep", "Glob"]
description: >
  Use this agent when [conditions].

  <example>
  Context: ...
  user: "..."
  assistant: "..."
  <commentary>Why this triggers</commentary>
  </example>
---

You are an expert at...

## Process
### Step 1: ...
```

- `description` **must** include `<example>` blocks showing trigger conditions
- Body is the system prompt — write in second person ("You are...")
- Keep system prompt under 10,000 characters

## Skills

Each skill is a directory under `skills/` with a required `SKILL.md`.

```
skills/my-skill/
├── SKILL.md            # required, ~1500-2000 words max
└── references/         # optional, detailed patterns
    └── patterns.md
```

```yaml
---
name: my-skill
description: >
  This skill should be used when the user asks to "phrase 1",
  "phrase 2", "phrase 3". NOT for [exclusions].
---

# Skill Name

## Process
### Phase 1: ...
```

- `description` **must** use third-person ("This skill should be used when...")
- `description` **must** include specific trigger phrases users would say
- Keep `SKILL.md` lean — put detailed content in `references/`

## Hooks

JSON config in `hooks/hooks.json`. Events: `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `PreCompact`, `Notification`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "prompt", "prompt": "Validate this write" }]
      }
    ]
  }
}
```

- Use `${CLAUDE_PLUGIN_ROOT}` for file paths — never hardcode
- Hooks load at session start — changes require restart
- Two types: `prompt` (LLM-evaluated) and `command` (bash script)

## Never

- Never use `git add -A` or `git add .` in commands — always stage explicit files
- Never commit `.env`, credentials, or secrets
- Never hardcode absolute paths in hooks — use `${CLAUDE_PLUGIN_ROOT}`
- Never write agent descriptions without `<example>` blocks
- Never write skill descriptions in second person — always third person
- Never put detailed reference content in `SKILL.md` — use `references/`
- Never write commands as user-facing descriptions — they are Claude instructions
- Never skip `make install` after adding new components
