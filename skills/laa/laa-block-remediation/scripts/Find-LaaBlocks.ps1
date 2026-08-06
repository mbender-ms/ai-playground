<#
.SYNOPSIS
    Find open PRs authored by AND assigned to a GitHub user that have unresolved
    Learn Authoring Assistant (LAA) suggestion blocks, and extract each violation + fix.

.DESCRIPTION
    LAA posts inline review comments from a learn-build-service-prod-*[bot] account containing a
    ```suggestion code block. These block the PR until accepted/rejected. This script discovers those
    comments across the user's own open PRs and writes a JSON array describing each one.

    Requires: gh CLI (authenticated) and pwsh.

.PARAMETER Owner
    Repository owner. Default: MicrosoftDocs.

.PARAMETER Repo
    Repository name. Default: azure-docs-pr.

.PARAMETER Login
    GitHub login to scope author+assignee. Default: auto-detected via `gh api user`.

.PARAMETER OutFile
    Path to write the JSON array. Default: $env:TEMP/laa-blocks.json.

.OUTPUTS
    Writes JSON to -OutFile and prints a per-PR summary to stdout.
#>
[CmdletBinding()]
param(
    [string]$Owner = 'MicrosoftDocs',
    [string]$Repo = 'azure-docs-pr',
    [string]$Login = '',
    [string]$OutFile = "$env:TEMP/laa-blocks.json"
)

$ErrorActionPreference = 'Stop'

function Assert-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "gh CLI not found. Install GitHub CLI and run 'gh auth login'."
    }
    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "gh is not authenticated. Run 'gh auth login' and retry."
    }
}

Assert-Gh

if ([string]::IsNullOrWhiteSpace($Login)) {
    $Login = (gh api user --jq .login).Trim()
    if ([string]::IsNullOrWhiteSpace($Login)) { throw "Could not resolve GitHub login via 'gh api user'." }
}

Write-Host "Scanning open PRs authored by and assigned to '$Login' in $Owner/$Repo ..."

# 1. Find candidate PRs (author AND assignee = login, open).
$searchJson = gh search prs --author $Login --assignee $Login --state open "repo:$Owner/$Repo" --limit 200 --json number
$prNumbers = @()
if ($searchJson) { $prNumbers = ($searchJson | ConvertFrom-Json).number }
Write-Host ("Candidate PRs: {0}" -f $prNumbers.Count)

$laaUserPattern = 'learn-build|openpublish'
$results = New-Object System.Collections.Generic.List[object]
$branchCache = @{}

foreach ($n in ($prNumbers | Sort-Object)) {
    # Branch (cached per PR)
    if (-not $branchCache.ContainsKey($n)) {
        try {
            $pv = gh pr view $n --repo "$Owner/$Repo" --json headRefName | ConvertFrom-Json
            $branchCache[$n] = $pv.headRefName
        } catch { $branchCache[$n] = $null }
    }
    $branch = $branchCache[$n]

    # Inline review comments
    $comments = @()
    try {
        $raw = gh api "repos/$Owner/$Repo/pulls/$n/comments?per_page=100" 2>$null
        if ($raw) { $comments = $raw | ConvertFrom-Json }
    } catch { continue }

    $laa = @($comments | Where-Object {
        $_.user.login -match $laaUserPattern -and $_.body -match '```suggestion'
    })

    foreach ($c in $laa) {
        # Original flagged text = last non-@@ line of the diff hunk (the changed line).
        $orig = ''
        if ($c.diff_hunk) {
            $hunkLines = $c.diff_hunk -split "`n"
            $lastLine = ($hunkLines | Where-Object { $_ -notmatch '^@@' } | Select-Object -Last 1)
            if ($null -ne $lastLine) { $orig = ($lastLine -replace '^[+ ]', '').Trim() }
        }

        # Suggested replacement (supports multi-line suggestions).
        $fix = ''
        if ($c.body -match '(?s)```suggestion\r?\n(.*?)```') { $fix = $Matches[1].TrimEnd() }

        # Rule tag (best effort).
        $rule = 'General'
        if ($c.body -match 'Rules?:\s*`?([A-Za-z_]+)`?') { $rule = $Matches[1] }

        # Outdated => comment no longer maps to a current diff line (often already fixed).
        $outdated = ($null -eq $c.position)

        $results.Add([pscustomobject]@{
            PR       = $n
            Branch   = $branch
            Path     = ($c.path -replace '^articles/', '')
            FullPath = $c.path
            Rule     = $rule
            Orig     = $orig
            Fix      = $fix
            Outdated = $outdated
            Url      = $c.html_url
        }) | Out-Null
    }
}

# Write JSON (array even if single/empty).
$json = if ($results.Count -eq 0) { '[]' } else { $results | ConvertTo-Json -Depth 6 }
Set-Content -Path $OutFile -Value $json -Encoding UTF8

# Summary
Write-Host ""
Write-Host ("LAA suggestion blocks: {0} across {1} PR(s)" -f $results.Count, (@($results | Select-Object -ExpandProperty PR -Unique).Count))
$results | Group-Object PR | Sort-Object { [int]$_.Name } | ForEach-Object {
    $applied = @($_.Group | Where-Object { $_.Outdated }).Count
    "  #{0} [{1}]: {2} suggestion(s){3}" -f $_.Name, $_.Group[0].Branch, $_.Count, ($(if ($applied) { " ($applied likely already applied)" } else { '' }))
}
Write-Host ""
Write-Host "JSON written to: $OutFile"
