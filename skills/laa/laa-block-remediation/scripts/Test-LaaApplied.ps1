<#
.SYNOPSIS
    Report whether each LAA suggestion for a given PR is already applied in the currently checked-out branch.

.DESCRIPTION
    Reads the JSON produced by Find-LaaBlocks.ps1 and, for the specified PR, inspects the working-tree files.
    For each suggestion it reports:
      APPLIED   - the suggested Fix text is present (skip it)
      NEEDS-FIX - the original Orig text is still present (apply it)
      NOT-FOUND - neither found; the file drifted, inspect manually

    Run this AFTER checking out the PR's branch so the working tree reflects the latest committed content.

.PARAMETER Json
    Path to the JSON file from Find-LaaBlocks.ps1.

.PARAMETER Pr
    The PR number to check.

.PARAMETER RepoRoot
    Root of the local repo clone (contains the 'articles' folder). Default: current directory.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Json,
    [Parameter(Mandatory)][int]$Pr,
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Json)) { throw "JSON file not found: $Json" }
$items = @((Get-Content $Json -Raw | ConvertFrom-Json) | Where-Object { [int]$_.PR -eq $Pr })
if ($items.Count -eq 0) { Write-Host "No suggestions found for PR #$Pr in $Json"; return }

$needFix = 0; $applied = 0; $notFound = 0

foreach ($it in $items) {
    $rel = if ($it.FullPath) { $it.FullPath } else { "articles/$($it.Path)" }
    $file = Join-Path $RepoRoot $rel
    $status = 'NOT-FOUND'
    if (Test-Path $file) {
        # Compare against whole (trimmed) file lines rather than substring Contains.
        # Substring matching would falsely report APPLIED when a fix is a substring of the
        # original (for example, removing a trailing period), causing a needed fix to be skipped.
        $lines = Get-Content $file | ForEach-Object { $_.Trim() }
        $fixKey  = ($it.Fix  -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
        $origKey = ($it.Orig -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
        if ($fixKey -and ($lines -contains $fixKey)) { $status = 'APPLIED' }
        elseif ($origKey -and ($lines -contains $origKey)) { $status = 'NEEDS-FIX' }
    }
    switch ($status) {
        'APPLIED'   { $applied++ }
        'NEEDS-FIX' { $needFix++ }
        default     { $notFound++ }
    }
    "{0,-10} {1}`n           orig: {2}`n           fix:  {3}" -f $status, $it.Path, $it.Orig, ($it.Fix -replace "`n", ' ')
}

Write-Host ""
Write-Host ("PR #{0}: {1} NEEDS-FIX, {2} APPLIED, {3} NOT-FOUND" -f $Pr, $needFix, $applied, $notFound)
