---
name: laa-block-remediation
description: >-
  Find, list, and fix Learn Authoring Assistant (LAA) suggestion blocks on the user's own GitHub pull
  requests. LAA — the `learn-build-service-prod-*[bot]` / OpenPublishing build bot — posts inline
  `suggestion` review comments (the "Action required: Accept or reject all suggestions" blocks) that keep
  docs PRs from merging; this skill scans the PRs you authored AND are assigned to, lists every violation
  and its fix, and applies the accepted suggestions branch-by-branch (review-then-confirm by default; a
  `--force` flag finds, lists, and fixes autonomously). USE WHEN the user wants to check for, list, triage,
  clear, or fix LAA / build-bot suggestion blocks on their pull requests — e.g. "check my PRs for LAA
  blocks", "fix the LAA suggestions on my pull requests", "clear my Learn Authoring Assistant blocks",
  "apply LAA fixes --force", "which of my PRs are blocked by the build bot", "resolve the
  learn-build-service or openpublishing suggestion comments blocking my azure-docs PRs", or "my docs PRs
  are stuck on accept/reject suggestion prompts". Trigger even when the user doesn't say "LAA" by name but
  clearly means the learn-build-service / OpenPublishing bot's inline suggestion comments on their PRs.
  DO NOT USE FOR: running an authoring, style, or metadata review on local article files — that's the
  laa-clone skill, even when the user says "run the Learn Authoring Assistant"; reviewing a PR for
  Microsoft Writing Style Guide compliance or technical accuracy (pr-review); addressing human-reviewer or
  GitHub Copilot code-review comments (address-pr-comments); fixing build failures such as YAML metadata or
  broken-link errors; merging or squashing PRs; or creating ADO work items to track style issues.
---

# LAA block remediation

Automate the full loop of clearing **Learn Authoring Assistant (LAA)** blocks on the user's own docs PRs:
discover which of their open PRs have unresolved LAA suggestion comments, list every violation and its fix,
get the user's go-ahead (or run autonomously with `--force`), then apply only the fixes that aren't already
committed — one PR branch at a time — and push.

LAA suggestions arrive as inline review comments from a `learn-build-service-prod-*[bot]` account containing a
` ```suggestion ` code block. They block the PR until every thread is accepted or rejected. Applying the
suggested text to the source file and pushing re-runs the check and clears the block.

## Why this shape

- **Author + assignee scope** keeps the run to PRs the user actually owns, so nothing is changed on someone
  else's work.
- **List-before-fix** exists because docs authors want to eyeball the bot's rewrites — some are judgment calls.
  The default pause respects that; `--force` skips it for users who trust the bot and want throughput.
- **Check the committed version before editing** because the user (or a prior run) often already applied some
  suggestions. Re-applying a fix that's already in place wastes a commit and can fail to match.
- **One branch at a time** because each PR is a separate branch on the user's fork; batching risks cross-branch
  contamination in a shared working tree.

## Inputs and flags

Parse these from the user's message; infer sensible defaults.

| Input | Default | Notes |
|---|---|---|
| Target repo | `MicrosoftDocs/azure-docs-pr` | Override if the user names another repo. |
| GitHub login | auto-detect | `gh api user --jq .login` (or the GitHub MCP `get_me`). |
| `--force` | off | When present (or the user says "force", "autonomously", "just fix them", "don't ask"), skip the acceptance pause: find, list, AND fix in one pass. |

## Workflow

### 1. Discover LAA-blocked PRs

Run the bundled discovery script. It resolves the login, finds every open PR **authored by and assigned to**
the user in the target repo, pulls each PR's inline review comments, and extracts the LAA suggestion blocks
(violation + fix + rule + branch).

```powershell
pwsh -File "<skill-dir>/scripts/Find-LaaBlocks.ps1" -Owner MicrosoftDocs -Repo azure-docs-pr -OutFile "$env:TEMP/laa-blocks.json"
```

The script prints a per-PR count summary and writes a JSON array to `-OutFile`. Each element has:
`PR`, `Branch`, `Path`, `Rule`, `Orig` (the flagged text), `Fix` (the suggested replacement), `Outdated`
(true when the bot comment no longer maps to a current diff line — usually already fixed).

Prerequisites the script assumes: `gh` is authenticated (`gh auth status`) and `pwsh` is available. If `gh`
isn't authenticated, tell the user to run `gh auth login` and stop.

### 2. Cross-check every block against the pattern catalog (always — not optional)

Every discovered suggestion is a real, observed LAA block. Before presenting the list, reconcile it against
the shared pattern catalog at `LAA_SUGGESTIONS_PATH` so the catalog
never falls behind what the bot is actually flagging:

1. Read the catalog's `Patterns` table and collect the set of `LAA tag` values already documented
   (ignore `General` — it's an intentional catch-all, not a discrete tag).
2. For each block in the JSON with a **named** `Rule` (not `General`, not `Unspecified`) that ISN'T already
   in that set, append a new row using the block's own `Orig`/`Fix` as the example — don't wait to be asked.
   Bump the `Patterns` count and `Last updated` date in the header, and add an `Update log` row citing the
   PR number(s) this run touched.
3. For blocks tagged `General` (or with no rule captured), compare the `Orig`/`Fix` shape against existing
   `General` rows' `Detect` heuristics. If none match, still add a new `General`-tagged row — don't discard
   it just because the bot didn't name a rule.
4. Note in your final report how many new patterns you captured (or that none were needed) so the user sees
   the catalog stayed current.

This step runs on every invocation of this skill, whether or not the user mentions the catalog.

### 3. List every block

Read the JSON and present the blocks the way a reviewer wants to scan them: grouped by service/area, one row
per suggestion. Keep `Fix` summaries short but unambiguous.

ALWAYS use this structure:

```
## LAA-blocked PRs (created by & assigned to <login> in <owner>/<repo>)

