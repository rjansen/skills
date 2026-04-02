# Interactive installer for Claude Code skills plugin
# Lets the user select individual components to install

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot
Set-Location $RepoDir

$ClaudeHome = Join-Path $env:USERPROFILE ".claude"

# Discovery
$Items = @()

foreach ($f in (Get-ChildItem -Path "commands\*.md" -ErrorAction SilentlyContinue)) {
    $Items += [PSCustomObject]@{
        Name     = $f.BaseName
        Category = "Command"
        Source   = $f.FullName
        Selected = $true
    }
}

foreach ($f in (Get-ChildItem -Path "agents\*.md" -ErrorAction SilentlyContinue)) {
    $Items += [PSCustomObject]@{
        Name     = $f.BaseName
        Category = "Agent"
        Source   = $f.FullName
        Selected = $true
    }
}

foreach ($skill in (Get-ChildItem -Path "skills\*\SKILL.md" -ErrorAction SilentlyContinue)) {
    $skillDir = $skill.Directory
    $Items += [PSCustomObject]@{
        Name     = $skillDir.Name
        Category = "Skill"
        Source   = $skillDir.FullName
        Selected = $true
    }
}

if ($Items.Count -eq 0) {
    Write-Host "No components found to install."
    exit 0
}

function Show-Menu {
    Clear-Host
    Write-Host "Claude Code Skills Installer" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""

    $currentCat = ""
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].Category -ne $currentCat) {
            $currentCat = $Items[$i].Category
            Write-Host ""
            Write-Host "  ${currentCat}s" -ForegroundColor Yellow
            Write-Host "  --------"
        }
        $mark = if ($Items[$i].Selected) { "x" } else { " " }
        $num = $i + 1
        Write-Host ("   [{0}] {1,2}) {2}" -f $mark, $num, $Items[$i].Name)
    }

    Write-Host ""
    Write-Host "  a) select all    n) deselect all"
    Write-Host "  i) install       q) quit"
    Write-Host ""
}

# Selection loop
while ($true) {
    Show-Menu
    $input = Read-Host "  Toggle items (e.g. '3' or '1 4 7')"

    switch -Regex ($input.Trim()) {
        "^[aA]$" {
            foreach ($item in $Items) { $item.Selected = $true }
        }
        "^[nN]$" {
            foreach ($item in $Items) { $item.Selected = $false }
        }
        "^[qQ]$" {
            Write-Host "Cancelled."
            exit 0
        }
        "^[iI]$" {
            break
        }
        default {
            foreach ($token in $input.Trim() -split '\s+') {
                $num = 0
                if ([int]::TryParse($token, [ref]$num) -and $num -ge 1 -and $num -le $Items.Count) {
                    $Items[$num - 1].Selected = -not $Items[$num - 1].Selected
                }
            }
        }
    }

    # 'break' inside switch only breaks the switch, need to check again
    if ($input.Trim() -match "^[iI]$") { break }
}

# Install selected items
$selected = $Items | Where-Object { $_.Selected }

if ($selected.Count -eq 0) {
    Write-Host ""
    Write-Host "  (nothing selected)"
    exit 0
}

Write-Host ""
Write-Host "Will install:"
foreach ($item in $selected) {
    Write-Host "  - $($item.Category): $($item.Name)"
}

Write-Host ""
$confirm = Read-Host "Proceed? [Y/n]"
if ($confirm -match "^[nN]") {
    Write-Host "Cancelled."
    exit 0
}

Write-Host ""
foreach ($item in $selected) {
    if ($item.Category -eq "Skill") {
        $dst = Join-Path $ClaudeHome "skills\$($item.Name)"
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        & robocopy $item.Source $dst /E /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Write-Error "robocopy failed for $($item.Name) (exit code $LASTEXITCODE)"
            exit 1
        }
        Write-Host "  installed skill: $($item.Name)"
    }
    else {
        $catDir = if ($item.Category -eq "Command") { "commands" } else { "agents" }
        $dstDir = Join-Path $ClaudeHome $catDir
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Copy-Item -Path $item.Source -Destination (Join-Path $dstDir (Split-Path $item.Source -Leaf)) -Force
        Write-Host "  installed $($item.Category.ToLower()): $($item.Name)"
    }
}

Write-Host ""
Write-Host "Done. Installed $($selected.Count) item(s) to $ClaudeHome"
