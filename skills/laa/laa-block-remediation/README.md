# laa-block-remediation

Find, list, and fix **Learn Authoring Assistant (LAA)** suggestion blocks on your own GitHub pull requests, one PR branch at a time.

LAA — the `learn-build-service-prod-*[bot]` / OpenPublishing build bot — posts inline `` ```suggestion `` review comments (the **"Action required: Accept or reject all suggestions"** blocks) that keep docs PRs from merging. This skill discovers the blocks across the PRs you authored **and** are assigned to, lists every violation and its fix, then applies the accepted suggestions branch-by-branch and pushes.

## When it runs

Triggers on phrases like:

- "check my PRs for LAA blocks"
- "fix the LAA suggestions on my pull requests"
- "clear my Learn Authoring Assistant blocks"
- "which of my PRs are blocked by the build bot"
- "resolve the learn-build-service / openpublishing suggestion comments blocking my azure-docs PRs"
- "my docs PRs are stuck on accept/reject suggestion prompts"

It triggers even when you don't say "LAA" by name but clearly mean the build bot's inline suggestion comments on your PRs.

**Not** for: running an authoring/style review on local files (use `laa-clone`), style/accuracy PR review (use `pr-review`), human/Copilot review comments (use `address-pr-comments`), build/metadata/link errors, merging PRs, or creating ADO work items.

## How it works

1. **Discover** — resolves your GitHub login and finds open PRs authored by and assigned to you in the target repo, then extracts each LAA suggestion block (violation + fix + branch).
2. **List** — presents every block grouped by service area: PR, file, violation, fix.
3. **Gate** — pauses for your acceptance by default. Pass `--force` to find, list, and fix autonomously.
4. **Fix** — for each PR: check out the branch, verify the latest committed content (skipping already-applied fixes), apply the remaining suggestions, commit, and push. Stays within each PR's own diff.
5. **Report** — returns the working tree to `main` and summarizes what was fixed, what was already applied, and anything left for a human.

## Usage

```text
check my PRs for LAA blocks
```

```text
fix my LAA blocks --force
```

```text
clear the learn-build-service suggestions on my virtual-network-manager PRs
```

Optional inputs the skill infers from your message: target repo (default `MicrosoftDocs/azure-docs-pr`), GitHub login (auto-detected), and the `--force` flag.

## Prerequisites

- **GitHub CLI** (`gh`) authenticated — `gh auth status` / `gh auth login`.
- **PowerShell 7** (`pwsh`) to run the bundled scripts.
- A local clone of the target repo with the PR branches available on your fork remote (usually `origin`).

## Files

| Path | Purpose |
|---|---|
| `SKILL.md` | The workflow, listing format, accept/`--force` gate, and git-safety rules. |
| `scripts/Find-LaaBlocks.ps1` | Discovers author+assignee PRs with LAA suggestion blocks → JSON + summary. Params: `-Owner`, `-Repo`, `-Login` (optional), `-OutFile`. |
| `scripts/Test-LaaApplied.ps1` | For the checked-out branch, reports APPLIED / NEEDS-FIX / NOT-FOUND per suggestion (exact trimmed-line matching). Params: `-Json`, `-Pr`, `-RepoRoot`. |

### Run the scripts directly

```powershell
# 1. Discover blocks across your open PRs
pwsh -File scripts/Find-LaaBlocks.ps1 -Owner MicrosoftDocs -Repo azure-docs-pr -OutFile "$env:TEMP/laa-blocks.json"

# 2. After checking out a PR branch, see which suggestions still need applying
pwsh -File scripts/Test-LaaApplied.ps1 -Json "$env:TEMP/laa-blocks.json" -Pr 318362 -RepoRoot "/path/to/your/docs-repo"
```

## Safety

- Fixes commit to each PR's own branch — never to `main`.
- Only `--force` skips the acceptance gate; it never authorizes force-push, hard reset, or branch deletion.
- Commit messages describe what changed and never include `AB#` references (those belong in PR bodies).
- Pre-existing duplicate wording outside a PR's diff is left untouched to avoid scope creep.