Scanned <N> open PRs. <M> have unresolved LAA suggestions — <K> suggestions total.

### <Service area>
| PR | File | Violation | Fix |
|---|---|---|---|
| #NNNNNN | path/file.md | <what LAA flagged> | <the transform> |
```

Link PRs as `https://github.com/<owner>/<repo>/pull/NNNNNN`. If the discovery script marked a suggestion
`Outdated`, still list it but note it's likely already applied — you'll confirm in step 5. Include the
"New patterns captured" note from step 2 at the top of the list.

### 4. Gate on user acceptance (unless `--force`)

- **Default:** Stop after the list and ask for a clear go-ahead, e.g. "Apply all these fixes? (yes / pick
  specific PRs / no)". Do not touch any branch until the user accepts. If they select a subset, only act on
  those PRs.
- **`--force`:** Skip this pause entirely. Announce that you're proceeding autonomously and go straight to
  step 5 for all discovered PRs.

### 5. Apply fixes — one PR branch at a time

For each PR to fix, follow this loop. The **check-before-edit** step is essential: some fixes are already in.

1. **Guard the working tree.** `git -C <repo> status --porcelain` must be empty before switching branches.
   If it isn't, stop and surface it — never discard unknown local changes in a shared clone.
2. **Check out the PR branch** from the fork remote (these branches live on the user's fork, usually `origin`):
   `git checkout <branch>` then `git pull origin <branch> --quiet`.
3. **Verify current committed content.** For each suggestion on this PR, use the bundled checker (or
   `Select-String`) to see whether the `Fix` text is already present (APPLIED → skip), the `Orig` text is
   still present (NEEDS-FIX → apply), or neither (NOT-FOUND → the file drifted; read the file and use judgment).

   ```powershell
   pwsh -File "<skill-dir>/scripts/Test-LaaApplied.ps1" -Json "$env:TEMP/laa-blocks.json" -Pr <number> -RepoRoot "<repo>"
   ```

4. **Apply only NEEDS-FIX suggestions** by editing the source file so the flagged text matches the bot's
   suggestion exactly. Match whitespace, indentation, and inline code precisely. Watch for em dashes and other
   non-ASCII characters — read the exact line before editing.
5. **Stay in the PR's diff.** If the same wording appears elsewhere in the file but outside this PR's changes
   (confirm with `git diff upstream/main...HEAD -- <file>`), leave it — fixing pre-existing, unflagged lines
   expands scope and can cause conflicts. Note such instances in your report instead.
6. **Commit and push.** One logical commit per PR. Conventional style, describe WHAT changed, ≤72 chars, and
   **never** put an `AB#` reference in a commit message (that belongs in PR bodies only). Then
   `git push origin <branch>`. Pushing here is the "apply" the user authorized (via acceptance or `--force`).
7. **Record the outcome** (fixed & pushed / already applied / skipped) and move to the next PR.

### 6. Leave the tree clean and report

Return the shared clone to a safe state: `git checkout main`. Then give a compact report:

- PRs that needed fixes → pushed (with the one-line change each).
- PRs already fully applied (no change).
- Any out-of-scope duplicates you intentionally left, and any NOT-FOUND drifts needing a human look.
- New patterns captured in the catalog this run (count + tags), or "catalog already current".

Each pushed commit re-triggers the LAA check on that PR. Offer to re-run discovery later to confirm the checks
cleared.

## Git safety

- Branch fixes belong on the PR's own branch on the fork — never commit LAA fixes to `main`.
- Batch related git commands, but run one PR's operations to completion before starting the next.
- Only `--force` skips the *acceptance* gate; it never authorizes force-push, hard reset, or branch deletion.
- If a push is rejected, `git pull --rebase origin <branch>` then retry; surface conflicts, don't auto-resolve.

## Pattern catalog upkeep

Step 2 makes catalog upkeep part of every run, not an afterthought — see there for the mechanics. The catalog
lives at `LAA_SUGGESTIONS_PATH` and should be a git-tracked file in a repo you control;
commit catalog edits there like any other tracked change when the user is
ready, rather than leaving them as an uncommitted local diff.

## Scripts

- `scripts/Find-LaaBlocks.ps1` — discovers author+assignee PRs with LAA suggestion blocks and emits JSON +
  a summary. Params: `-Owner`, `-Repo`, `-Login` (optional; auto-detected), `-OutFile`.
- `scripts/Test-LaaApplied.ps1` — for the currently checked-out branch, reports APPLIED / NEEDS-FIX /
  NOT-FOUND per suggestion so you apply only what's missing. Params: `-Json`, `-Pr`, `-RepoRoot`.
