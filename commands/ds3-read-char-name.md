# DS3 Read Character Name

## When to use

- Understanding how the DS3 character name is read
- Debugging character name display issues
- Adding character name reading for a new game

## Key files

- `internal/memreader/reader.go:824-839` — `ReadCharacterName()`
- `internal/memreader/reader.go:802-821` — `readUTF16()`
- `internal/memreader/ds3_offsets.go:19-22` — name offset constants
- `internal/memreader/config.go:96-98` — DS3 config

## Memory path

```
GameDataMan (AOB, Dereference=true)
  → +0x10 (PlayerGameData, dereferenced via "player_game_data" path)
    → +0x88 (DS3OffsetCharName, UTF-16LE string, 16 chars max)
```

## Config

```go
CharNamePathKey: "player_game_data",  // resolves via PathBases → "game_data_man" AOB
CharNameOffset:  DS3OffsetCharName,   // 0x88
CharNameMaxLen:  DS3CharNameMaxLen,   // 16
```

## Reading flow

1. `resolvePathAddress("player_game_data")` → AOB resolves GameDataMan → deref → +0x10 → deref → PlayerGameData address
2. `readUTF16(resolved + 0x88, 16)` → read 32 bytes (16 * 2 for UTF-16LE), decode to Go string, stop at null terminator

## CT verification

TGA CT v3.4.0 line ~1874: `GameDataMan → +0x10 → +0x88`, Unicode type, 48 bytes max

## Adding for another game

1. Find the character name pointer chain in CheatEngine (see `/ct-extract`)
2. Determine which singleton holds the path (see `/singleton-resolve`)
3. Set `CharNamePathKey` to the MemoryPaths key
4. Set `CharNameOffset` to the final field offset
5. Set `CharNameMaxLen` to the game's max character name length

## Related skills

- `/singleton-resolve` — how GameDataMan is found via AOB
- `/pointer-chain` — how the offset chain is traversed
