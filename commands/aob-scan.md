# AOB Scan — Array of Bytes Pattern Scanning

## When to use

- Adding a new AOB pattern to find a game structure
- Debugging why an AOB scan fails
- Understanding how game pointers are resolved dynamically

## Key files

- `internal/memreader/aob.go` — all AOB scanning code
- `internal/memreader/config.go:3-10` — `AOBPointerConfig` struct

## How it works

### Pattern syntax

Hex bytes separated by spaces. `?` or `??` = wildcard (matches any byte).

```
"48 c7 05 ? ? ? ? 00 00 00 00"
```

### Algorithm (`aob.go`)

1. **Parse PE header** (`findTextSection`, line 91-145):
   - Read DOS header → `e_lfanew` at offset `0x3C`
   - Read PE header → `NumberOfSections` at `+0x6`, `SizeOfOptionalHeader` at `+0x14`
   - Iterate section headers (40 bytes each) looking for `.text` name
   - Return `virtualAddress` and `virtualSize`

2. **Chunked scan** (`ScanForPointer`, line 152-207):
   - Read `.text` section in `aobChunkSize` (64KB) chunks
   - Each chunk includes `patLen - 1` bytes of overlap (handles boundary-spanning patterns)
   - `scanAOB` does linear byte-by-byte comparison with mask

3. **RIP-relative resolution** (`resolveRelativePtr`, line 76-82):
   ```
   targetAddr = matchAddr + instrLen + int32_displacement
   ```
   - `matchAddr` = absolute address where pattern was found
   - `instrLen` = total instruction length (NOT pattern length!)
   - `int32_displacement` = read 4 bytes at `matchOffset + relativeOffsetPos`

### AOBPointerConfig fields

```go
type AOBPointerConfig struct {
    Pattern           string   // Primary hex pattern
    FallbackPatterns  []string // Additional patterns tried if primary fails
    RelativeOffsetPos int      // Byte position of int32 displacement in pattern
    InstrLen          int      // Total instruction length for RIP calc
    Dereference       bool     // True = read pointer at resolved addr
}
```

### Fallback mechanism (`reader.go:239-258`)

`scanWithFallbacks()` tries primary pattern first, then each fallback in order. All patterns share the same `RelativeOffsetPos` and `InstrLen`.

### Current DS3 patterns (config.go)

| Structure | Pattern purpose | InstrLen | Dereference |
|-----------|----------------|----------|-------------|
| SprjEventFlagMan | `mov [rip+?], 0` (clear on shutdown) | 11 | true |
| FieldArea | `mov r15, [rip+?]` (load for world lookup) | 7 | false |
| GameMan | `mov reg, [rip+?]` (load singleton) | 7 | true |
| GameDataMan | `mov rax/rbx, [rip+?]` (6 fallback patterns) | 7 | true |

## Gotchas

- **`instrLen` ≠ pattern byte count** — `instrLen` is the x86 instruction length, not the number of pattern bytes. The SprjEventFlagMan pattern is 28 bytes but `instrLen=11`
- **Pattern must be unique** in `.text` section — multiple matches cause first-match behavior
- **Chunk overlap** handles patterns spanning 64KB boundaries, but overlap size = patLen-1
- **Cache lifetime** — results cached per attach, cleared on `Detach()`
- **Dereference meaning** — when `true`, the resolved address is a pointer TO the singleton (needs one more dereference to get the actual object)
