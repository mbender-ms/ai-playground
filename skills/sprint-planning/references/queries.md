# Queries — board snapshot and velocity

Every example below is parameterized. Load `config.json` once and bind these variables before
running anything — never paste an org, email, or area path inline:

```powershell
$cfg     = Get-Content "$PSScriptRoot\..\config.json" -Raw | ConvertFrom-Json
$org     = $cfg.ado.org
$project = $cfg.ado.project
$owner   = $cfg.owner.email
```

`$sprint` and `$nextSprint` come from the Phase 0 iteration-path calculation.

## Verify iteration nodes

The flat `--query` filters against this endpoint silently return nothing when the shape doesn't match. Walk the tree recursively instead — it always works:

```powershell
$n = az boards iteration project list --organization $org --project $project --depth 4 -o json | ConvertFrom-Json
function Walk($x, $p) {
  $cur = if ($p) { "$p\$($x.name)" } else { $x.name }
  if ($cur -match $fiscalYear) { $cur }
  foreach ($c in $x.children) { Walk $c $cur }
}
Walk $n $null
```

Set `$fiscalYear` to the year you're planning, for example `'FY27'`.

## Board snapshot — open items across two sprints

Query the planned sprint and the next one together. Planning one in isolation pushes work into an already-overloaded next month with no signal.

```powershell
$wiql = "SELECT [System.Id] FROM WorkItems " +
        "WHERE [System.IterationPath] IN ('$sprint','$nextSprint') " +
        "AND [System.AssignedTo] = '$owner' " +
        "AND [System.State] NOT IN ('Closed','Removed','Resolved') " +
        "ORDER BY [System.IterationPath], [System.Id]"

az boards query --organization $org --project $project --wiql $wiql --query "[].id" -o json
```

> **`az boards query` returns IDs only.** It ignores additional SELECT columns and returns empty field objects. This is not a bug you can work around by changing the WIQL — always follow with a batch fetch.

## Batch fetch fields

Use the ADO MCP work item tool, action `get_batch`, with an explicit fields array. Split into chunks of ~40 IDs.

```json
{
  "action": "get_batch",
  "project": "<config.ado.project>",
  "ids": [1001, 1002, "..."],
  "fields": [
    "System.Id", "System.WorkItemType", "System.Title", "System.State",
    "System.IterationPath", "System.Parent",
    "Microsoft.VSTS.Scheduling.StoryPoints",
    "Microsoft.VSTS.Scheduling.TargetDate",
    "Microsoft.VSTS.Common.Priority"
  ]
}
```

`fields` and `expand` are mutually exclusive. Passing both fails.

## Parse the batch result

Large batch results get written to a JSON file rather than returned inline. The file is a **top-level array** of work item objects, each with a `fields` property.

Working pattern — pipe `ConvertFrom-Json` straight into `ForEach-Object`:

```powershell
$all = @("<file1>", "<file2>") |
  ForEach-Object { Get-Content $_ -Raw | ConvertFrom-Json } |
  ForEach-Object {
    $f = $_.fields
    [pscustomobject]@{
      Id     = $f.'System.Id'
      Type   = $f.'System.WorkItemType'
      Sprint = ($f.'System.IterationPath' -split '\\')[-1]
      State  = $f.'System.State'
      Pts    = $f.'Microsoft.VSTS.Scheduling.StoryPoints'
      Target = ("" + $f.'Microsoft.VSTS.Scheduling.TargetDate') -replace 'T.*',''
      Parent = $f.'System.Parent'
      Title  = $f.'System.Title'
    }
  }

$all | Sort-Object Sprint, Id | Format-Table -AutoSize | Out-String -Width 220

$all | Group-Object Sprint | ForEach-Object {
  "{0}: {1} items, {2} pts" -f $_.Name, $_.Count, (($_.Group | Measure-Object Pts -Sum).Sum)
}
```

**Do not** try to normalize the root with `if ($j.value) {...} elseif ($j.workItems) {...} else { $j }`. Against a top-level array, PowerShell member enumeration makes that branch resolve strangely and you get rows of nulls with correct headers — which looks like a field-name problem and sends you debugging the wrong thing.

Cast dates and points defensively. `TargetDate` is absent on many items; the `("" + ...)` coercion above handles null without throwing.

## Velocity baseline

```powershell
$wiql = "SELECT [System.Id] FROM WorkItems " +
        "WHERE [System.IterationPath] = '$priorSprint' " +
        "AND [System.AssignedTo] = '$owner' " +
        "AND [System.State] = 'Closed' " +
        "ORDER BY [System.Id]"
```

Batch-fetch and sum `StoryPoints`. Repeat for the prior two sprints and average, per `config.json` → `velocity.source`.

Report both the item count and the point total. A month that closed 42 items for 105 points has a different character than one that closed 8 items for 105 points, and it changes how much unplanned work the coming sprint can absorb.

## Enumerate a Feature's real children

`assignedtome`-style queries miss children assigned to someone else or unassigned. Fetch the Feature with `expand: "Relations"`, filter to `rel == "System.LinkTypes.Hierarchy-Forward"`, and take the trailing path segment of each `url`.

## Finding attached pull requests

Before scheduling or editing anything tied to a PR-backed finding, check whether a PR already exists:

1. Read the work item's `## PR info` description section.
2. Check `ArtifactLink` relations — PRs attach there and don't always appear in the description.
3. `gh pr list --search "<finding-id>"`.
4. **Check `Removed` work items too.** Removing an item retains its artifact links, so a removed umbrella can hold the only reference to a dozen live PRs.
