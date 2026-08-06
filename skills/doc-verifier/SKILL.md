---
name: doc-verifier
description: >-
  Verify technical accuracy of Microsoft documentation across all product areas
  (Azure, M365, Security, Power Platform, Dynamics 365, Windows, DevTools).
  Five workflows: single article, PR review, research, fleet batch, and gated
  live validation. Tiered source hierarchy prioritizing learn.microsoft.com.
  Reports are opt-in via the --report flag.
argument-hint: "Describe what to verify — e.g., 'fact-check this article', 'verify PR #123', 'research Azure Front Door caching', 'fact-check these 5 articles'"
user-invocable: true
---

# Documentation Verifier

Verify technical accuracy of Microsoft documentation across **any product area** using a structured source hierarchy and reproducible workflows.

**Normative definitions** — status enum, claim risk classes, accurate-verdict gate, threshold matrix, escalation triggers, and the run quality gate — live in **[assets/_taxonomy.md](assets/_taxonomy.md)**. Load it before verifying anything. Do not restate its tables; when another file disagrees with it, `_taxonomy.md` wins.

## File-type filter (all workflows — mandatory)

**Only verify documentation text files: `.md`, `.yml`, and `.yaml`. Skip every other file type** — images, PDFs, archives, binaries, media. Filter file lists to these extensions **before** reading any file; record dropped paths as `skipped (non-doc file type)`. Reading image files attaches them to the model request and causes `Too many images in request` failures. Image references inside an article (`![alt](media/diagram.png)`) are verified as text/links only — never load the referenced binary.

## Choose your workflow

| # | Workflow | When to use | Output | Prompt asset |
|---|---------|-------------|--------|--------------|
| 1 | **Single Article** | Full single-file check with product-area scoping | Edits + chat summary | `single-article-check.prompt.md` |
| 2 | **PR Review** | Fact-check all changed files in a PR | Chat summary | `pr-review.prompt.md` |
| 3 | **Research** | Investigate a topic with citations, no edits | Chat findings | `microsoft-researcher.prompt.md` |
| 4 | **Fleet Batch** | Verify multiple articles in parallel (CLI `/fleet` or Chat `runSubagent`) | Chat consolidated findings | `fleet-batch-verify.prompt.md` |
| 5 | **Live Validation** | Empirically settle a `⚖️ Contested` claim | Chat findings + optional gated script | `live-validation.prompt.md` |

All five workflows are **chat-only by default**. The Fleet Batch workflow uses Claim Manifest extraction (`assets/claim-manifest.prompt.md`) internally to build its authoritative batch manifest and adaptive track plan — a supporting step, not a standalone workflow.

### Decision guide

- **"Fact-check this article"** → Workflow 1 (product-area scoped)
- **"Fact-check PR #12345"** → Workflow 2
- **"Research topic X with sources"** → Workflow 3
- **"Fact-check these 5 articles" / "this folder"** → Workflow 4 via `/fleet` or Chat `runSubagent`
- **"Settle this contested limit empirically"** → Workflow 5 (gated)
- **"Save the findings to a report"** → add `--report <path>` to any of the above

Routing by claim volume uses the **Threshold Matrix** in [assets/_taxonomy.md](assets/_taxonomy.md) — evaluated after claim extraction, never on estimates.

### Report output (`--report`)

Every workflow presents findings in chat without writing files by default:

- `--report <path>` → write to that exact path (a directory for Fleet Batch, a file for the others). Fleet directories include the validated manifest, track summary/results, reconciled findings JSON, and rendered Markdown.
- Report requested but **no path given** → ask for the path before completing; do not guess a default.
- No report requested → chat only.

## Step 0 — Scope (all workflows)

Before verifying, determine (ask only if not obvious):

1. **Product area**: Azure, M365, Security, Power Platform, Dynamics 365, Windows, DevTools
2. **Service/feature**: e.g., Defender for Endpoint, Azure Firewall, Intune
3. **Scope**: Single file, folder, PR, or topic
4. **Output**: In-place edits, report, chat, or both

Verification depth is decided by claim risk class and the Threshold Matrix — do not ask the user to choose a depth.

Generate a **run ID** (`YYYYMMDD-HHMMSS`) once at Step 0 and use it in every artifact name for the run (manifests, caches, reports) so artifacts never collide across runs.

Use the answers to select search domains and load the matching sources catalog YAML from `sources/` via [sources/routing-index.md](sources/routing-index.md) — load a category YAML only when repo-level detail is needed.

### Product area search domains

| Area | Search paths | Key terms |
|------|-------------|-----------|
| Azure | `/azure/`, `/azure/architecture/` | Azure, ARM, Bicep, subscription |
| M365 | `/microsoft-365/`, `/office/` | Exchange, SharePoint, Teams |
| Security | `/security/`, `/defender/` | Defender, Sentinel, Entra, Purview |
| Power Platform | `/power-platform/`, `/power-apps/` | Power Apps, Dataverse, connectors |
| Dynamics 365 | `/dynamics365/` | D365, Business Central, Finance |
| Windows | `/windows/`, `/windows-server/` | Windows 11, Group Policy |
| DevTools | `/visualstudio/`, `/dotnet/` | Visual Studio, .NET, NuGet |

## Source authority hierarchy

Always prefer the highest available tier. See [_shared/source-hierarchy.md](_shared/source-hierarchy.md) for the complete reference, including the **Tier 1-C API Contract** tier (ARM/Bicep templates, CLI/PowerShell parameter reference, REST specs) that outranks prose for numeric, default, and enum claims. Higher tier always wins; internal sources never appear in public docs.

## Prompt assets

| File | Role |
|------|------|
| `assets/single-article-check.prompt.md` | Workflow 1 — Single Article |
| `assets/pr-review.prompt.md` | Workflow 2 — PR Review |
| `assets/microsoft-researcher.prompt.md` | Workflow 3 — Research |
| `assets/fleet-batch-verify.prompt.md` | Workflow 4 — Fleet Batch |
| `assets/live-validation.prompt.md` | Workflow 5 — Live Validation (gated escalation) |
| `assets/claim-manifest.prompt.md` | Supporting — claim extraction (Step 1 of every verification workflow) |
| `assets/_taxonomy.md` | **Normative** — statuses, risk classes, gates, thresholds, triggers |
| `assets/_runtime-adapter.md` | Shared runtime dispatch rules |
| `assets/_subagent-contract.md` | Shared subagent I/O contract |
| `scripts/batch-presearch.sh` | Pre-search cache helper (batch runs) |
| `scripts/contract-lookup.sh` | Tier 1-C contract cache helper |
| `scripts/link-check.sh` | Deterministic link checker — computes 🔗 findings before verification |

## Token budget controls

- `microsoft_docs_fetch` calls use `maxTokenBudget=2000`
- Fleet tracks: independent context windows (no shared state)
- Search first, fetch selectively — spend fetch budget on high-risk claims per the risk classes in `_taxonomy.md`
- For large batches, front-load search latency with `scripts/batch-presearch.sh` (see [references/workflows.md](references/workflows.md))

## Detailed procedures

See [references/workflows.md](references/workflows.md) for per-workflow procedures and the workflow comparison table, and [_shared/quality-checklist.md](_shared/quality-checklist.md) for the quality checklist.
