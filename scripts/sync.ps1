# Sync Claude Code skills plugin to ~/.claude/
# Usage: .\scripts\sync.ps1 [-Mirror]
#   Default: copy only new/updated files (install)
#   -Mirror: full sync, deletes extras at destination

param(
    [switch]$Mirror
)

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE ".claude"
$Dirs = @("commands", "agents", "skills")

if ($Mirror) {
    $Mode = "Mirror"
    $Flags = @("/MIR", "/NJH", "/NJS", "/NP")
} else {
    $Mode = "Install"
    $Flags = @("/E", "/XO", "/NJH", "/NJS", "/NP")
}

Write-Host "$Mode skills to $ClaudeHome ..."

foreach ($d in $Dirs) {
    $src = Join-Path $RepoDir $d
    $dst = Join-Path $ClaudeHome $d

    if (-not (Test-Path $src)) {
        Write-Host "  skip $d (not found)"
        continue
    }

    Write-Host "  $d"
    & robocopy $src $dst @Flags | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Error "robocopy failed for $d (exit code $LASTEXITCODE)"
        exit 1
    }
}

Write-Host "Done."
