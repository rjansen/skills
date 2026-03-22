# DS3 Read Character Stats

## When to use

- Adding a stat-based route checkpoint (soul level, vigor, str, dex, etc.)
- Understanding the DS3 stat memory layout
- Looking up a specific stat offset

## Key files

- `internal/memreader/ds3_offsets.go:4-15` — stat offset constants
- `internal/memreader/config.go:73-88` — MemoryPaths and PathBases
- `internal/memreader/reader.go:547-631` — `ReadMemoryValue()`

## Memory path

```
GameDataMan (AOB, Dereference=true)
  → +0x10 (PlayerGameData) — dereferenced
    → +offset (stat field) — read as uint32 or byte
```

In code: `ReadMemoryValue("player_stats", offset, size)`

PathBases resolves `"player_stats"` → `"game_data_man"` AOB base, then applies MemoryPaths `{0x10}` to reach PlayerGameData.

## All stat offsets (`ds3_offsets.go:4-15`)

| Constant | Offset | Size | Range | Description |
|----------|--------|------|-------|-------------|
| `DS3OffsetSoulLevel` | 0x44 | 4 | 1–802 | Soul Level |
| `DS3OffsetAttunement` | 0x48 | 4 | 1–99 | Attunement |
| `DS3OffsetEndurance` | 0x4C | 4 | 1–99 | Endurance |
| `DS3OffsetVigor` | 0x50 | 4 | 1–99 | Vigor |
| `DS3OffsetDexterity` | 0x54 | 4 | 1–99 | Dexterity |
| `DS3OffsetIntelligence` | 0x58 | 4 | 1–99 | Intelligence |
| `DS3OffsetFaith` | 0x5C | 4 | 1–99 | Faith |
| `DS3OffsetLuck` | 0x60 | 4 | 1–99 | Luck |
| `DS3OffsetStrength` | 0x6C | 4 | 1–99 | Strength |
| `DS3OffsetVitality` | 0x70 | 4 | 1–99 | Vitality |
| `DS3OffsetReinforceLv` | 0xB3 | 1 | 0–10 | Weapon reinforcement level |

## Route JSON example

To checkpoint on reaching Soul Level 20:

```json
{
  "id": "soul-level-20",
  "name": "Soul Level 20",
  "event_type": "mem_check",
  "mem_check": {
    "path": "player_stats",
    "offset": 68,
    "size": 4,
    "comparison": "gte",
    "value": 20
  }
}
```

Note: `offset` in JSON is **decimal** — `0x44 = 68`.

To checkpoint on weapon upgrade +5:

```json
{
  "id": "weapon-plus-5",
  "name": "Weapon +5",
  "event_type": "mem_check",
  "mem_check": {
    "path": "player_stats",
    "offset": 179,
    "size": 1,
    "comparison": "gte",
    "value": 5
  }
}
```

Note: `0xB3 = 179`, `size: 1` for byte-sized reads.

## Related skills

- `/pointer-chain` — how `ReadMemoryValue` traverses the chain
- `/singleton-resolve` — how GameDataMan is resolved via AOB
