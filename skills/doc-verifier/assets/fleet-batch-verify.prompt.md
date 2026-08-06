---
mode: agent
description: "Fact-check multiple articles using adaptive thematic tracks, schema-valid JSON results, bounded retry, and completeness-safe reconciliation. Supports Copilot CLI /fleet and VS Code subagents."
tools:
  - microsoft-learn-mcp-server/microsoft_docs_search
  - microsoft-learn-mcp-server/microsoft_docs_fetch
  - microsoft-learn-mcp-server/microsoft_code_sample_search
  - read/readFile
  - read/problems
  - search/fileSearch
  - search/textSearch
  - edit/editFiles
  - edit/createFile
  - execute/runInTerminal
  - execute/getTerminalOutput
  - agent/runSubagent
  - todo
---

# Fleet Batch Verification

Fact-check a set of Microsoft documentation articles with adaptive parallel tracks. The batch manifest remains authoritative for every article, claim, and canonical topic key; tracks return compact JSON and the orchestrator renders user-facing results only after validation and reconciliation.

> **Runtime**:
> - Copilot CLI: `/fleet` dispatch (preferred)
> - Copilot Chat: `runSubagent` dispatch (equivalent output)
> - Fallback: sequential processing if parallel tools are unavailable

## Setup

Load, in this order:

1. [_taxonomy.md](./_taxonomy.md) — **normative**: status enum, risk classes, accurate-verdict gate, threshold matrix, escalation triggers, self-citation exclusion, run quality gate.
2. [_shared/source-hierarchy.md](../_shared/source-hierarchy.md) — source authority reference. Higher tier always wins.
3. [_runtime-adapter.md](./_runtime-adapter.md) — runtime dispatch rules and output guarantees.
4. [_subagent-contract.md](./_subagent-contract.md) — subagent I/O schema and call-budget defaults.
5. [`schemas/batch-manifest.schema.json`](../schemas/batch-manifest.schema.json), [`schemas/track-result.schema.json`](../schemas/track-result.schema.json), and [`schemas/findings.schema.json`](../schemas/findings.schema.json) — machine-readable artifact contracts.

Generate a run ID (`<runid>` = `YYYYMMDD-HHMMSS`) once and use it in every artifact name for this run — manifests, caches, track results, findings, and reports.

## Report output (`--report`)

By default this workflow is **chat-only** — it presents per-article findings and the consolidated cross-article reconciliation in chat without writing files. Persist artifacts only when the user asks for a report:

- If the user passes `--report <dir>`, write `batch_manifest_<runid>.json`, accepted track results or a `track_summary_<runid>.json`, `findings_<runid>.json`, and `factcheck_batch_<runid>.md` under that directory. Per-article Markdown is optional and must be rendered from `findings_<runid>.json`, never from raw track prose.
- If the user requests reports but gives **no path**, ask for the directory before completing — do not guess a default location.
- If neither is present, hold all report structures in memory and present them in chat only.

Validation, retry, completeness accounting, evidence enforcement, and cross-article reconciliation always run regardless of report output.

## Step 0 — Discover and register scope

Ask the user (skip if already clear):
1. **File scope** — Which articles? (folder path, glob, or explicit list)
2. **Output** — Corrections, reports, or both? Reports are written only when requested via `--report <dir>` (see **Report output**); otherwise findings are chat-only.

Verification depth is decided by claim risk class and the threshold matrix in `_taxonomy.md` — do not ask the user for a depth preference.

Discover files (documentation text only — `.md`, `.yml`, `.yaml`):
- If folder: list files recursively, then keep only `.md`/`.yml`/`.yaml`
- If glob: expand the pattern, then filter to `.md`/`.yml`/`.yaml`
- If file list: validate each path exists, then drop any non-`.md`/`.yml`/`.yaml` entry
- **Skip every other file type** (images such as `.png`/`.jpg`/`.svg`, PDFs, binaries, media). Never read or attach them — doing so causes `Too many images in request` failures. Record dropped paths as `skipped (non-doc file type)`.

Sort repo-relative in-scope paths for deterministic processing. Register every in-scope path before reading it. A zero-claim `.md`/`.yml`/`.yaml` file remains in scope and later counts as completed; it is not skipped.

## Step 0b — Build the authoritative batch manifest

Run [claim-manifest.prompt.md](./claim-manifest.prompt.md) across every in-scope article before fan-out and build one logical object conforming to [`batch-manifest.schema.json`](../schemas/batch-manifest.schema.json):

