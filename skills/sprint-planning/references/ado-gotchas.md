# ADO gotchas

Failure modes hit repeatedly during real planning sessions. Each one costs 10–20 minutes if you rediscover it.

## Creating a work item

**The `create` action rejects a `format` key anywhere in its `fields` array.** Including `{"format": "Markdown", ...}` on any entry causes the entire array to be rejected with a message about invalid JSON or wrong shape. The error talks about escaping — that's a red herring. `update` and `update_batch` accept `format`; `create` does not.

Creating with many fields at once can also fail for reasons that don't reproduce reliably.

**Reliable three-step pattern:**

```
1. create  → System.Title + System.AreaPath only
2. update  → everything else, including multiline fields with format: "Markdown"
3. link    → parent, using linkType: "parent"
```

Step 3 needs the friendly name. The raw `System.LinkTypes.Hierarchy-Reverse` is rejected with "Unknown link type", and omitting `linkType` silently creates a **Related** link instead of a parent — which looks fine until the item doesn't roll up.

## Reparenting an existing item

Adding a parent link to an item that already has one fails:

```
TF201036: You cannot add a Parent link between work items X and Y
because a work item can have only one Parent link.
```

`System.Parent` is read-only, so you can't reassign it with a field update either. Remove the old link first, then add the new one:

```powershell
az boards work-item relation remove --organization $org `
  --id 602910 --relation-type parent --target-id 596503 --yes --output none
```

Then link the new parent with the MCP tool as usual. Verify `System.Parent` on a read-back — a failed remove leaves the original parent in place and the subsequent link silently fails the same way.

## Where `format` belongs

Use `format: "Markdown"` **only** on multiline HTML-backed fields:

- ✅ `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `System.History`, repro steps
- ❌ `System.Title`, `System.Tags`, `System.State`, `System.AreaPath`, `System.IterationPath`, any date or numeric field

Setting it on a short field fails with "Operation of changing value type is not supported".

## Required Request information fields

Set all four on every create and every update. They're easy to omit and the work item looks complete without them:

| Field | Value |
|---|---|
| `Custom.Modality` | `Documentation` |
| `Custom.ResourceType` | `Technical Writer` |
| `Custom.ProposalType` | `Update` for existing content, `New` for net-new |
| `Custom.ProposalPointofContact` | owner email from `config.json` |

On update, read the item first and repair any missing values in the same write.

## Removing a field value

To clear story points, use an explicit `Remove` operation with the value omitted:

```json
{"id": 576236, "op": "Remove", "path": "/fields/Microsoft.VSTS.Scheduling.StoryPoints"}
```

Replacing with `0` is not equivalent — zero is a real estimate and rolls up as one, which defeats the point of clearing it.

## Batch updates

`update_batch` takes a flat array of operations across multiple items and needs no `project`. Prefer it over one call per item — it's faster and atomic enough for planning moves.

```json
[
  {"id": 576236, "op": "Remove",  "path": "/fields/Microsoft.VSTS.Scheduling.StoryPoints"},
  {"id": 576229, "op": "Replace", "path": "/fields/Microsoft.VSTS.Scheduling.TargetDate", "value": "2026-08-31T00:00:00Z"}
]
```

## Description structure

Sentence casing for all headings.

**Description:** `## Problem/Impact` · `## Solution` · `## Resources` · `## Success criteria`
**Acceptance criteria:** `### Success criteria` · `### Verification`

Durable information — approach changes, completed work, PR links — belongs in the Description. Temporal information — started, blocked, progress notes — belongs in a comment. When something is both an event and a permanent fact, such as creating a PR, do both.

Always read the current Description before updating it. Overwriting a description that someone else extended is invisible and unrecoverable without digging through revisions.

## PR references

Use `[#PR_NUMBER](url)` in work items.

Never put `AB#` in a commit message — it belongs in the PR body only, under `## Related Work Items`. `AB#` in commits creates duplicate ADO links.

## CLI fallback

If the MCP tools are unavailable:

| Mistake | Correct |
|---|---|
| `--expand all --fields X,Y` | Mutually exclusive — pick one |
| `--query "fields['System.Title']"` | Dot notation: `--query "fields.System.Title"` |
| Multiline string passed inline | Write to a temp file, read with `Get-Content -Raw` |
| One-liners over ~1000 chars | Split across commands — long lines cause terminal echo thrash |

The CLI stores descriptions as HTML and strips Markdown, so use single-line HTML there. Write temp files to `$env:TEMP`, never into a repository working tree, and delete them afterward.

Verify with a single full read — `az boards work-item show --id $id --output json` — rather than repeated targeted reads.
