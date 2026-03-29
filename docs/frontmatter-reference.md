# Frontmatter Reference

## Commands (all optional)

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Shown in `/help` listing |
| `allowed-tools` | string | Comma-separated tool names: `Read, Write, Bash(git:*)` |
| `model` | string | `sonnet`, `opus`, `haiku`, or `inherit` |
| `argument-hint` | string | Displayed as usage hint: `[file] [options]` |
| `disable-model-invocation` | bool | If `true`, runs as template only (no LLM) |

## Agents (required fields marked with *)

| Field | Type | Description |
|-------|------|-------------|
| `name`* | string | 3-50 chars, lowercase, hyphens only |
| `description`* | string | Trigger conditions + `<example>` blocks |
| `model`* | string | `sonnet`, `opus`, `haiku`, or `inherit` |
| `color`* | string | `blue`, `cyan`, `green`, `yellow`, `magenta`, `red` |
| `tools` | list | Restrict available tools: `["Read", "Grep", "Bash(git:*)"]` |

## Skills

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Skill identifier |
| `description` | string | Third-person trigger phrases. Must include "This skill should be used when..." |
| `version` | string | Semver (e.g., `0.1.0`) |