1. Use the repo-relative path as `article_path`. `{article_path, claim_id}` is the compound claim identity; a bare `C001` is never batch-unique.
2. Assign explicit `risk_class` values from `_taxonomy.md` and include every extracted claim. Register zero-claim articles with empty claim ID arrays.
3. Build one canonical `topic_index` for high-risk facts. Reuse the same fact-naming key across articles; subagents may echo keys but may not invent or rename them.
4. Keep a logical manifest in memory for every run. Persist `batch_manifest_<runid>.json` only with `--report <dir>`.

Do not dispatch until the final manifest validates. A manifest claim that cannot be assigned is an orchestration failure, not work that may be silently omitted.

## Step 0c — Deterministic pre-pass (before fan-out)

- If a terminal is available, run [scripts/link-check.sh](../scripts/link-check.sh) across the batch — `broken` entries become 🔗 findings in the owning track's results without spending any fetch budget.
- If a fact ledger exists at `<repo>/.doc-verifier/facts-ledger.json`, validate and look up every high-risk `topic_key`: fresh entries whose `verified_value` matches the article text are pre-resolved as `accurate` (`verification_method: ledger`) and excluded from track fetch budgets; fresh entries that **conflict** with an article's text stay in scope for live verification. Version 1 ledgers remain readable; migrate accepted entries to version 2 claim-class TTL provenance only when writing after reconciliation.
- For large batches, optionally warm the search cache with [scripts/batch-presearch.sh](../scripts/batch-presearch.sh) and cache contract pages with [scripts/contract-lookup.sh](../scripts/contract-lookup.sh) so tracks read one shared lookup instead of re-fetching.

Build a run-scoped source cache keyed by canonical `topic_key` plus source URL. Search-only facts may be reused during the run but are never written as verified ledger facts.

## Step 0d — Plan adaptive tracks

Apply `_runtime-adapter.md` to populate the manifest's `track_plan`:

1. Group by service area, canonical topic-key overlap, and nearby subject matter; sort paths before packing.
2. Target 3-7 articles per standard track without exceeding 40 claims or 10 high-risk claims.
3. Use a dedicated heavy track for any article over a standard threshold. If its expected result cannot fit, split by service area or coherent claim group while preserving the same article identity.
4. Record `track_id`, article paths, compound claim references, counts, weight class, and routing signals.
5. Detect runtime model-selection and telemetry capabilities. Capability absence selects default routing and never blocks dispatch.

Revalidate the completed batch manifest before dispatch.

## Step 1 — Dispatch, validate, and retry tracks

Dispatch the finalized track plan through the selected runtime. Each unit receives the exact manifest slice and controls defined in `_subagent-contract.md`; it verifies assigned claims against official sources and returns exactly one `track-result.schema.json` JSON object.

### Step 1a — Verify assigned claims

For every assigned claim, apply the source hierarchy, accurate-verdict gate, Contract gate, self-citation exclusion, and per-class fetch budget. Reuse supplied deterministic findings and cache entries. Referenced scripts, images, binaries, and PDFs remain excluded; when a verdict depends on one, return `unverifiable_out_of_scope_artifact` without reading it.

### Step 1b — Validate each attempt

Before merging any result:

1. Reject an empty response, timeout, or tool error.
2. Parse exactly one JSON object and validate it against `track-result.schema.json`.
3. Enforce the attempt's output budget: 12 KiB initially, 8 KiB on retry. Never accept silent truncation.
4. Reject unknown compound claim identities, duplicate terminal records, or expected claims missing from both findings and explicit failures.
5. Treat a returned noncanonical `topic_key` for a known claim as a contract violation: restore the manifest value and add a gate note. An unknown claim identity is malformed, not repairable during merge.

### Step 1c — Perform one retry wave

For retryable failures, apply `_runtime-adapter.md` once:

- Split a failed multi-article track into article-level assignments.
- Split an oversized heavy article by service area or coherent claim group.
- Keep the current/default model for transport, format, coverage, and output failures.
- Mark the retry as `attempt: 2`; never recurse or attempt the same assignment a third time.

After retry exhaustion, create explicit failed article and claim records with stable reason codes. Continue consolidating unaffected and partial results.

## Step 2 — Consolidate (after all tracks complete)

Consolidation runs whenever any track result exists, even after exhausted failures. The orchestrator:

