# DS3 Read Save Slot

## When to use

- Understanding how the DS3 save slot index is read
- Debugging save slot detection issues
- Adding save slot reading for a new game

## Key files

- `internal/memreader/reader.go:936-956` — `ReadSaveSlotIndex()`
- `internal/memreader/ds3_offsets.go:26-29` — GameMan offset constants
- `internal/memreader/config.go:100-102` — DS3 save slot config

## Memory path

```
GameMan (AOB, Dereference=true, empty chain)
  → +0xA60 (DS3OffsetSaveSlot, Byte, 0-9 or 255=uninitialized)
```

## Config

```go
SaveSlotPathKey: "game_man",
SaveSlotOffset:  DS3OffsetSaveSlot,  // 0xA60
```

GameMan uses a zero-length memory path (`"game_man": {}`), meaning it's resolved entirely via `GameManAOB`. No static fallback exists.

## Reading flow

1. `resolvePathAddress("game_man")` → calls `resolveAOBPath("game_man")` → dereferences `gameManAOBAddr`
2. `readByte(resolved + 0xA60)` → returns save slot index

## Values

- `0-9`: valid save slot (DS3 has 10 save slots)
- `255`: uninitialized — game is loading or no save is selected. Monitor rejects this value

## Other GameMan offsets

| Constant | Offset | Size | Description |
|----------|--------|------|-------------|
| `DS3OffsetSaveSlot` | 0xA60 | 1 | Save slot index |
| `DS3OffsetLastBonfire` | 0xACC | 4 | Last bonfire ID |
| `DS3OffsetHollowing` | 0x204E | 1 | Hollowing level |

## Key detail: AOB-only resolution

GameMan has **no static offset fallback**. If the GameMan AOB scan fails, save slot reading fails entirely. The GameManAOB pattern:

```
"48 8B ?? ?? ?? ?? 04 89 48 28 C3"
RelativeOffsetPos: 3, InstrLen: 7, Dereference: true
```

## Related skills

- `/singleton-resolve` — how GameMan is found via AOB
- `/pointer-chain` — how the resolved address is used
