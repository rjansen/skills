# DS3 Read Inventory — Full Developer Workflow

## When to use

- Adding a new item to track in inventory for route checkpoints
- End-to-end workflow: find item ID → add constant → update tests → route JSON

## Steps

### Step 1: Find item ID in CT (`/ct-extract`)

1. Open `C:\Users\rapha\Downloads\DS3_TGA_v3.4.0\DS3_TGA_v3.4.0.CT` (XML)
2. Search for the item name
3. Find the `<Value>` attribute (often decimal)
4. Determine category: Goods (`0x40000000`), Rings (`0x20000000`), Weapons (varies)
5. Full TypeId = category prefix | base value

### Step 2: Add constant to `ds3_offsets.go`

Add to the appropriate section in `internal/memreader/ds3_offsets.go`:

```go
// For Goods (prefix 0x4000):
DS3Item<PascalCaseName> uint32 = 0x4000XXXX

// For Rings (prefix 0x2000):
DS3Item<PascalCaseName> uint32 = 0x2000XXXX

// For Weapons:
DS3Item<PascalCaseName> uint32 = 0x00F4XXXX  // (or other weapon prefix)
```

Naming convention: `DS3Item<PascalCaseName>` (e.g. `DS3ItemFirebomb`, `DS3ItemChloranthyRing`)

### Step 3: Add to `allItemIDs()` in `ds3_offsets_test.go`

Add entry to `allItemIDs()` function (line 260-290):

```go
{"<Name>", DS3Item<Name>},
```

Update count in `TestDS3ItemIDs_Count` (currently expects **18**):

```go
if len(items) != 19 {  // increment by 1
```

### Step 4: Add pinned value to `TestDS3ItemIDs_KnownValues`

Add to the expected slice in `TestDS3ItemIDs_KnownValues` (line 309-345):

```go
{"<Name>", DS3Item<Name>, 0x4000XXXX},
```

### Step 5: Add to e2e test `AllTrackedItems` table

In `internal/memreader/memreader_e2e_ds3_test.go`, add to `TestE2E_ReadInventoryItemQuantity_AllTrackedItems` items slice (line 1027-1052):

```go
{DS3Item<Name>, "<Display Name>"},
```

### Step 6: Use in route JSON

In route file (e.g. `routes/ds3-glitchless-any-percent-hybrid.json`):

```json
{
  "id": "get-item-name",
  "name": "Item Display Name",
  "event_type": "inventory_check",
  "inventory_check": {
    "item_id": 1073742116,
    "comparison": "gte",
    "value": 1
  }
}
```

**Important**: `item_id` in JSON is **decimal**. Convert hex → decimal (e.g. `0x40000124` = `1073742116`).

Supported comparisons: `"gte"`, `"gt"`, `"eq"`

### Step 7: Run tests

```bash
make test
```

Verify:
- `TestDS3ItemIDs_Count` passes with new count
- `TestDS3ItemIDs_NoDuplicates` passes
- `TestDS3ItemIDs_KnownValues` passes with pinned value
- `TestDS3ItemIDs_GoodsPrefix` passes (if goods item)

### Step 8: Update integration test if used in route

If the item is referenced in a route checkpoint's `inventory_check`, add its expected `item_id` to `route_integration_test.go`. Specifically, add the item constant to the expected inventory items map in `TestDS3Route_InventoryCheckItemsMatchConstants` so the integration test validates the route JSON references the correct constant value.

## File modification order

1. `internal/memreader/ds3_offsets.go` — add constant
2. `internal/memreader/ds3_offsets_test.go` — add to `allItemIDs()`, update count, add pinned value
3. `internal/memreader/memreader_e2e_ds3_test.go` — add to AllTrackedItems
4. Route JSON file — add checkpoint
5. `internal/route/route_integration_test.go` — update expected maps if needed

## Related skills

- `/ct-extract` — finding item IDs in the CheatEngine table
- `/inventory-scan` — understanding the inventory memory layout
