# DS3 Add Game Data — Master Orchestrator

## When to use

- When asked to add any new DS3 game data reading capability
- Decision tree to route to the right sub-skill

## Decision tree

Ask yourself: **what kind of data am I adding?**

### Boss kill / event flag → `/ds3-read-event-flag`
- "Add boss X to the route"
- "Track whether boss X is defeated"
- "Add encounter flag for boss X"

### Inventory item → `/ds3-read-inventory`
- "Add item X tracking"
- "Check if player has item X"
- "Track quantity of item X"

### Character stat → `/ds3-read-char-stats`
- "Track soul level"
- "Checkpoint on reaching X vigor/str/dex"
- "Read weapon upgrade level"

### Character name → `/ds3-read-char-name`
- "Read character name"
- "Debug character name display"

### Save slot → `/ds3-read-save-slot`
- "Read save slot index"
- "Debug save detection"

### New singleton / global pointer → `/singleton-resolve` + `/aob-scan`
- "Add a new game structure"
- "Find pointer to X manager"
- "Add AOB pattern for X"

### Find data in CheatEngine table → `/ct-extract`
- "What's the item ID for X?"
- "Find the pointer chain to X"
- "Verify offset against CT"

## File modification order (general)

1. `internal/memreader/ds3_offsets.go` — constants (flags, items, offsets)
2. `internal/memreader/config.go` — if adding new MemoryPaths, AOB configs, or PathBases
3. `internal/memreader/aob.go` — if adding new singletons requiring AOB scanning
4. `internal/memreader/reader.go` — if adding new read methods or singletons
5. `internal/memreader/ds3_offsets_test.go` — unit tests (counts, pinned values, uniqueness)
6. `internal/memreader/memreader_e2e_ds3_test.go` — e2e test tables
7. Route JSON file — checkpoints
8. `internal/route/route_integration_test.go` — route flag/checkpoint validation
9. `CLAUDE.md` — if documenting new features or offsets

## Testing checklist

```bash
make test    # all unit and integration tests
make vet     # static analysis
make fmt     # formatting check
```

## Current counts (for reference)

- **25** defeated boss flags
- **17** encountered boss flags
- **18** item ID constants (13 goods, 4 rings, 1 weapon)
- **4** singletons (GameDataMan, GameMan, SprjEventFlagMan, FieldArea)
- **10** stat offsets + 2 other PlayerGameData fields + 3 GameMan fields
