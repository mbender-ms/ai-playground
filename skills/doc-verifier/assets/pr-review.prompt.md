---
mode: agent
description: Fact-check all changed files in a GitHub PR and generate a verification report
tools:
  - microsoft-learn-mcp-server/microsoft_docs_search
  - microsoft-learn-mcp-server/microsoft_docs_fetch
  - microsoft-learn-mcp-server/microsoft_code_sample_search
  - github/pull_request_read
  - read/readFile
  - read/problems
  - search/codebase
  - search/fileSearch
  - search/textSearch
  - edit/editFiles
  - edit/createFile
  - execute/runInTerminal
  - execute/getTerminalOutput
  - todo
---

# PR Fact-Check Review

Fact-check all changed files in a GitHub pull request against official Microsoft documentation and present a verification summary.

## Setup

Load, in this order:

1. [_taxonomy.md](./_taxonomy.md) — **normative**: status enum, risk classes, accurate-verdict gate, threshold matrix, escalation triggers, self-citation exclusion, run quality gate.
2. [_shared/source-hierarchy.md](../_shared/source-hierarchy.md) — tiered source authority, including Tier 1-C contract sources.

Generate a run ID (`YYYYMMDD-HHMMSS`) and use it in all artifact names for this run.

## Report output (`--report`)

By default this workflow is **chat-only** — it does not write a report file. Write a standalone markdown report only when the user asks for one:

- If the user passes `--report <path>`, write the report to that exact path.
- If the user requests a report but gives **no path**, ask for the path before completing — do not guess a default location.
- If neither is present, present the findings in chat only.

## Step 0 — Scope

Ask the user (skip if already clear):
1. **PR number** — Which PR to review?
2. **Repository** — Which repo? (default: current workspace repo)
3. **Product area** — What Microsoft product area do the changed files cover?

Verification depth is decided by claim risk class and the threshold matrix in `_taxonomy.md` — do not ask the user for a depth preference.

## Step 1 — Load the PR

1. Fetch PR metadata (title, author, branch, description)
2. List all changed files
3. Filter to documentation text files only — keep `.md`, `.yml`, and `.yaml`; **skip every other file type** (images such as `.png`/`.jpg`/`.svg`, PDFs, binaries, media). Reading non-text files attaches them as images to the request and triggers `Too many images in request` failures.
4. Read the content of each **kept** file only (from patches or file read). Record skipped files as `skipped (non-doc file type)`.
5. Report the file count (kept vs. skipped) and ask for confirmation

## Step 1.5 — Triage (apply the threshold matrix)

Before deep verification:

1. Extract a claim inventory per kept file (per [claim-manifest.prompt.md](./claim-manifest.prompt.md)) so routing uses actual claim counts, not estimates.
2. Mark risk level for each file:
  - High risk: security, compliance, identity, encryption, RBAC, production safety, retirement timelines.
  - Standard risk: feature descriptions, configuration guidance, and examples without safety-critical impact.
3. Route each file using the **threshold matrix** in `_taxonomy.md` (PR-scope rows), and apply its **escalation triggers** at claim level. Record routing decisions in the findings.
4. If a terminal is available, run [scripts/link-check.sh](../scripts/link-check.sh) across the kept files — every `broken` entry becomes a 🔗 finding without spending fetch budget.

## Step 2 — Catalog and group files

For each file:
1. Extract frontmatter metadata (`ms.service`, `ms.prod`, `ms.topic`)
2. Identify the service/feature area from content
3. Group files by service area
4. Build a claim inventory per file

## Step 3 — Verify per service group

Process files grouped by service area:

> **Multi-agent optimization**: When the PR contains files across 3+ service groups, spawn one `runSubagent` per service group for parallel verification. Each sub-agent receives its file list, the source hierarchy, and the matching category YAML from `../sources/`.

1. Search `microsoft_docs_search` for each service area
2. Use `microsoft_docs_fetch` for full reference pages — mandatory for every high-risk claim (a snippet is never sufficient)
3. **Contract check (Tier 1-C)**: for numeric limit/quota, config-default, and enum claims, confirm against a Contract source (`learn.microsoft.com/azure/templates/<provider>` schema, CLI/PowerShell parameter reference). If the contract pins the bound, it outranks prose; if the contract is silent and prose sources disagree, classify ⚖️ `contested` and offer [Live Validation](./live-validation.prompt.md)
4. Use `microsoft_code_sample_search` for code examples
5. Cross-reference all technical claims against fetched sources, applying the accurate-verdict gate and self-citation exclusion from `_taxonomy.md`
6. Audit remediation and reference links (use the link-check output from Step 1.5 when available)
7. Check preview/GA/deprecated status for all mentioned features
8. For contested or high-risk claims, perform Tier 1 adjudication before assigning final status

## Step 4 — Classify findings

Classify each claim with the canonical 7-status enum from `_taxonomy.md` (✅ accurate, ⚠️ partial, ❌ inaccurate, 🕐 outdated, ❓ unverifiable, 🔗 broken, ⚖️ contested). Unverifiable claims stay in the findings — never dropped. Contested claims never get an asserted value.

## Step 5 — Assemble findings

Assemble the findings using the report structure from SKILL.md. If a report was requested (see **Report output**), write it to the resolved `--report` path; otherwise hold this structure in memory to present in chat at Step 6.

1. **Header** — PR number, date, product area, files reviewed
2. **Executive summary** — Overall assessment with counts
3. **Findings at a glance** — Status distribution table
4. **Critical findings** — Each with: claim quote, evidence from official docs, recommended fix
5. **Advisory findings** — Context gaps, SKU notes, preview disclosures
6. **Per-file verification table** — Grouped by service area, per-file status + notes
7. **Link audit** — Every remediation/reference link with verification status
8. **Sources consulted** — All URLs organized by tier

## Step 6 — Present results

- Run the **run quality gate** from `_taxonomy.md` and lead with `run_status`
- Summarize key findings in chat
- If a report was written, note the report file location
- Ask if the user wants to:
  - Commit the report to the PR branch (only if a report was written)
  - Post findings as a PR comment
  - Apply corrections to the files
