# Documentation Verifier

> **Version:** 1.3.0 · **Last updated:** 2026-07-14

A VS Code Copilot skill that fact-checks Microsoft documentation against official sources across **all product areas** — Azure, Microsoft 365, Microsoft Security, Power Platform, Dynamics 365, Windows, Developer Tools, and more.

Four primary workflows — single-article check, PR review, research, and fleet batch (parallel multi-article) — plus a fifth gated **Live Validation** escalation that empirically settles contested numeric/behavioral claims. A tiered source hierarchy prioritizes learn.microsoft.com, with a dedicated **Tier 1-C API Contract** tier (ARM/Bicep templates, CLI/PowerShell parameter reference, REST specs) that outranks prose for numeric, default, and enum claims. Reports are opt-in via the `--report` flag — every workflow is chat-only by default.

---

## Prerequisites

### Required

| Requirement | How to verify |
|-------------|---------------|
| **VS Code** (1.100+) | `code --version` |
| **GitHub Copilot** (agent mode) | Copilot Chat → mode dropdown → "Agent" available |
| **Microsoft Learn MCP Server** | Check MCP config for `microsoft-learn-mcp-server` entry |

### Optional

| Requirement | Needed for |
|-------------|------------|
| **GitHub MCP Server** | PR Review workflow |
| **GitHub CLI** (`gh`) | PR Review workflow |
| **Copilot CLI** with `/fleet` | Fleet Batch workflow |
| **@microsoft/learn-cli** (`npm i -g @microsoft/learn-cli`, installs the `mslearn` binary) | `batch-presearch.sh` + `contract-lookup.sh` cache modes — both degrade gracefully without it |

---

## Installation

Copy the `doc-verifier/` folder to your Copilot skills directory:

**Windows:**
```powershell
Copy-Item -Recurse .\doc-verifier\ "$env:USERPROFILE\.copilot\skills\doc-verifier"
```

**macOS / Linux:**
```bash
cp -r ./doc-verifier/ ~/.copilot/skills/doc-verifier/
```

Restart VS Code. The skill is discovered automatically on startup.

### Folder structure

```
doc-verifier/
├── SKILL.md                                    # Thin router (Copilot reads this) — points at _taxonomy.md
├── README.md                                   # This file (non-normative)
├── assets/
│   ├── _taxonomy.md                             # ★ NORMATIVE: status enum, risk classes, verdict gate,
│   │                                            #   threshold matrix, escalation triggers, run quality gate
│   ├── single-article-check.prompt.md           # Single Article workflow
│   ├── pr-review.prompt.md                      # PR Review workflow
│   ├── microsoft-researcher.prompt.md           # Research workflow
│   ├── fleet-batch-verify.prompt.md             # Fleet Batch workflow
│   ├── live-validation.prompt.md                # Live Validation (gated escalation)
│   ├── claim-manifest.prompt.md                 # Supporting: claim extraction (Step 1 of every workflow)
│   ├── _runtime-adapter.md                      # Shared runtime dispatch rules
│   └── _subagent-contract.md                    # Shared subagent I/O contract
├── schemas/
│   ├── claims.schema.json                       # Claim manifest JSON sidecar
│   ├── batch-manifest.schema.json                # Fleet article/claim/topic/track inventory
│   ├── track-result.schema.json                  # Per-attempt Fleet completion envelope
│   ├── findings.schema.json                     # Reusable finding + run-level artifact
│   └── facts-ledger.schema.json                 # Persistent fact ledger (<target-repo>/.doc-verifier/)
├── scripts/
│   ├── batch-presearch.sh                       # Pre-search cache helper (degrades to query lists)
│   ├── contract-lookup.sh                       # API Contract (Tier 1-C) cache helper
│   └── link-check.sh                            # Deterministic 🔗 link checker
├── TEST-PROTOCOLS.md                           # Validation procedures (incl. script smoke tests)
├── _shared/                                     # Vendored shared references (self-contained)
│   ├── source-hierarchy.md                      # Canonical tiered source authority reference
│   ├── quality-checklist.md                     # Shared quality checklist
│   ├── formatting-rules.md
│   ├── seo-and-metadata.md
│   └── writing-style.md
├── sources/                                     # Vendored repository catalog (per-category only)
│   ├── routing-index.md                         # Product-area → category YAML routing
│   ├── categories-index.yml
│   └── *.yml                                     # Per-category repo catalogs (azure-networking.yml, ...)
└── references/
    ├── source-hierarchy.md                      # Local pointer → _shared/source-hierarchy.md
    ├── source-guide.md                          # Educational guide to sources
    └── workflows.md                             # Detailed per-workflow procedures

# Repo root (NOT shipped with the installed skill):
tools/sources-orgs/                              # Per-org catalog monoliths (~1.4 MB)
tools/sources-build/                             # Catalog build scripts + raw data
tests/fixtures/                                  # Test manifests, cache samples, fixture articles
```

