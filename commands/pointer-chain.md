# Pointer Chain — Memory Traversal

## When to use

- Understanding how death counts, stats, or other values are read from memory
- Adding a new memory path or pointer chain
- Debugging "null pointer in chain" errors

## Key files

- `internal/memreader/reader.go:483-500` — `followPointerChain`
- `internal/memreader/reader.go:124-179` — `ReadDeathCount`
- `internal/memreader/reader.go:547-631` — `ReadMemoryValue`
- `internal/memreader/reader.go:710-768` — `resolvePathAddress`

## How it works

### Three traversal methods with different last-offset semantics

#### 1. `followPointerChain(offsets)` (line 484-500)

Standard traversal. **Last offset is NOT dereferenced** — returns an address.

```
address = baseAddress
for each offset:
    address += offset
    if not last: address = *address  // dereference
return address  // final value is an ADDRESS
```

Used by: `ReadEventFlag` (static fallback), `ReadIGT` (static fallback)

#### 2. `ReadDeathCount()` (line 124-179)

**ALL offsets are dereferenced** — the final value IS the death count.

```
address = baseAddress
for each offset:
    address += offset
    address = *address  // ALWAYS dereference, including last
return uint32(address)  // final value IS the count
```

This works because the last "dereference" actually reads the death count value (stored at the final address).

#### 3. `ReadMemoryValue(pathName, extraOffset, size)` (line 547-631)

AOB-aware path resolution + extra offset for the specific field.

```
1. Look up pathName in game.MemoryPaths → get offsets
2. Determine start address:
   - Check PathBases[pathName] → resolve via AOB (e.g. "game_data_man")
   - If no PathBases entry → use module baseAddress
3. Follow ALL offsets (each dereferenced — same as ReadDeathCount)
4. Read value at (resolved_address + extraOffset) with given size (1/2/4 bytes)
```

### 32-bit vs 64-bit

- 64-bit: pointers are 8 bytes (uint64)
- 32-bit: pointers are 4 bytes (uint32) — only used in `ReadDeathCount`
- `followPointerChain` always reads 8-byte pointers (64-bit only method)

### ErrNullPointer

Returned when a `0` address is encountered mid-chain. Means the game is still loading and data structures aren't initialized yet. Callers should retry next tick.

## Example: DS3 death count

Offsets: `[0x47572B8, 0x98]`

```
1. addr = base + 0x47572B8
2. addr = *(addr)           // read 8-byte pointer
3. addr += 0x98
4. addr = *(addr)           // read death count (uint32 stored as pointer-sized read)
5. return uint32(addr)
```

## Example: DS3 soul level via ReadMemoryValue

```go
ReadMemoryValue("player_stats", 0x44, 4)
```

1. PathBases["player_stats"] = "game_data_man" → resolve GameDataMan via AOB
2. MemoryPaths["player_stats"] = {0x10} → deref at GameDataMan+0x10 = PlayerGameData
3. Read uint32 at PlayerGameData + 0x44 (extraOffset) = SoulLevel

## Gotchas

- **Last-offset semantics differ** between `followPointerChain` (returns address), `ReadDeathCount` (returns value), and `ReadMemoryValue` (returns value at extra offset)
- **CheatEngine offset order is reversed** — CT shows offsets bottom-to-top, code uses top-to-bottom
- **Zero-length paths** (e.g. `"game_man": {}`) are resolved entirely via AOB, not via pointer chain
- **extraOffset in ReadMemoryValue** is applied AFTER the chain is fully resolved — it's the field offset within the final structure
