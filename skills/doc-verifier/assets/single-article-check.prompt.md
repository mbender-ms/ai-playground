---
mode: agent
description: Fact-check the current article against official Microsoft documentation
tools:
  - microsoft-learn-mcp-server/microsoft_docs_search
  - microsoft-learn-mcp-server/microsoft_docs_fetch
  - microsoft-learn-mcp-server/microsoft_code_sample_search
  - read/readFile
  - read/problems
  - search/codebase
  - search/fileSearch
  - search/textSearch
  - edit/editFiles
  - execute/runInTerminal
  - execute/getTerminalOutput
  - todo
---

# Single Article Fact-Check

Fact-check the currently open article against official Microsoft documentation. Verify every technical claim, apply corrections in-place, and present a summary with source citations.

## Setup

Load, in this order:

1. [_taxonomy.md](./_taxonomy.md) — **normative**: status enum, risk classes, accurate-verdict gate, threshold matrix, escalation triggers, self-citation exclusion, run quality gate.
2. [_shared/source-hierarchy.md](../_shared/source-hierarchy.md) — tiered source authority, including Tier 1-C contract sources.
3. [`schemas/findings.schema.json`](../schemas/findings.schema.json) — shared finding shape, evidence fields, and unverifiable reason-code conditionals.

For product-area repo lookups, consult [sources/routing-index.md](../sources/routing-index.md); load a category YAML only if repo-level detail is needed.

Generate a run ID (`YYYYMMDD-HHMMSS`) and use it in all artifact names for this run.

## Report output (`--report`)

Chat-only by default. Write a markdown report only when asked:

- `--report <path>` → write to that exact path.
- Report requested with **no path** → ask for the path before completing; do not guess.
- Neither → chat only.

## Step 0 — Scope

1. **Product area** — Read the file's `ms.service`, `ms.prod`, or content to identify the product area.
2. **Service focus** — Identify the specific service or feature.

Verification depth is decided by claim risk class and the threshold matrix — do not ask the user for a depth preference.

Only proceed if the current file is a documentation text file (`.md`, `.yml`, `.yaml`). Any other type (image, PDF, binary, media): stop and report that the file type is not verifiable — never open or attach it. Image references inside the article (`![alt](media/diagram.png)`) are checked as text/links only.

## Step 1 — Extract the claim manifest

Extract every verifiable technical claim per [claim-manifest.prompt.md](./claim-manifest.prompt.md): types, line numbers, `topic_key`s for high-risk claims, and the machine-readable sidecar. Resolve `[!INCLUDE]` files.

Then **route** using the threshold matrix in `_taxonomy.md` on the actual claim count:

- 1–15 claims, low ambiguity → verify in this pass (Tier 2).
- 16–40 claims or mixed ambiguity → verify in this pass; adjudicate high-risk claims at Tier 1.
- More than 40 claims, cross-service scope, or safety-critical content → recommend a Fleet Batch single-article track and ask before proceeding sequentially.

## Step 1.5 — Deterministic pre-pass

Before spending any fetch budget:

- If a terminal is available, run [scripts/link-check.sh](../scripts/link-check.sh) on the article and read its JSON output — every `broken` entry becomes a 🔗 finding with zero MCP calls. If no terminal, verify links as part of Step 2 instead.
- If a fact ledger exists at `<repo>/.doc-verifier/facts-ledger.json`, validate and look up each high-risk claim's `topic_key`: a fresh (unexpired) entry whose `verified_value` matches the article text may be scored `accurate` with `verification_method: ledger`; a fresh entry that **conflicts** with the article text must still be verified live. Version 1 remains readable; write version 2 with claim-class TTL provenance after reconciliation.

## Step 2 — Verify against sources

For each remaining claim, in priority order per the source hierarchy:

1. `microsoft_docs_search` — product-area-specific terms
2. `microsoft_docs_fetch` — full pages for every high-risk claim (a snippet is never sufficient); for low-risk claims, only on apparent discrepancy
3. **Contract check (Tier 1-C)** — for numeric limit/quota, config-default, and enum claims, also confirm against a Contract source: the `learn.microsoft.com/azure/templates/<provider>` schema page and/or CLI/PowerShell parameter reference (`scripts/contract-lookup.sh` can cache these). Record `contract_value` and `contract_source`. If the contract pins the bound, it outranks prose; if the contract is silent and prose sources disagree, classify ⚖️ `contested`.
4. `microsoft_code_sample_search` — validate code examples
5. `grep_search` / `semantic_search` — cross-reference workspace content
6. Check deprecation, preview/GA status, and retirement notices

Apply the **accurate-verdict gate** and **self-citation exclusion** from `_taxonomy.md` to every verdict. Use `maxTokenBudget=2000` on fetch calls.

## Step 3 — Classify accuracy

Use the canonical 7-status enum from `_taxonomy.md` (✅ accurate, ⚠️ partial, ❌ inaccurate, 🕐 outdated, ❓ unverifiable, 🔗 broken, ⚖️ contested). For ⚖️ contested claims, offer the [Live Validation workflow](./live-validation.prompt.md) — never assert a value.

Assemble each result with `findings.schema.json#/$defs/finding`, including claim type/risk, Contract gate fields, source independence, nullable reason code, and gate notes. Every `unverifiable` result requires a reason code from `_taxonomy.md`. Validate the shared evidence contract before edits or reporting; deterministically downgrade an unsupported `accurate` result to `unverifiable_evidence_gate_failed` and preserve the original verdict in gate notes.

Apply the escalation triggers from `_taxonomy.md` as you classify. Fleet completion envelopes and retry rules do not apply to this workflow.

## Step 4 — Apply corrections

Edit the file directly. Preserve tone/style. Do NOT remove unverifiable claims. Bump `ms.date` **only** when at least one claim was fetch/contract/live-verified — never on a search-only pass.

## Step 5 — Present results

Run the **run quality gate** from `_taxonomy.md` and lead with `run_status`. Then summarize: total claims checked, issues by severity, per-issue details with source URLs. If a fact ledger is in use, upsert newly fetch/contract/live-verified facts. Ask to commit.

If a report was requested, write the summary and per-issue details to the resolved `--report` path before finishing.

## Quality

See [_shared/quality-checklist.md](../_shared/quality-checklist.md) — verify the fact-check quality section.
