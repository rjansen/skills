# DS3 Read Event Flag — Full Developer Workflow

## When to use

- Adding a new boss kill or encounter flag for route checkpoints
- End-to-end workflow: find flag ID → add constant → update tests → route JSON

## Steps

### Step 1: Find flag ID

Sources for DS3 event flag IDs:
- SoulSplitter source code (github.com/CapitaineToinworst/SoulSplitter)
- DS3 cheat tables (TGA CT v3.4.0)
- Community wikis and speedrun resources
- CheatEngine event flag scanning

Boss defeated flags follow the pattern `XXYYYZZZ` where:
- `XX` = div10M (always 1 for DS3)
- `YYY` = area code (e.g. 300 = High Wall, 330 = Farron)
- `ZZZ` = suffix: 800, 830, 850, 860, or 890

### Step 2: Add constants to `ds3_offsets.go`

In `internal/memreader/ds3_offsets.go`:

```go
// Defeated flag:
DS3Flag<BossName> uint32 = XXXXXXXX

// Encountered flag (if known):
DS3Flag<BossName>Enc uint32 = XXXXXXXX
```

Encountered = defeated + 1, except for `XXX50` suffix where encountered = defeated + 2.

8 bosses have **no known encounter flag**: Pontiff, Aldrich, Dancer, Ancient Wyvern, Nameless King, Dragonslayer Armour, Demon Prince, Old Demon King. Don't add `Enc` constants for these.

### Step 3: Add to helper functions in `ds3_offsets_test.go`

Add to `allDefeatedFlags()` (line 9-45):
```go
{"<BossName>", DS3Flag<BossName>},
```

If encounter flag exists, add to `allEncounteredFlags()` (line 48-74):
```go
{"<BossName>Enc", DS3Flag<BossName>Enc},
```

### Step 4: Update count tests

In `TestDS3BossFlags_Count` (line 76-86):
```go
// Currently: 25 defeated, 17 encountered
if len(defeated) != 26 {  // increment
```

### Step 5: Add pinned values

Add to `TestDS3BossFlags_KnownValues` (line 179-223):
```go
{"<BossName>", DS3Flag<BossName>, XXXXXXXX},
```

If encounter flag exists, add to `TestDS3BossFlags_KnownEncounteredValues` (line 225-258):
```go
{"<BossName>Enc", DS3Flag<BossName>Enc, XXXXXXXX},
```

### Step 6: Add to e2e tests

In `internal/memreader/memreader_e2e_ds3_test.go`:

Add to `TestE2E_ReadEventFlag_MultipleBosses` bosses slice (line 87-118):
```go
{DS3Flag<BossName>, "<Boss Display Name>"},
```

If encounter flag exists, add to `TestE2E_ReadEventFlag_AllEncountered` (line 136-157):
```go
{DS3Flag<BossName>Enc, "<BossName> Enc"},
```

### Step 7: Use in route JSON

```json
{
  "id": "boss-name",
  "name": "Boss Display Name",
  "event_type": "boss_kill",
  "event_flag_id": 13000800,
  "backup_flag_id": 13000801
}
```

- `event_flag_id` = defeated flag (decimal)
- `backup_flag_id` = encountered flag (decimal) — omit if no encounter flag exists
- If no `backup_flag_id`, save backup triggers on kill instead of encounter

### Step 8: Update route integration tests

In `internal/route/route_integration_test.go`:

Add to `expectedFlags` map in `TestDS3Route_CheckpointFlagsMatchConstants` (line 46-60):
```go
"boss-id": memreader.DS3Flag<BossName>,
```

Add to `expectedBackup` map in `TestDS3Route_BackupFlagsMatchEncounteredConstants` (line 84-99):
```go
"boss-id": memreader.DS3Flag<BossName>Enc,  // or 0 if no encounter flag
```

### Step 9: Run tests

```bash
make test
```

## File modification order

1. `internal/memreader/ds3_offsets.go` — add flag constants
2. `internal/memreader/ds3_offsets_test.go` — add to helpers, update counts, add pinned values
3. `internal/memreader/memreader_e2e_ds3_test.go` — add to e2e test tables
4. Route JSON file — add checkpoint
5. `internal/route/route_integration_test.go` — update expected flag maps

## Related skills

- `/event-flag-read` — the event flag reading algorithm
- `/ct-extract` — finding flag IDs in CheatEngine tables