1. Merge accepted results by `{file, claim_id}` against the manifest. The manifest's identity, risk class, claim type, and canonical topic key win over track output.
2. **Enforce evidence gates** from `_taxonomy.md` and `findings.schema.json`. Downgrade unsupported `accurate` results to `unverifiable` with `unverifiable_evidence_gate_failed`, preserve the original result in `gate_notes`, and mark the run degraded.
3. **Reconcile shared claims across tracks** using [_subagent-contract.md](./_subagent-contract.md). Group by canonical `topic_key`, drop `—` and singletons, and compare `verified_value`:
   - Values agree and at least one is fetch-verified → consistent; propagate the authoritative value to any track that marked the claim `unverifiable`.
   - Values disagree → **conflict**: the highest-tier source wins, and every file asserting a different value is `inaccurate`/`outdated` even if its own track scored it ✅.
   - No value in the group is fetch-verified → mark the group `unverifiable` and flag for a deep pass.
4. Update the fact ledger after reconciliation: upsert only fetch/code-sample/contract/live-verified facts. Never write search-only or ledger-derived results as newly verified facts; update `seen_in` from accepted reconciled claims only.
5. **Compute completeness** from the manifest:
   - File invariant: `discovered_in_scope = completed + explicitly_failed`.
   - Claim invariant: every manifest claim has exactly one terminal finding or explicit failed-claim record.
   - Zero-claim documentation files count as completed.
6. Run the **run quality gate** from `_taxonomy.md`. An accounting gap is failed; fully accounted exhausted failures are degraded unless the taxonomy's failure threshold is met. List exhausted failures before ordinary findings.
7. If corrections were requested, edit only from reconciled findings. Never remove unverifiable claims. Bump `ms.date` only when at least one claim in that file was fetch/contract/live-verified.
8. Build one run object conforming to `findings.schema.json`, then render chat Markdown from it. The rendered result contains:
   - **Cross-article reconciliation table (first)** — every conflicted `topic_key`, the value each file asserts, the authoritative value, and the source:

```markdown
| topic_key | Conflicting values (file → value) | Authoritative value | Source | Files to fix |
|-----------|-----------------------------------|---------------------|--------|--------------|
| loadbalancer-outbound-idle-timeout-max | tcp-reset.md → 100 min; outbound-rules.md → 120 min | 4–120 min | [Outbound rules](URL) — Tier 1 | tcp-reset.md, tcp-idle-timeout.md |
```

   - **Executive summary** — total files, total claims, overall health score
   - **Cross-article patterns** — repeated issues across files (e.g., same deprecated API referenced in 3 articles)
   - **Per-file summary table**:

```markdown
| File | Claims | ✅ | ⚠️ | ❌ | 🕐 | ❓ | 🔗 |
|------|--------|----|-----|----|----|----|----|
```

9. With `--report <dir>`, persist the validated manifest, accepted track results or track summary, `findings_<runid>.json`, and Markdown rendered from that JSON. Without `--report`, write nothing.

## Quality checklist

See [_shared/quality-checklist.md](../_shared/quality-checklist.md). Additionally:
- [ ] Every in-scope article registered as completed or explicitly failed; zero-claim files count as completed
- [ ] Every manifest claim has one terminal finding or explicit failed-claim record
- [ ] Batch manifest validates before fan-out
- [ ] Adaptive tracks stay within standard claim/high-risk limits; heavy articles are dedicated or split
- [ ] Every accepted attempt validates against `track-result.schema.json` and its byte budget
- [ ] At most one retry wave occurred; no result was truncated
- [ ] Shared canonical `topic_key` index built across the whole batch before fan-out
- [ ] Evidence and Contract gates enforced again during merge
- [ ] Consolidated run object validates; Markdown is rendered from it
- [ ] Cross-track reconciliation run; conflicted `topic_key`s listed first
- [ ] Cross-article patterns identified
- [ ] Run quality gate evaluated; `run_status` reported first
- [ ] Fact ledger updated with newly verified facts (if in use)
- [ ] Corrections applied only if user requested

## /fleet prompt template

When running from Copilot CLI, use this structure:

```
/fleet Fact-check the following articles against Microsoft Learn documentation.
Use @fleet-batch-verify to build one batch manifest, create bounded thematic
tracks, and return schema-valid JSON results for reconciliation.

Articles:
1. articles/networking/load-balancer-health-probes.md
2. articles/networking/outbound-rules.md
3. articles/networking/tcp-reset.md

After all tracks complete, validate, retry once where required, enforce
completeness/evidence gates, and present the reconciled findings.
```

## Chat prompt template

When running from Copilot Chat, use this structure:

```
Use @fleet-batch-verify to fact-check the following articles.
Build adaptive thematic tracks and dispatch one runSubagent unit per track.

Articles:
1. articles/networking/load-balancer-health-probes.md
2. articles/networking/outbound-rules.md
3. articles/networking/tcp-reset.md

After all units complete, validate, retry once where required, enforce
completeness/evidence gates, and present the reconciled findings.
```
