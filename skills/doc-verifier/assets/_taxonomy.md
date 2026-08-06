# Canonical Taxonomy and Routing (normative)

**Taxonomy version: 1.3.0**

Single source of truth for status values, claim risk classes, the accurate-verdict gate, routing thresholds, escalation triggers, and the run quality gate. **Every workflow prompt loads this file in its Setup step.** Other files (README, SKILL.md, references) may summarize for human readers, but those copies are non-normative — when they disagree, this file wins.

> **Load canary:** every run summary and report header must state the taxonomy version it applied (`Taxonomy: 1.3.0`). This is how test protocol T7 detects whether the runtime actually loaded this file — an agent that cannot cite the version did not load it and must not claim gate compliance.

## Status enum (all workflows, all runtimes)

| Status | Icon | Meaning |
|--------|------|---------|
| `accurate` | ✅ | Matches current official documentation |
| `partial` | ⚠️ | Mostly correct — needs minor update or added context |
| `inaccurate` | ❌ | Contradicts official sources |
| `outdated` | 🕐 | Was correct but superseded |
| `unverifiable` | ❓ | No authoritative source found — flag, never remove |
| `broken` | 🔗 | URL doesn't resolve or anchor is missing |
| `contested` | ⚖️ | Authoritative prose sources disagree AND the API contract is silent — flag for Live Validation or product-team confirmation; never assert a value |

No other status values are valid. A finding using any other value fails the run quality gate.

## Unverifiable reason codes

Every `unverifiable` finding must include exactly one reason code. Other statuses use a null reason code.

| Reason code | Use when |
|-------------|----------|
| `unverifiable_no_authoritative_source` | No authoritative source addresses the claim |
| `unverifiable_insufficient_evidence` | Relevant evidence exists but cannot support a terminal verdict |
| `unverifiable_source_unavailable` | The required authoritative source could not be accessed during the run |
| `unverifiable_evidence_gate_failed` | A proposed `accurate` verdict failed the accurate-verdict or Contract gate |
| `unverifiable_out_of_scope_artifact` | Verification depends on an excluded image, binary, PDF, or referenced script artifact |

Referenced artifact contents remain outside the documentation-only workflow. Record the final reason code without reading the excluded artifact.

## Claim risk classes

Depth is driven by claim class — there is no global quick/thorough toggle.

- **High risk** — `limit`, `config`, `pricing`, `status`, `prereq`, and any `feature` claim stating a number, version, date, or lifecycle state. Each gets a dedicated authoritative fetch; a search snippet can never make a high-risk claim `accurate`. High-risk claims carry a non-`—` `topic_key` and feed cross-track reconciliation.
- **Low risk** — prose `feature`, `cli`, `code`, `link`. Search-only verification is acceptable; fetch only on an apparent discrepancy. Low-risk claims share the pooled fetch budget.

## Accurate-verdict gate

A claim may be scored `accurate` **only** when all of the following hold. Otherwise it is `unverifiable` (or the appropriate non-accurate status) — never default a plausible-but-unchecked claim to `accurate`.

- `source_tier ≤ 2`, and
- **high-risk** claims: `verification_method` is `fetch`, `code-sample`, `contract`, `live`, or a fresh `ledger` hit, and `verified_value` matches the article text. A search snippet is not sufficient evidence.
- **numeric limit/quota, config-default, or enum** claims: an agreeing **Contract source** (Tier 1-C) is required for `accurate`; prose agreement alone caps at `confidence: medium`. If the contract is silent and prose sources conflict → `contested`.
- **low-risk** claims may be `accurate` via `search` when the snippet is unambiguous; set `confidence: medium`.

Checklist form: every **high-risk** claim is fetch/contract/live-confirmed; **low-risk** claims are search-verified at minimum.

## Self-citation exclusion

