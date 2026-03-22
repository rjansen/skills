# CT Extract — CheatEngine Cheat Table Data Extraction

## When to use

- Finding item IDs for inventory checkpoints
- Finding pointer chains for new memory paths
- Verifying AOB patterns against the CT
- Looking up event flag IDs

## Key file

- `C:\Users\rapha\Downloads\DS3_TGA_v3.4.0\DS3_TGA_v3.4.0.CT` — DS3 cheat table (XML format)

**Note**: This path is user-specific. The CT file location may vary — check the user's Downloads or CheatEngine directories.

## How it works

### CT file structure

The `.CT` file is XML with nested `<CheatEntries>` elements. Key sections:

```xml
<CheatEntry>
  <Description>"Entry Name"</Description>
  <Address>basePointer</Address>
  <Offsets>
    <Offset>0x88</Offset>    <!-- BOTTOM offset (applied last) -->
    <Offset>0x10</Offset>    <!-- TOP offset (applied first) -->
  </Offsets>
</CheatEntry>
```

### Finding item IDs

1. Search for the item name in the CT XML
2. Navigate the item category tree: Goods, Weapons, Armor, Rings
3. Each entry has a `<Value>` attribute — this is the base item ID
4. The TypeId = category prefix + base ID

**Category prefixes** (from CT dropdown structure):
| CT prefix | Category | Hex prefix |
|-----------|----------|------------|
| 00000000 | Weapon | `0x00000000`–`0x00F40000` |
| 10000000 | Protector | `0x10000000` |
| 20000000 | Accessory | `0x20000000` |
| 40000000 | Goods | `0x40000000` |

**Example**: Ember has Value `500` (decimal) = `0x1F4`. It's a Good, so full TypeId = `0x40000000 + 0x1F4 = 0x400001F4`.

### Finding pointer chains

1. Search for the data you want (e.g., "Soul Level", "Character Name")
2. Read the `<Offsets>` elements — **offsets are listed bottom-to-top**
3. Reverse the order for code: CT bottom = code first offset

**Example**: CT shows Character Name path as:
```
GameDataMan → Offset: 0x88 (bottom) → Offset: 0x10 (top)
```
In code: `offsets = {0x10}`, `extraOffset = 0x88`
(GameDataMan is resolved via AOB, 0x10 dereferences to PlayerGameData, 0x88 is the field offset)

### Finding AOB patterns

1. Search for `tga.baseData` or similar Lua script sections
2. Look for `AOBScanModule` calls with hex patterns
3. Note: Lua script patterns may use different notation than our config format

### Reading event flag IDs

1. Search for boss names or "defeated" in the CT
2. Flag IDs are typically stored as `<Value>` in the event flag entries
3. DS3 uses decimal flag IDs (e.g., `13000800`)

## Extraction workflow

### For a new item ID:
1. Open CT file, search for item name
2. Find the `<Value>` attribute
3. Determine category from tree hierarchy (Goods/Weapons/Rings)
4. Combine: `prefix | value` = full TypeId
5. Add as hex constant: `DS3Item<Name> uint32 = 0x4000XXXX`

### For a new pointer chain:
1. Find the entry in CT
2. Note all `<Offset>` elements
3. **Reverse the order** for code
4. Identify the base pointer (GameDataMan, GameMan, etc.)
5. Last offset becomes `extraOffset` in `ReadMemoryValue`

## Gotchas

- **Offset order is REVERSED** — CT shows bottom-to-top, code needs top-to-bottom
- **Values can be decimal or hex** — check context; item IDs are often decimal in CT
- **Lua scripts are harder to port** — AOB patterns in Lua may need manual translation
- **CT version matters** — offsets may differ between CT versions and game patches
- **The CT file is large XML** — use text search, don't try to parse the entire structure
- **Weapon TypeId ranges overlap** — weapons use multiple sub-prefixes (`0x00000000` through `0x00F40000`)
