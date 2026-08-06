# Fact-Check Subagent Contract

Shared input and output contract for parallel verification subagents.

> Normative status enum, risk classes, and the accurate-verdict gate live in [_taxonomy.md](./_taxonomy.md). Load it alongside this contract; this file defines only the I/O schemas, budgets, and merge rules.

## Input schema

Each claim-verification subagent receives the common verification controls below. A Fleet Batch track also receives the run and completion-envelope fields so the orchestrator can validate accounting without interpreting prose.

- `service_area`: string
- `claims`: array of claim objects
- `search_strategy`: `batched` or `per-claim` (default `batched`)
- `max_fetch_calls`: integer (default `3`) — shared budget for low-risk claims
- `high_risk_fetch_calls`: integer (default `1 per high-risk claim`) — dedicated budget so numeric/limit/version/status claims always get an authoritative fetch
- `token_budget`: integer (default `2000`)

Fleet Batch track fields:

- `schema_version`: `1.3.0`
- `taxonomy_version`: `1.3.0`
- `run_id`: string (`YYYYMMDD-HHMMSS`)
- `track_id`: stable string from the batch manifest
- `attempt`: `1` for initial dispatch or `2` for the single retry wave
- `article_paths`: array of repo-relative documentation paths
- `claims`: the exact manifest claim slice assigned to the track
- `output_budget_bytes`: `12288` on attempt 1 or `8192` on attempt 2
- `cache_refs`: optional run-cache, Contract-cache, link-check, and fresh ledger references
- `routing`: capability and routing signals supplied by the runtime adapter

## Claim risk classes

Defined normatively in [_taxonomy.md](./_taxonomy.md) → "Claim risk classes". Spend the fetch budget where defects concentrate: each high-risk claim gets its own authoritative fetch (and, for numeric/default/enum claims, a Contract-source confirmation — if the contract states a bound it wins over prose; if the contract is silent and prose disagrees, return `contested`). Low-risk claims share the pooled budget.

Claim object shape:

```json
{
  "schema_version": "1.3.0",
  "article_path": "articles/load-balancer/health-probes.md",
  "claim_id": "C001",
  "line": 23,
  "type": "feature",
  "risk_class": "low",
  "topic_key": "—",
  "text": "Health probes support HTTP, HTTPS, and TCP protocols",
  "service_area": "Azure Load Balancer",
  "context": "Standard SKU"
}
```

`topic_key` is the cross-article correlation slug coined in the claim manifest. It names the *fact*, not the value, and is identical for the same fact across every file in the batch. Subagents MUST echo it back unchanged so the orchestrator can group results across tracks. A value of `—` means the claim is not subject to cross-article reconciliation.

## Output schemas

Single Article and other non-Fleet callers use the reusable finding object in [`schemas/findings.schema.json`](../schemas/findings.schema.json) → `$defs.finding`.

Each Fleet track returns exactly one JSON object conforming to [`schemas/track-result.schema.json`](../schemas/track-result.schema.json). Do not return Markdown beside it. The envelope contains the attempt identity, expected/completed/failed article and claim references, findings, failure details, output bytes, and telemetry availability.

Finding objects use this shape; the schema owns required fields and conditionals:

```json
{
  "claim_id": "C001",
  "file": "articles/load-balancer/health-probes.md",
  "topic_key": "—",
  "status": "accurate",
  "claim_type": "feature",
  "risk_class": "low",
  "verified_value": "HTTP, HTTPS, and TCP",
  "verification_method": "search",
  "contract_required": false,
  "contract_checked": false,
  "contract_value": null,
  "contract_source": null,
  "confidence": "medium",
  "source_independent": true,
  "source_url": "https://learn.microsoft.com/...",
  "source_tier": "1",
  "reason_code": null,
  "fix": null,
  "gate_notes": []
}
```

`topic_key` is echoed back from the input unchanged. `verified_value` is the normalized fact the authoritative source states (a number, range, version, date, or lifecycle state) — the orchestrator compares this field across tracks that share a `topic_key`. For prose claims with no discrete value, set `verified_value` to a short canonical phrase. `verification_method` records how the verdict was reached, and `confidence` reflects source strength and agreement.

### Compact output rules

- Initial Fleet results must be no larger than 12 KiB (`12288` bytes). Retry results must be no larger than 8 KiB (`8192` bytes).
- Accurate low-risk findings use the compact schema shape: identity, canonical topic key, status, verified value, method, confidence, source URL/tier, evidence-gate booleans, and null reason/fix fields. Omit optional prose fields.
- High-risk and every non-accurate finding include concise evidence and corrective text as required by the finding schema.
- Never truncate or drop findings to fit the budget. Return a failed envelope with `output_limit_exceeded`, allowing the orchestrator to split the assignment once.

### Completion and telemetry rules

- Echo the manifest's expected article and claim references. Partition each expected item into completed or explicitly failed output exactly once.
- An attempt has terminal `status: completed|failed`; retry is represented by `attempt: 2`, never by a third status.
- Telemetry values are recorded only when directly observable. Unknown model, token, or call values are `null` and named in `unavailable_fields`; never estimate them.
- `field_sources` identifies each available telemetry field as `runtime`, `orchestrator`, or `subagent`.

