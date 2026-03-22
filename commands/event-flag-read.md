# Event Flag Read — DS3 Hierarchical Event Flag Algorithm

## When to use

- Understanding how boss kill/encounter flags are read
- Debugging why a specific event flag isn't being detected
- Porting the event flag system to a new game

## Key files

- `internal/memreader/reader.go:262-363` — `ReadEventFlag()`
- `internal/memreader/reader.go:367-481` — `lookupFieldAreaCategory()`
- `internal/memreader/ds3_offsets.go:44-62` — flag structure constants

## How it works

### Flag ID decomposition (`reader.go:274-279`)

A flag ID like `13000800` is decomposed into:

```
flagID = 13000800
div10M    = (flagID / 10000000) % 10  = 1      → array index
area      = (flagID / 100000) % 100   = 30     → world area
block     = (flagID / 10000) % 10     = 0      → block within area
div1K     = (flagID / 1000) % 10      = 0      → data offset multiplier
remainder = flagID % 1000             = 800    → bit position encoding
```

### Category resolution (`reader.go:281-293`)

Two paths:
- **Global flag** (`area >= 90` or `area + block == 0`): `category = 0`
- **Area flag** (all boss flags): look up via FieldArea → `category = lookupResult + 1`

### FieldArea traversal (`reader.go:367-481`)

```
FieldArea → deref [0x0] → deref [+0x10] = worldInfoOwner
worldInfoOwner → size at [+0x08], vector ptr at [+0x10]
for each entry (stride 0x38):
    read area byte at [+0x0B]
    if matches → scan block sub-vector:
        block count at [+0x20], vector ptr at [+0x28]
        for each block (stride 0x70):
            packed flag at [+0x08]: area = (flag >> 24) & 0xFF, block = (flag >> 16) & 0xFF
            if area+block match → return category at [+0x20]
```

### Flag data navigation (`reader.go:299-362`)

```
SprjEventFlagMan (AOB or static) → resolved base
base + 0x218 (FlagArray) → deref
+ (div10M * 0x18) → deref  (array entry for this 10M range)
+ (div1K << 4) + (category * 0xA8) → deref  (flag data pointer)
+ ((remainder >> 5) * 4) → read uint32
check bit: (0x1F - (remainder & 0x1F))
```

### Bit extraction

```go
dwordIndex := (remainder >> 5) * 4     // which uint32 in the data
bitIndex   := 0x1f - (remainder & 0x1f) // which bit (reversed order)
mask       := uint32(1) << uint(bitIndex)
isSet      := (value & mask) != 0
```

## DS3 boss flag patterns

### Defeated flag suffixes

| Suffix | Example | Boss |
|--------|---------|------|
| 800 | 13000800 | Vordt |
| 830 | 13800830 | Old Demon King |
| 850 | 13300850 | Crystal Sage |
| 860 | 14500860 | Friede |
| 890 | 13000890 | Dancer |

### Encountered flag offsets

- For `XXX00` suffix: encountered = defeated + 1 (e.g. 13000800 → 13000801)
- For `XXX30` suffix: encountered = defeated + 1 (e.g. 13800830 → 13000831)
- For `XXX50` suffix: encountered = defeated + **2** (e.g. 13300850 → 13300852)
- For `XXX60` suffix: encountered = defeated + 1 (e.g. 14500860 → 14500861)
- For `XXX90` suffix: encountered = defeated + 1 (e.g. 13000890 → 13000891)

### Bosses with no known encounter flag (8 of 25)

Pontiff, Aldrich, Dancer, Ancient Wyvern, Nameless King, Dragonslayer Armour, Demon Prince, Old Demon King. Omit `backup_flag_id` for these in route JSON.

## Structure offset constants (`ds3_offsets.go:44-62`)

```
DS3OffsetFlagArray      = 0x218  // SprjEventFlagMan → flag array
DS3FlagArrayEntryStride = 0x18   // per-entry stride
DS3FlagCategoryStride   = 0xA8   // category stride in data

DS3OffsetFieldAreaPtr    = 0x10  // FieldArea → world info
DS3OffsetWorldInfoSize   = 0x08  // entry count
DS3OffsetWorldInfoVector = 0x10  // vector pointer
DS3WorldInfoEntrySize    = 0x38  // entry stride
DS3OffsetWorldInfoArea   = 0x0B  // area byte
DS3OffsetBlockCount      = 0x20  // block count
DS3OffsetBlockVector     = 0x28  // block vector
DS3BlockEntrySize        = 0x70  // block entry stride
DS3OffsetBlockFlag       = 0x08  // packed area/block
DS3OffsetBlockCategory   = 0x20  // category field
```

## Gotchas

- **Flag IDs are decimal** — `13000800` not `0x13000800`
- **Category off-by-one** — FieldArea returns 0-based, but code adds +1 for non-global flags
- **Algorithm is ported from SoulSplitter** — reference implementation in C#
- **ErrNullPointer** during FieldArea traversal means the game world isn't loaded yet
- **Only works for 64-bit games** — `ReadEventFlag` checks `r.is64Bit`