### Bundled dependencies (self-contained)

`_shared/` and `sources/` are vendored into this folder so the skill is fully portable — copying just `doc-verifier/` to your skills directory brings everything it needs.

| Dependency | Purpose |
|-----------|----------|
| `_shared/source-hierarchy.md` | Canonical tiered source authority reference |
| `_shared/quality-checklist.md` | Shared quality checklist |
| `sources/` | Repository catalog — Step 0 loads category YAML for Tier 2 verification |

---

## Usage

Open **GitHub Copilot Chat** in agent mode and describe what you want verified. The skill automatically selects the right workflow.

### Trigger examples

| You say... | Workflow |
|-----------|----------|
| "Fact-check this article" | Single Article |
| "Fact-check PR #12345" | PR Review |
| "Research Azure Front Door caching" | Research |
| "Fact-check these 5 articles" / "this folder" | Fleet Batch |
| "Settle this contested limit empirically" | Live Validation (gated) |
| "...and save the findings to a report" | add `--report <path>` to any workflow |

---

## Routing, escalation, and gates (normative reference)

The status enum, claim risk classes, accurate-verdict gate, **Threshold Matrix**, **Escalation Triggers**, self-citation exclusion, and the **run quality gate** are all defined in one normative file: [`assets/_taxonomy.md`](assets/_taxonomy.md). Every workflow loads it in Setup. Routing by claim volume happens *after* claim extraction, on actual counts. Summaries elsewhere (including this README) are non-normative — `_taxonomy.md` wins on any disagreement.

---

## API contract verification (Tier 1-C)

For **numeric limit/quota, configuration-default, and enum/allowed-value** claims, prose pages alone are not authoritative. The skill confirms these against a dedicated **Tier 1-C API Contract** tier and prefers it over prose when they disagree:

| Source | Content type |
|--------|-------------|
| `learn.microsoft.com/azure/templates/*` | ARM/Bicep/Terraform resource schema — property min/max, defaults, enums |
| `learn.microsoft.com/cli/azure/*` | Azure CLI parameter reference and `--help` (accepted ranges, defaults) |
| `learn.microsoft.com/powershell/module/*` | Az PowerShell cmdlet parameter reference |
| `github.com/Azure/azure-rest-api-specs` | Swagger — authoritative property constraints |

When a Contract source pins the bound, it wins over prose (the prose is the defect). When the contract is **silent** on a bound and prose pages disagree, the claim is marked **⚖️ Contested** rather than guessed — and can be routed to **Live Validation** for empirical confirmation. The `scripts/contract-lookup.sh` helper caches the templates schema page and CLI `--help` once so every fleet track reuses one lookup.

---

## Live Validation (gated escalation)

When a claim is **⚖️ Contested** or a contract conflict fires, the **Live Validation** workflow can settle it empirically — always gated and safe:

- **Tier 4a — read-only introspection (default):** `az <cmd> --help`, `Get-Help -Full`, `az rest --method get` against provider metadata. No resources are created or modified.
- **Tier 4b — mutating probe (opt-in only):** generates a boundary-probe script for explicit user approval; never auto-runs, requires a non-production subscription, and always cleans up resources.

Results are recorded as `verification_method: live` and outrank prose during reconciliation.

---

## Parallel verification

The **Fleet Batch** workflow scales verification across multiple articles:

