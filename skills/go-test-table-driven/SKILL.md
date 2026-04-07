---
name: go-test-table-driven
description: >
  This skill should be used when the user asks to "write a table-driven test",
  "create test cases", "parametrize Go tests", "refactor test tables",
  "design a test matrix", "add data-driven tests", or mentions test case structs,
  subtests with range loops, wantErr patterns, or table test anti-patterns.
  Focused specifically on the table-driven testing idiom — for general test
  quality and patterns use go-test-quality instead.
---

# Go Table-Driven Tests

Table-driven tests are Go's primary idiom for testing multiple inputs through the same
assertion logic. This skill covers when to use them, how to structure the test case table,
and when to refactor away from them.

## Resolve References

Locate this skill's reference files before starting. Run:
Glob for `~/.claude/**/go-test-table-driven/references/*.md`

This returns the absolute path for `refactoring-guide.md`. Store this path —
all later "Read references/" instructions mean "Read the file at its
resolved absolute path."

If Glob returns no results, try: `Glob for **/go-test-table-driven/references/*.md`

## When Table Tests Shine

Use a table-driven test when ALL four conditions hold:

1. **Same function under test** across all cases
2. **Identical assertion pattern** for every case
3. **Cases differ only in data** — inputs, expected outputs, error conditions
4. **Three or more cases** — fewer than 3 does not justify the overhead

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive numbers", 2, 3, 5},
        {"negative numbers", -1, -2, -3},
        {"zero", 0, 0, 0},
        {"mixed signs", -1, 5, 4},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

## When NOT to Use Table Tests

- **Complex per-case setup** — if each case needs different mock behavior, a helper function, or unique teardown, use separate subtests
- **Fewer than 3 cases** — the overhead of defining a struct is not worth it
- **Multiple branching paths in the loop body** — if the loop has `if tt.someFlag { ... } else { ... }`, the cases are not truly uniform
- **Each case tests a different function** — table tests are for one function, multiple inputs

## Test Case Struct Design

### Every field must vary

**Critical rule:** Every field in the struct should change between at least two test cases. If a field has the same value in all cases, it is setup — move it to the loop body or a constant.

```go
// BAD — timeout is the same in every case
tests := []struct {
    name    string
    input   string
    timeout time.Duration // always 5s
    want    string
}{
    {"case 1", "a", 5 * time.Second, "A"},
    {"case 2", "b", 5 * time.Second, "B"},
}

// GOOD — timeout moved to constant, only varying fields in struct
const testTimeout = 5 * time.Second
tests := []struct {
    name  string
    input string
    want  string
}{
    {"case 1", "a", "A"},
    {"case 2", "b", "B"},
}
```

### Descriptive field names

Use names that describe what the value means, not its type:

```go
// Weak
tests := []struct {
    s    string
    n    int
    want bool
}{ ... }

// Strong
tests := []struct {
    name     string
    email    string
    maxLen   int
    wantValid bool
}{ ... }
```

### Error assertion patterns

**Simple: wantErr bool**

When only checking whether an error occurred:

```go
tests := []struct {
    name    string
    input   string
    want    int
    wantErr bool
}{
    {"valid", "42", 42, false},
    {"invalid", "abc", 0, true},
    {"empty", "", 0, true},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got, err := Parse(tt.input)
        if (err != nil) != tt.wantErr {
            t.Fatalf("err = %v, wantErr = %v", err, tt.wantErr)
        }
        if !tt.wantErr && got != tt.want {
            t.Errorf("got %d, want %d", got, tt.want)
        }
    })
}
```

**Specific: wantErrIs sentinel**

When checking for a specific error type:

```go
tests := []struct {
    name      string
    id        string
    wantErrIs error // nil means no error expected
}{
    {"found", "123", nil},
    {"not found", "999", ErrNotFound},
    {"invalid id", "", ErrValidation},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        _, err := store.Get(tt.id)
        if tt.wantErrIs != nil {
            if !errors.Is(err, tt.wantErrIs) {
                t.Fatalf("err = %v, want %v", err, tt.wantErrIs)
            }
            return
        }
        if err != nil {
            t.Fatalf("unexpected error: %v", err)
        }
    })
}
```

## Loop Body Must Be Trivial

The loop body should be under 10 lines with zero conditionals (except the `wantErr` check).
If the body needs `if tt.setupMock { ... }` or `switch tt.mode { ... }`, the cases are not
uniform — split into separate test functions.

**Red flag indicators:**
- Loop body exceeds 10 lines of real logic
- Multiple `if` branches based on test case fields
- Different assertion patterns for different cases
- Mock setup varies significantly per case

## Parallel Table Tests

Mark table subtests as parallel for faster execution:

```go
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        got := Process(tt.input)
        if got != tt.want {
            t.Errorf("got %v, want %v", got, tt.want)
        }
    })
}
```

**Go 1.22+ note:** Loop variables are per-iteration by default. No `tt := tt` copy needed.

**Pre-Go 1.22:** Capture the loop variable to avoid data races:

```go
for _, tt := range tests {
    tt := tt // capture
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        // ...
    })
}
```

## Compact Formats

### Aligned struct literals

For simple cases with few fields, align values for readability:

```go
tests := []struct {
    input string
    want  int
}{
    {"one",   1},
    {"two",   2},
    {"three", 3},
}
```

### Map-based tables

For ultra-simple input→output tests:

```go
tests := map[string]int{
    "one":   1,
    "two":   2,
    "three": 3,
}
for input, want := range tests {
    t.Run(input, func(t *testing.T) {
        if got := Parse(input); got != want {
            t.Errorf("Parse(%q) = %d, want %d", input, got, want)
        }
    })
}
```

### Error-only slices

When testing multiple inputs that should all fail:

```go
badInputs := []string{"", " ", "invalid", "12345678901234567890"}
for _, input := range badInputs {
    t.Run(input, func(t *testing.T) {
        if _, err := Validate(input); err == nil {
            t.Errorf("Validate(%q) = nil, want error", input)
        }
    })
}
```

## Decision Flowchart

1. **Same function for all cases?** No → separate test functions
2. **Same assertion for all cases?** No → separate subtests
3. **3+ cases?** No → inline subtests (simpler than a table)
4. **Loop body under 10 lines?** No → split into separate tests
5. **Under 5 struct fields?** No → consider if some fields should be constants
6. **All fields vary?** No → move constants out of the struct

All yes → table-driven test is the right choice.

## Verification Checklist

- [ ] Every struct field varies across at least two cases
- [ ] Loop body is under 10 lines with no branching (except wantErr)
- [ ] Test names describe the scenario, not "case 1", "case 2"
- [ ] Happy path, error cases, and edge cases are all covered
- [ ] `t.Parallel()` is used when cases are independent (with loop variable capture pre-Go 1.22)
- [ ] `errors.Is` used for sentinel error assertions, not string comparison

## Additional Resources

### Reference Files

Paths resolved in Resolve References section. Read when needed:
- **`references/refactoring-guide.md`** — Symptom→fix table with before/after code, splitting bloated tables, test matrices, and converting between subtests and table tests
