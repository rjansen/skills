# Table Test Refactoring Guide

## Symptom → Fix Reference

| Symptom | Diagnosis | Fix |
|---|---|---|
| Struct has 6+ fields | Too many parameters | Split into multiple focused tables or use nested subtests |
| Same field value in all cases | Constant masquerading as variable | Move to constant or loop body |
| `if tt.flag` in loop body | Non-uniform cases | Split into separate test functions |
| Mock setup differs per case | Cases are not data-only | Use separate subtests with explicit setup |
| Test names are "case 1", "case 2" | Unclear intent | Rename to describe scenario: "empty input returns error" |
| Loop body > 10 lines | Too complex for table format | Extract to separate tests or helpers |
| One case has extra assertions | Mixed assertion patterns | Move that case to its own subtest |

## Splitting a Bloated Table

### Before — too many fields, mixed concerns

```go
tests := []struct {
    name      string
    input     string
    maxLen    int
    required  bool
    pattern   string
    wantErr   bool
    wantField string
    wantCode  int
}{
    {"valid", "hello", 10, true, ".*", false, "hello", 200},
    {"too long", "hello world", 5, true, ".*", true, "", 400},
    {"empty required", "", 10, true, ".*", true, "", 400},
    {"pattern mismatch", "hello", 10, false, "^\\d+$", true, "", 400},
}
```

### After — focused tables per concern

```go
func TestValidate_Length(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        maxLen  int
        wantErr bool
    }{
        {"within limit", "hello", 10, false},
        {"at limit", "hello", 5, false},
        {"exceeds limit", "hello world", 5, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validate(tt.input, WithMaxLen(tt.maxLen))
            if (err != nil) != tt.wantErr {
                t.Errorf("err = %v, wantErr = %v", err, tt.wantErr)
            }
        })
    }
}

func TestValidate_Required(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"non-empty", "hello", false},
        {"empty", "", true},
        {"whitespace only", "   ", true},
    }
    // ...
}

func TestValidate_Pattern(t *testing.T) {
    // ...
}
```

**Rule:** Each table should test one dimension of behavior. Combine dimensions only when the
interaction between them is what you are testing.

## Extracting Shared Setup

### Before — setup repeated in struct fields

```go
tests := []struct {
    name   string
    dbURL  string
    dbName string
    want   error
}{
    {"valid postgres", "localhost:5432", "mydb", nil},
    {"valid mysql", "localhost:3306", "mydb", nil},
    {"empty url", "", "mydb", ErrInvalidConfig},
}
```

### After — shared values as constants, only varying fields in struct

```go
const testDBName = "mydb"

tests := []struct {
    name    string
    dbURL   string
    wantErr error
}{
    {"valid postgres", "localhost:5432", nil},
    {"valid mysql", "localhost:3306", nil},
    {"empty url", "", ErrInvalidConfig},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        err := Connect(tt.dbURL, testDBName)
        // ...
    })
}
```

## Converting Between Subtests and Table Tests

### Explicit subtests → Table test

**Before:**

```go
func TestParse(t *testing.T) {
    t.Run("integer", func(t *testing.T) {
        got, err := Parse("42")
        if err != nil {
            t.Fatal(err)
        }
        if got != 42 {
            t.Errorf("got %d, want 42", got)
        }
    })
    t.Run("negative", func(t *testing.T) {
        got, err := Parse("-5")
        if err != nil {
            t.Fatal(err)
        }
        if got != -5 {
            t.Errorf("got %d, want -5", got)
        }
    })
    t.Run("zero", func(t *testing.T) {
        got, err := Parse("0")
        if err != nil {
            t.Fatal(err)
        }
        if got != 0 {
            t.Errorf("got %d, want 0", got)
        }
    })
}
```

**After:**

```go
func TestParse(t *testing.T) {
    tests := []struct {
        input string
        want  int
    }{
        {"42", 42},
        {"-5", -5},
        {"0", 0},
    }
    for _, tt := range tests {
        t.Run(tt.input, func(t *testing.T) {
            got, err := Parse(tt.input)
            if err != nil {
                t.Fatal(err)
            }
            if got != tt.want {
                t.Errorf("Parse(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

**When to convert:** Three or more subtests with identical assertion structure, differing only
in input/expected values.

### Table test → Explicit subtests

**When to convert back:**
- Adding a new case requires a field that no other case uses
- The loop body has grown past 10 lines
- Different cases need different mock setups
- A single case needs extra assertions that others do not

Split the anomalous case into its own subtest and keep the uniform cases in the table.

## Test Matrices (2D Tables)

For testing combinations of two dimensions:

```go
func TestPermission(t *testing.T) {
    roles := []string{"admin", "editor", "viewer"}
    actions := []string{"read", "write", "delete"}

    // expected[role][action] = allowed
    expected := map[string]map[string]bool{
        "admin":  {"read": true, "write": true, "delete": true},
        "editor": {"read": true, "write": true, "delete": false},
        "viewer": {"read": true, "write": false, "delete": false},
    }

    for _, role := range roles {
        for _, action := range actions {
            name := role + "/" + action
            t.Run(name, func(t *testing.T) {
                got := HasPermission(role, action)
                want := expected[role][action]
                if got != want {
                    t.Errorf("HasPermission(%q, %q) = %v, want %v", role, action, got, want)
                }
            })
        }
    }
}
```

Use matrices when:
- Two independent dimensions interact
- The expected behavior is naturally a grid
- All combinations should be tested

Avoid matrices when the number of meaningful combinations is small — just list them explicitly.

## Map-Based Tables for Property Testing

When testing a function against a known mapping:

```go
func TestHTTPStatusText(t *testing.T) {
    known := map[int]string{
        200: "OK",
        201: "Created",
        400: "Bad Request",
        404: "Not Found",
        500: "Internal Server Error",
    }
    for code, want := range known {
        t.Run(fmt.Sprintf("%d", code), func(t *testing.T) {
            got := http.StatusText(code)
            if got != want {
                t.Errorf("StatusText(%d) = %q, want %q", code, got, want)
            }
        })
    }
}
```

Maps are ideal when:
- Each case is an input→output pair with no other fields
- The input itself makes a good test name
- Order of test execution does not matter

**Caveat:** Map iteration order is non-deterministic. This is fine for independent tests but
problematic if tests are order-dependent (which they should not be).