- Builds one batch manifest for every in-scope article and claim, including zero-claim documentation files
- Packs related work into adaptive thematic tracks targeting 3-7 articles, with hard standard limits of 40 claims and 10 high-risk claims
- Validates compact JSON track envelopes and retries empty, malformed, incomplete, or oversized work once at smaller scope
- Enforces evidence gates and exact article/claim completeness during merge before reporting run status
- Builds a batch-wide canonical `topic_key` index via the **Claim Manifest** supporting step so cross-article conflicts can be reconciled afterward
- For large batches, run `scripts/batch-presearch.sh` first to warm search caches before verification
- With `--report <dir>`, persists the batch manifest, track summary/results, reconciled findings JSON, and Markdown rendered from that JSON; chat-only remains the default

---

## Supported product areas

| Area | Examples |
|------|---------|
| **Azure** | Firewall, DDoS Protection, App Service, AKS, Cosmos DB |
| **Microsoft 365** | Exchange Online, SharePoint, Teams, OneDrive |
| **Microsoft Security** | Defender for Endpoint/Cloud, Sentinel, Entra ID, Purview, Intune |
| **Power Platform** | Power Apps, Power Automate, Power BI, Dataverse |
| **Dynamics 365** | Business Central, Finance, Supply Chain |
| **Windows** | Windows 11, Windows Server, Group Policy |
| **Developer Tools** | Visual Studio, .NET, Azure DevOps, GitHub Actions |

---

## Accuracy classifications

> Non-normative summary — the canonical enum lives in [`assets/_taxonomy.md`](assets/_taxonomy.md).

| Icon | Status | Meaning |
|------|--------|---------|
| ✅ | Accurate | Matches current official documentation |
| ⚠️ | Partially accurate | Needs minor update or added context |
| ❌ | Inaccurate | Contradicts official sources |
| 🕐 | Outdated | Was correct but superseded |
| ❓ | Unverifiable | No authoritative source found (flagged, not removed) |
| 🔗 | Broken link | URL doesn't resolve or anchor is missing |
| ⚖️ | Contested | Prose sources disagree AND the API contract is silent — flagged for Live Validation or product-team confirmation; no value asserted |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Skill not recognized | Verify folder at `~/.copilot/skills/doc-verifier/` with `SKILL.md`. Restart VS Code. |
| `microsoft_docs_search` unavailable | Check MCP config for Microsoft Learn MCP Server. Restart VS Code. |
| PR workflow can't load PR | Ensure GitHub MCP Server configured and `gh auth status` shows authenticated. |
| Fleet workflow not parallelizing | Use Copilot CLI `/fleet`; VS Code agent mode may run sequentially. |
| `batch-presearch.sh` fails | Install `@microsoft/learn-cli` and run from a shell with bash support. |
| `contract-lookup.sh` finds no contract | Verify the provider path (e.g. `microsoft.network/loadbalancers`); fetch the templates schema page in-agent via `microsoft_docs_fetch` if the helper can't reach it. |
| Agent doesn't ask scoping questions | Add context: "fact-check this M365 Security article about Defender for Endpoint" |

---

## History

This skill consolidates the earlier `fact-checker`, `microsoft-doc-verifier`, `microsoft-fact-checker`, and `fact-check-batch-subagent` skills into a single unified tool with four focused workflows.

---

## Changelog

### 1.3.0 — 2026-07-14

**Added — completeness-safe adaptive Fleet Batch contracts**

- Fleet Batch now builds a schema-valid batch manifest, dispatches bounded thematic tracks, validates JSON-only completion envelopes, and performs one scope-reduction retry wave.
- Exact file and claim invariants prevent silent omissions; exhausted work remains explicit and available partial results are still consolidated.
- Merge-time evidence and Contract gates downgrade unsupported `accurate` verdicts with auditable reason codes.
- New `batch-manifest.schema.json` and `track-result.schema.json`; expanded claim, findings, and versioned fact-ledger schemas with valid/invalid CI fixtures. Version 1 ledgers remain readable and migrate to provenance-aware version 2 on write.
- Report mode persists structured artifacts and renders Markdown from reconciled JSON. Model/token telemetry remains capability-gated and unknown values stay null.

### 1.2.0 — 2026-07-09

**Repaired — single source of truth, script fixes, deterministic pre-pass, fact ledger, run gate**

