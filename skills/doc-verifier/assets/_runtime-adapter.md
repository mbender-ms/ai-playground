# Runtime Adapter

Shared orchestration guidance for dual-runtime execution.

## Goal

Run parallel verification workflows in either runtime:
- Copilot CLI with `/fleet`
- Copilot Chat with `runSubagent`

Both paths must produce equivalent artifacts and status taxonomy.

## Runtime selection

Use this decision order:
1. If the user invocation explicitly uses `/fleet`, prefer CLI fleet dispatch.
2. Else if `runSubagent` is available, use Chat subagent dispatch.
3. Else fall back to sequential processing and clearly note reduced parallelism.

Do not fail a workflow only because `/fleet` is unavailable.

## Threshold-Based Dispatch

Apply these thresholds before selecting a dispatch pattern.

| Decision axis | Threshold | Dispatch choice |
|---|---|---|
| Standard Fleet track | Target 3-7 related articles, at most 40 claims and 10 high-risk claims | Pattern A (adaptive thematic track) |
| Small Fleet scope | 2 articles, or fewer than 3 related articles remain | Pattern A with the available articles; preserve the same claim limits |
| Heavy article | More than 40 claims or more than 10 high-risk claims | Dedicated heavy track; use Pattern B if the result cannot fit its output budget |
| Claims in one article | 1-40 claims and at most 10 high-risk claims | Single-article flow or one bounded Fleet track |
| Claims in one article | More than 40 claims or more than 10 high-risk claims | Pattern B (service-area or claim-group fan-out) |
| Nested need | Multiple deep-check articles with high claim counts | Pattern C (hybrid), unless runtime cannot support nested parallelism |
| Re-check run | Less than 20% changed content | Incremental path, then selective pattern choice |

Article count is never the sole size signal. Build the claim manifest before dispatch, sort paths for deterministic packing, and group by service area, shared `topic_key` overlap, and nearby subject matter.

## Escalation Triggers

Use the canonical escalation triggers in [_taxonomy.md](./_taxonomy.md) → "Escalation triggers" (including the contract-conflict trigger). Do not restate them here.

## Dispatch patterns

### Pattern A: Adaptive thematic track parallelism

Use when verifying multiple articles.
- Unit of parallel work: one bounded thematic slice from `batch_manifest_<runid>.json`
- Standard unit: 3-7 related articles, no more than 40 claims or 10 high-risk claims
- Output per attempt: one JSON object conforming to `schemas/track-result.schema.json`
- Final merge output: reconciled in-memory run model; render `factcheck_batch_<runid>.md` only when reports are requested

CLI path:
- `/fleet` creates one task per planned thematic track.

Chat path:
- Spawn one `runSubagent` call per planned thematic track.
- Orchestrator waits for all subagents, then consolidates.

### Pattern B: Service-area fan-out parallelism

Use for deep verification of one article with many claims.
- Unit of parallel work: one service-area claim group
- Output per unit: structured claim result set
- Final merge output: one `factcheck_[article]_<runid>.md`

CLI path:
- If subagent tooling is available, spawn subagents for each service group.
- Otherwise process groups sequentially.

Chat path:
- Spawn one `runSubagent` call per service group.
- Merge by claim ID; tier precedence resolves conflicts.

### Pattern C: Hybrid parallelism

Use when deep-checking multiple articles.
- Top level: article-level dispatch
- Inside each article: service-area fan-out

If runtime limits nested parallelism, keep top-level article dispatch and run service groups sequentially inside each article.

## Output guarantees

Regardless of runtime:
1. Every artifact name includes the run ID (`YYYYMMDD-HHMMSS`, generated once at Step 0), so two runs never overwrite each other.
2. Fleet track attempts return JSON only. Markdown is rendered from the reconciled run model after validation and reconciliation.
3. Status taxonomy remains identical across runtimes — the 7-value enum in [_taxonomy.md](./_taxonomy.md) (`accurate`, `partial`, `inaccurate`, `outdated`, `unverifiable`, `broken`, `contested`). No runtime may add or drop values.
4. Source citation shape remains identical: URL plus tier.
5. Every run ends with the run quality gate from [_taxonomy.md](./_taxonomy.md) and reports `run_status: passed|degraded|failed`.
6. Initial completed track results are at most 12 KiB; retry results are at most 8 KiB. Findings are never silently truncated.
7. Runtime-equivalent execution preserves article and claim accounting even when processing sequentially.

## Failure handling

Validate each attempt for a nonempty response, JSON syntax, schema conformance, known claim identities, complete claim coverage, and output size.

Retryable conditions are: empty response, timeout, tool error, malformed JSON, schema failure, unknown claim identity, incomplete claim coverage, and output-limit breach.

If an initial parallel unit fails:

1. Record the failed attempt and continue unaffected units.
2. Perform one retry wave with reduced scope and the 8 KiB budget. Split a multi-article track into article-level retries; split an oversized heavy article by service area or coherent claim group.
3. Keep the current/default model for transport, format, and size retries. Do not treat model escalation as error recovery.
4. Never recurse and never perform a third attempt for the same article/claim assignment.
5. After retry exhaustion, emit explicit failed article and claim records with stable reason codes, then consolidate all available results.

## Runtime capabilities and model routing

At run start, record whether the runtime exposes explicit model selection and reliable model/token telemetry.

- When either capability is unavailable, use the existing default fact-checker and record `routing_mode: default_capability_unavailable` with the missing capability.
- Unknown model, token, and tool-call values remain `null` and appear in `unavailable_fields`; never estimate them.
- Capability detection must never block verification.
- Two-tier model routing remains off by default until the A/B promotion gate documented in the Fleet workflow passes. When experimentation is enabled, routing decisions and fallback reasons must be preserved in each track summary.

## Capability note for test protocols

T4.1 validates CLI `/fleet` dispatch.
T4.3 validates Chat `runSubagent` dispatch with equivalent outputs.
