# Singleton Resolve — AOB-Based Global Pointer Resolution

## When to use

- Understanding how GameDataMan, GameMan, SprjEventFlagMan, or FieldArea are found
- Adding a new singleton/global pointer for a game
- Debugging "failed to resolve base" errors

## Key files

- `internal/memreader/reader.go:184-235` — `initEventFlagPointers()` (lazy init)
- `internal/memreader/reader.go:771-800` — `resolveAOBPath()`
- `internal/memreader/reader.go:710-768` — `resolvePathAddress()`
- `internal/memreader/config.go:89-94` — `PathBases` map

## How it works

### Four singletons in DS3

| Singleton | AOB Config Field | Dereference | Used For |
|-----------|-----------------|-------------|----------|
| GameDataMan | `GameDataManAOB` | true | Player stats, character name, inventory |
| GameMan | `GameManAOB` | true | Save slot, last bonfire, hollowing |
| SprjEventFlagMan | `SprjEventFlagManAOB` | true | Event flags (boss kills, etc.) |
| FieldArea | `FieldAreaAOB` | false | Event flag category lookup |

### Lazy initialization (`reader.go:184-235`)

`initEventFlagPointers()` runs once per attach (guarded by `eventFlagInitDone`):

1. Scan for SprjEventFlagMan AOB → store address in `sprjEventFlagManAOBAddr`
2. Scan for FieldArea AOB → store in `fieldAreaAOBAddr`
3. Scan for GameDataMan AOB (with fallbacks) → store in `gameDataManAOBAddr`
4. Scan for GameMan AOB (with fallbacks) → store in `gameManAOBAddr`

Triggered by first call to `ReadEventFlag()`, `ReadMemoryValue()`, `ReadIGT()`, or any function that calls `initEventFlagPointers()`.

### AOB path resolution (`reader.go:771-800`)

`resolveAOBPath(pathName)` maps a path name to its cached AOB address:

```go
switch pathName {
case "game_man":       → gameManAOBAddr, GameManAOB config
case "game_data_man":  → gameDataManAOBAddr, GameDataManAOB config
}
```

If `Dereference = true`: reads the pointer at the AOB address to get the actual singleton object address.

### PathBases indirection (`config.go:89-94`)

```go
PathBases: map[string]string{
    "player_stats":     "game_data_man",
    "player_game_data": "game_data_man",
    "game_data_man":    "game_data_man",
    "game_man":         "game_man",
}
```

When `ReadMemoryValue("player_stats", ...)` is called:
1. Look up `PathBases["player_stats"]` → `"game_data_man"`
2. Call `resolveAOBPath("game_data_man")` → dereference GameDataMan AOB addr → object ptr
3. Use that as the starting address for the pointer chain

### Zero-length path pattern

```go
MemoryPaths: map[string][]int64{
    "game_man": {},  // empty chain — entirely AOB-resolved
}
```

When `resolvePathAddress("game_man")` sees an empty offset list, it calls `resolveAOBPath("game_man")` directly and returns the dereferenced singleton address.

### Cache lifecycle

- **Set**: on first `initEventFlagPointers()` call after attach
- **Cleared**: on `Detach()` — all four AOB addresses reset to 0, `eventFlagInitDone = false`
- **Reinitialized**: next lazy call after reattach

## Gotchas

- **Dereference is about the global pointer variable** — AOB finds the ADDRESS of the global pointer var in .data, `Dereference=true` means "read what the global points to"
- **FieldArea uses Dereference=false** — the AOB resolves directly to the FieldArea object, not a pointer to it
- **Cache cleared on Detach** — if game process restarts, singletons need re-scanning
- **Static fallback varies by singleton**:
  - SprjEventFlagMan and FieldArea fall back to `EventFlagOffsets64` / `FieldAreaOffsets64` if AOB fails
  - GameDataMan and GameMan have **no static fallback** — AOB scanning must succeed
  - GameDataMan has 6 fallback AOB patterns (1 primary + 5 in `FallbackPatterns`, see `config.go:136-149`) for resilience
- **Test injection** — `SetTestAOBAddresses(gameDataMan, gameMan)` bypasses AOB scanning for unit tests
