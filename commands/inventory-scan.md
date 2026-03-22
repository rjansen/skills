# Inventory Scan — Inventory Array Scanning

## When to use

- Understanding how inventory item quantities are read
- Adding inventory-based route checkpoints
- Debugging why an item isn't being detected in inventory

## Key files

- `internal/memreader/reader.go:860-933` — `ReadInventoryItemQuantity()`
- `internal/memreader/config.go:16-26` — `InventoryConfig` struct
- `internal/memreader/ds3_offsets.go:32-41` — inventory offset constants

## How it works

### Memory structure traversal

```
PlayerGameData (via AOB "player_game_data" path)
  + 0x3D0 = EquipInventoryData (inline struct)
    + 0x10: capacity (uint32) — total array slots
    + 0x14: keyItemStart (uint32) — index where key items begin
    + 0x18: listPtr (pointer) — dereference to get item array base
    + 0x20: count (uint32) — normal item count
```

### Two scan regions (`reader.go:920-930`)

1. **Normal items**: indices `0` to `count - 1`
2. **Key items**: indices `keyItemStart` to `capacity - 1`

Both regions are index ranges within one contiguous array — they share the same `listPtr` base address and entry layout. The scan checks normal items first, then key items.

### Entry layout (stride 0x10)

```
+0x00: (internal/unknown)
+0x04: TypeId (uint32) — item type identifier
+0x08: Quantity (uint32)
+0x0C: (padding)
```

### Scan algorithm

```go
for each entry in region:
    read TypeId at entry + 0x04
    if TypeId == target itemID:
        read Quantity at entry + 0x08
        return Quantity
return (0, nil)  // item not found — NOT an error
```

### InventoryConfig struct (`config.go:16-26`)

```go
type InventoryConfig struct {
    PathKey             string // "player_game_data"
    DataOffset          int64  // 0x3D0 — offset to EquipInventoryData
    CapacityOffset      int64  // 0x10
    KeyItemStartOffset  int64  // 0x14
    ListPtrOffset       int64  // 0x18
    CountOffset         int64  // 0x20
    ItemStride          int64  // 0x10
    TypeIdOffset        int64  // 0x04
    QuantityOffset      int64  // 0x08
}
```

### DS3 concrete values (`config.go:103-113`)

```go
Inventory: &InventoryConfig{
    PathKey:            "player_game_data",
    DataOffset:         0x3D0,  // DS3OffsetEquipInventoryData
    CapacityOffset:     0x10,   // DS3OffsetInvCapacity
    KeyItemStartOffset: 0x14,   // DS3OffsetInvKeyItemStart
    ListPtrOffset:      0x18,   // DS3OffsetInvListPtr
    CountOffset:        0x20,   // DS3OffsetInvCount
    ItemStride:         0x10,   // DS3InvItemStride
    TypeIdOffset:       0x04,   // DS3InvItemTypeIdOffset
    QuantityOffset:     0x08,   // DS3InvItemQuantityOffset
}
```

### TypeId prefix categories (from TGA CT v3.4.0)

| Prefix | Category | Example |
|--------|----------|---------|
| `0x0000xxxx`–`0x00F4xxxx` | Weapons | Sellsword Twinblades = `0x00F42400` |
| `0x10000000` | Protector/Armor | — |
| `0x2000xxxx` | Rings/Accessories | Chloranthy Ring = `0x20004E2A` |
| `0x4000xxxx` | Goods (consumables, materials, keys) | Ember = `0x400001F4` |

## Gotchas

- **`(0, nil)` means item not found** — this is normal, not an error. The item simply isn't in the player's inventory
- **Count capped at 8192** — safety limit to prevent runaway scans
- **TypeId is the FULL prefixed value** — `0x400001F4` for Ember, not `0x1F4`
- **Key items are in a separate region** — if you're looking for an Ashes item or key item and it's not found in normal items, it's in the key item region (indices `keyStart` to `capacity-1`)
- **Quantity for weapons/rings is typically 1** — they're counted by presence, not stacks
- **item_id in route JSON is decimal** — `0x400001F4` = `1073742324` in decimal