Evidence for a claim is **invalid** if its URL resolves to the article under verification — the same learn.microsoft.com path, or the `MicrosoftDocs/*` repo source of that same file. Cross-article agreement inside the same batch is corroboration, not verification; at least one evidence source must be independent of the batch.

## Threshold matrix (workflow and tier routing)

> Rows keyed on claim volume are evaluated **after claim extraction (Step 1)** — claim volume is known only from a manifest, never estimated.

| Decision axis | Threshold | Route | Tier |
|---|---|---|---|
| Single article claim volume | 1–15 claims and low ambiguity | Single Article | Tier 2 |
| Single article claim volume | 16–40 claims or mixed ambiguity | Single Article (Tier 2 gather, Tier 1 adjudicate) | Tier 2 then Tier 1 |
| Single article claim volume | >40 claims, cross-service scope, or safety-critical content | Fleet Batch (single-article track) | Tier 1-heavy |
| Batch size | Multiple articles | Fleet Batch (adaptive thematic tracks; preserve per-article and per-claim accounting) | Tier 2 orchestration, Tier 1 on contested claims |
| PR scope | 1–5 doc files, mostly editorial or metadata changes | PR Review standard pass | Tier 2 or Tier 3 |
| PR scope | >5 files or major technical changes | PR Review + deep pass on high-risk files | Tier 1 on flagged files |
| Claim class | limit / quota / config-default / enum | Require Tier 1-C contract confirmation; if contested, route to Live Validation | Tier 1-C |

## Escalation triggers (accuracy-first)

Escalate a claim or file to Tier 1 adjudication when any trigger matches:

- **Tier conflict**: Tier 1 and Tier 2 sources disagree.
- **Unverifiable rate**: more than 10% of claims in one file are unverifiable.
- **Safety impact**: claims affect RBAC, authentication, encryption, compliance, or production availability.
- **Confidence drop**: reviewer confidence is below high after Tier 2 analysis.
- **Policy or retirement risk**: deprecation, retirement, or SKU support boundary claims are present.
- **Contract conflict**: a Contract source (Tier 1-C) disagrees with Tier-1 prose, OR two prose sources conflict and the contract is silent → escalate to Live Validation.

## Run quality gate

Every run ends with a gate evaluation. Report `run_status` first in chat and in any report artifact.

| Check | Fail/degrade when |
|---|---|
| Status schema | **Fail** if any finding uses a status outside the enum or an `unverifiable` finding lacks a valid reason code |
| High-risk compliance | Downgrade unsupported `accurate` to `unverifiable` with `unverifiable_evidence_gate_failed`; **degrade** and record the original verdict in gate notes |
| Contract compliance | Downgrade numeric/default/enum `accurate` without agreeing Tier 1-C evidence to `unverifiable` with `unverifiable_evidence_gate_failed`; **degrade** |
| File completeness | **Fail** unless `discovered_in_scope = completed + explicitly_failed`; zero-claim documentation files count as completed |
| Claim completeness | **Fail** unless every manifest claim has exactly one terminal finding or one explicit failed-claim record |
| Exhausted failures | **Degrade** when all work is accounted for and up to 10% of in-scope articles explicitly fail; **fail** above 10% or when no article completes |
| Reconciliation | **Fail** if a multi-file `topic_key` group was not reconciled (batch runs) |
| Self-citation | **Fail** if any evidence URL resolves to the article under verification |
| Unverifiable rate | **Degrade** when more than 10% of claims in a file or run are `unverifiable` |

- `passed` — all work is accounted for, no article or claim failed, and every check is satisfied.
- `degraded` — all work is accounted for and useful results remain, but one or more degrade conditions apply. State each condition and reason.
- `failed` — an accounting invariant or hard gate failed, more than 10% of in-scope articles failed, or no article completed. Consolidate any available results, but do not present the run as authoritative.

Gate output format (chat and report header): `run_status: <value> · Taxonomy: 1.3.0` followed by one line per degraded/failed check.
