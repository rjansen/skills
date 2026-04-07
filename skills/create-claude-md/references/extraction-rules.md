# Extraction Rules

Decision matrix for what stays inline in CLAUDE.md vs what gets extracted to companion docs.

## Core Principle

CLAUDE.md keeps only what Claude needs on **every single prompt**. If content applies to
a subset of tasks, it belongs in a companion doc referenced with one line.

## Decision Matrix

| Content Type | Action | Target File | Inline Reference | Detection Signals |
|---|---|---|---|---|
| Project name + stack | **KEEP** | — | — | H1 heading, first paragraph |
| Build/test/lint commands | **KEEP** | — | — | `make`, `npm`, `dotnet`, `cargo` commands |
| Folder structure map | **KEEP** | — | — | Directory listings with descriptions |
| Non-obvious code style | **KEEP** | — | — | Naming rules, formatting, idioms (3-5 bullets) |
| NEVER/landmine rules | **KEEP** | — | — | "NEVER", "DO NOT", "ALWAYS" warnings |
| Skill/agent/plugin refs | **KEEP** | — | — | Mentions of skills, agents, hooks, plugins |
| Testing strategy | **EXTRACT** | `TESTING.md` | `See docs/TESTING.md for test strategy` | "test", "coverage", "fixtures", "mocks", checklists |
| Database details | **EXTRACT** | `DATABASE.md` | `See docs/DATABASE.md for schema` | "migration", "schema", "ORM", "pgx", "GORM", "Prisma" |
| Architecture deep-dive | **EXTRACT** | `ARCHITECTURE.md` | `See docs/ARCHITECTURE.md for design` | "pattern", "layer", "domain", "clean architecture" explanations |
| Auth/security setup | **EXTRACT** | `AUTH.md` | `See docs/AUTH.md for identity setup` | "JWT", "OAuth", "Keycloak", "auth middleware", "session" |
| Environment config | **EXTRACT** | `ENV.md` | `See docs/ENV.md for configuration` | "environment variable", "docker-compose", ".env", config blocks |
| Dependency explanations | **EXTRACT** | `DEPENDENCIES.md` | `See docs/DEPENDENCIES.md` | "key dependencies", library descriptions, version notes |
| API endpoint catalog | **EXTRACT** | `API.md` | `See docs/API.md for endpoints` | Route listings, endpoint descriptions, request/response formats |
| Domain model docs | **EXTRACT** | `DOMAIN.md` | `See docs/DOMAIN.md for domain model` | Entity descriptions, relationship explanations, business rules |
| Development patterns | **EXTRACT** | `PATTERNS.md` | `See docs/PATTERNS.md for patterns` | "pattern", "how to", step-by-step guides for specific tasks |
| Real-time/event systems | **EXTRACT** | `EVENTS.md` | `See docs/EVENTS.md for event system` | "PubSub", "WebSocket", "Pusher", "event-driven", subscribers |
| Code examples/snippets | **EXTRACT** | Relevant doc | Inline ref to that doc | Multi-line code blocks explaining patterns |

## Section Size Threshold

Any H2 section in CLAUDE.md longer than **10 lines** is a candidate for extraction.
Measure by counting lines between H2 headings.

Priority for extraction when multiple sections exceed threshold:
1. Testing sections (most detailed, least frequently needed per-prompt)
2. Architecture deep-dives (useful but not per-task)
3. Configuration/environment (setup-time only)
4. Domain model explanations (reference material)
5. Code pattern guides (reference material)

## Merge Strategy

When a companion doc already exists:

1. Read the existing file completely
2. Identify sections that overlap with new content
3. For overlapping sections: keep the more detailed version, update if new content adds value
4. For new sections: append under a clear H2 heading
5. Never duplicate content between companion docs — each fact lives in exactly one place

## Ambiguity Rules

When content could fit multiple companion docs:

- **Commands in context of testing** → stays in CLAUDE.md Commands section (just the command), testing details go to TESTING.md
- **Architecture + domain** → architecture goes to ARCHITECTURE.md, domain entities go to DOMAIN.md
- **Auth + environment** → auth flow goes to AUTH.md, auth env vars go to ENV.md
- **Testing + database** → test setup in TESTING.md, schema in DATABASE.md

## What to NEVER Extract

These must always remain inline in CLAUDE.md regardless of length:

- The project name and one-line stack description
- The exact commands needed to build, test, lint, and run
- The top-level folder map (even if architecture details are extracted)
- Critical "NEVER do X" warnings that prevent common mistakes
- References to skills, agents, or plugins the project uses
