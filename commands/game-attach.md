# Game Attach — Process Discovery & Attachment

## When to use

- Adding a new game to the death counter
- Debugging why a game isn't being detected
- Understanding how the app connects to a running game process

## Key files

- `internal/memreader/reader.go:50-97` — `Attach()` method
- `internal/memreader/config.go:52-173` — `supportedGames` slice
- `internal/memreader/process_ops.go` — `ProcessOps` interface

## How it works

### Attach flow (`reader.go:50-97`)

1. Iterate over `supportedGames` slice in `config.go`
2. For each game, call `FindProcessByName(game.ProcessName + ".exe")`
3. On match: `OpenProcess` with `PROCESS_VM_READ | PROCESS_QUERY_INFORMATION`
4. `GetModuleBaseAddress(pid, processName + ".exe")` — get module base (ASLR)
5. `IsProcess64Bit(handle)` — detect 32-bit vs 64-bit
6. Verify we have offsets for the detected architecture (`Offsets32` or `Offsets64`)
7. Store handle, baseAddress, game config, and set `attached = true`

### Detach flow (`reader.go:99-111`)

1. Close process handle
2. Clear all cached AOB addresses (sprjEventFlagMan, fieldArea, gameMan, gameDataMan)
3. Reset `eventFlagInitDone = false`
4. Clear `currentGame`

### Adding a new game — minimum config

```go
{
    Name:        "Game Display Name",
    ProcessName: "executablename",  // without .exe, case-sensitive
    Offsets64:   []int64{0x..., 0x...},  // death count pointer chain
}
```

For 32-bit only games, use `Offsets32` instead. For games with both, set both.

### Full config (for route tracking support)

Also needs: `EventFlagOffsets64`, `FieldAreaOffsets64`, `IGTOffsets64`, `MemoryPaths`, `SprjEventFlagManAOB`, `FieldAreaAOB`, `GameManAOB`, `GameDataManAOB`, `PathBases`, `CharNamePathKey/Offset/MaxLen`, `SaveSlotPathKey/Offset`, `Inventory`, `SaveFilePattern`

See the DS3 entry in `config.go:66-154` as the reference implementation.

## Gotchas

- **Process name is case-sensitive** — check Task Manager for the exact executable name
- **Anti-cheat blocks OpenProcess** — Elden Ring requires EAC disabled
- **Architecture mismatch** — if `is64Bit=true` but `Offsets64=nil`, the game is skipped
- **ASLR** — base address changes each launch, so all offsets are relative to base
- **Module name must match** — `GetModuleBaseAddress` uses the same `ProcessName + ".exe"`