- **`assets/_taxonomy.md`** (new, normative): one canonical home for the 7-status enum, claim risk classes, accurate-verdict gate, threshold matrix, escalation triggers, self-citation exclusion, and the new **run quality gate** (`passed`/`degraded`/`failed`). All duplicated copies across SKILL.md, README, prompts, and references replaced with pointers — this removes the drift class that had left `contested`/`broken` and the Tier 1-C contract gate missing from the Single Article and PR Review workflows.
- **Workflows 1 and 2 wired for v1.1 features**: contract check (Tier 1-C), ⚖️ Contested → Live Validation escalation, full 7-status classification, claim-manifest-first routing on actual claim counts.
- **Depth question removed**: depth is driven by claim risk class, per the contract — the "Quick or thorough?" scoping question asked for an answer nothing consumed.
- **`batch-presearch.sh` rewritten**: header-aware column lookup (works with 5- and 6-column manifests — it previously extracted `topic_key` slugs instead of claim text and dropped all low-risk claims), case-insensitive section matching (previously matched zero sections on normal-cased manifests), `jq`-built JSON, and graceful degradation to query lists when the Learn CLI is unavailable.
- **`contract-lookup.sh` repaired**: static provider→CLI-group map plus explicit `--cli-group` (mechanical derivation produced nonexistent `az` groups), unified Learn CLI invocation, curl fallback removed (it cached unusable JS-shell HTML), and honest non-zero exit with an in-agent fallback instruction instead of silently empty cache files.
- **`scripts/link-check.sh`** (new): deterministic 🔗 checker — HTTP checks with HEAD→ranged-GET fallback and retries, relative-path checks, `unchecked-anchor` for fragments; agents consume its JSON instead of spending fetch budget on links.
- **Fact ledger** (`schemas/facts-ledger.schema.json`): verified facts persist at `<target-repo>/.doc-verifier/facts-ledger.json` with per-class TTLs; re-runs skip fresh matching facts (`verification_method: ledger`) and always re-verify conflicting ones.
- **JSON artifacts** (`schemas/claims.schema.json`, `schemas/findings.schema.json`): claim manifests emit a machine-readable sidecar; runs can emit a structured findings artifact.
- **Run-ID artifact naming** (`YYYYMMDD-HHMMSS`): same-day runs no longer overwrite each other's reports/caches.
- **Bundle pruned ~70%**: per-org catalog monoliths and build tooling moved to repo-root `tools/`, test scratch to `tests/fixtures/` — the installed skill ships only what verification uses.
- Stale references fixed ("four workflows" → five; "Workflows 3 and 6" → Research workflow).

### 1.1.0 — 2026-06-26

**Added — API contract verification & gated live validation**

- **Tier 1-C API Contract sources** in the source hierarchy (ARM/Bicep templates, CLI/PowerShell parameter reference, REST API specs). For numeric limit/quota, config-default, and enum claims, a Contract source outranks Tier-1 prose.
- **Contract gate for numeric claims**: numeric/limit/quota/config-default/enum claims now require an agreeing Contract source to be scored `accurate`; prose agreement alone caps at `confidence: medium`.
- **⚖️ Contested classification**: emitted when prose sources disagree and the API contract is silent — no value is guessed. Added to the `status` enum and the fleet classification list.
- **Live Validation workflow (5)**: new gated escalation (`assets/live-validation.prompt.md`) — read-only introspection by default, mutating boundary probes only on explicit opt-in.
- **Subagent contract fields**: `verification_method` extended with `contract|live`; new optional `contract_value` and `contract_source` fields; cross-track reconciliation now prefers `contract`/`live` values over prose.
- **`scripts/contract-lookup.sh`**: caches a provider's templates schema page and CLI `--help` so fleet tracks reuse a single contract lookup.
- Quality checklist and Threshold Matrix updated with contract-confirmation and contested-routing items.

### 1.0.0 — Initial release

- Consolidated the earlier `fact-checker`, `microsoft-doc-verifier`, `microsoft-fact-checker`, and `fact-check-batch-subagent` skills into one tool.
- Four workflows: Single Article, PR Review, Research, Fleet Batch.
- Tiered source hierarchy (Tiers 1–7) prioritizing learn.microsoft.com; opt-in `--report` output; vendored `_shared/` and `sources/` for portability.