## Shared operating constraints

1. **Cache first**: before any MCP call, read the run's pre-search cache (`search_*_<runid>.json` / `queries_*_<runid>.txt`), contract cache (`contract_*`), and link-check output (`links_*.json`) if the orchestrator provided them. Never re-fetch a page another track already cached.
2. Search first, fetch selectively.
3. Use `microsoft_docs_search` for discovery.
4. Use `microsoft_docs_fetch` only for top matches.
5. Enforce `maxTokenBudget=2000` on fetch calls.
6. Do not exceed the budget: low-risk claims share `max_fetch_calls`; each high-risk claim has its own `high_risk_fetch_calls` allowance so it is never starved by prose claims.
7. For `code` or `cli` claims, use `microsoft_code_sample_search` when needed.
8. **Fact ledger** (when the orchestrator supplies ledger hits): a fresh entry whose `verified_value` matches the article text may be returned as `accurate` with `verification_method: ledger` and the ledger's source fields; a fresh entry that conflicts with the article text must be verified live. Ledger results still flow through cross-track reconciliation (see `schemas/facts-ledger.schema.json`).

## Accurate-verdict gate

Defined normatively in [_taxonomy.md](./_taxonomy.md) → "Accurate-verdict gate". Apply it to every claim. If no Tier-1/2 source is found, return `unverifiable` and keep the claim in the report — do not drop or guess. Evidence must satisfy the self-citation exclusion in `_taxonomy.md`: never cite the article under verification as its own source.

## Standard subagent instruction template

Use this exact structure for all workflows that spawn claim-verification subagents:

```text
You are a fact-checking subagent for {service_area} claims.

Verify each claim against official Microsoft sources.
Use microsoft_docs_search first, then microsoft_docs_fetch for top matches.
Apply maxTokenBudget={token_budget} on fetch calls.
Low-risk claims share {max_fetch_calls} fetch calls; each high-risk claim
(limit, config, pricing, status, prereq, or any feature stating a number,
version, date, or lifecycle state) gets its own fetch and MUST be confirmed
against a fetched Tier-1/2 page — a search snippet alone cannot make a
high-risk claim "accurate". Capture that page's value in `verified_value`,
set `verification_method` and `confidence`, and echo each claim's `topic_key`
back unchanged so the orchestrator can reconcile the same fact across articles.
If no Tier-1/2 source confirms a claim, return "unverifiable" — never default
an unchecked claim to "accurate".

Return exactly one JSON track-result object using the required schema. Return no
Markdown and no text outside the JSON object. Account for every assigned article
and claim in the completion envelope. Never truncate findings; if the result
cannot fit in {output_budget_bytes} bytes, return a failed envelope with
reason_code "output_limit_exceeded".

Claims to verify:
{claims_json}
```

## Merge rules for orchestrators

1. Parse the response as one JSON object, measure its encoded byte length, replace or verify `output_bytes`, validate it against `track-result.schema.json`, and enforce the attempt's byte budget before merging.
2. Match results by the compound identity `{file, claim_id}`. An unknown claim identity makes the attempt malformed and retryable.
3. Compare expected coverage with completed findings plus explicit failed-claim records. Missing or duplicate accounting makes the attempt incomplete and retryable.
4. Restore each known claim's canonical `topic_key` from the batch manifest. Record a contract violation when a returned key differs; do not let subagents create canonical keys.
5. Enforce the accurate-verdict and Contract gates from `_taxonomy.md`. Deterministically downgrade unsupported `accurate` results to `unverifiable` with `unverifiable_evidence_gate_failed`, preserving the original verdict in `gate_notes`.
6. If duplicate claim results conflict, pick the higher-tier source. If tiers match and conflict remains, classify as `partial` and include both URLs in evidence notes.
7. Keep unverifiable and explicitly failed claims in the run model; do not silently drop either.

## Cross-track reconciliation (shared claim ledger)

After all tracks return, the orchestrator MUST run a reconciliation pass before writing the consolidated report. This is what catches cross-article inconsistencies that no single isolated track can see.

1. **Group** every returned result by `topic_key`, ignoring groups where `topic_key` is `—` and singletons (a key that appears in only one file).
2. **Compare `verified_value`** within each multi-file group:
   - If any track in the group returned `verification_method: contract` or `live`, that value is authoritative and outranks every `fetch`/`search` prose value — propagate it and mark conflicting prose files `inaccurate`/`outdated`.
   - All values agree and at least one is fetch-verified (`source_tier ≤ 2`) → the group is consistent. Propagate the authoritative value to any track that marked the claim `unverifiable`.
   - Values disagree → raise a **conflict**. The correct value is the one backed by the highest-tier source; every file whose text states a different value is `inaccurate` (or `outdated` if it was historically correct), regardless of how the owning track originally scored it. A track's local ✅ does **not** override a cross-track conflict.
   - No value in the group is fetch-verified → mark the whole group `unverifiable` and flag for a deep pass; do not let mutual agreement between unverified snippets count as accurate.
3. **Emit a reconciliation table** in the consolidated report listing every conflicted `topic_key`, the value each file asserts, the authoritative value, and the source. These are the highest-value findings in the batch — list them first.
