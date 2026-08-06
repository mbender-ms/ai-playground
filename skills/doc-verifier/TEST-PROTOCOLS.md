# Test Protocols — Doc-Verifier Workflows

Structured test procedures for validating that the four doc-verifier workflows and the `batch-presearch.sh` script produce trusted, repeatable results.

Each test has a **fixture** (what to run against), **procedure** (exact steps), **pass criteria** (what "working" looks like), and **known-good reference** (how to verify the agent's findings independently).

All workflows are chat-only by default. Where a test expects report files, run the workflow with `--report <path>` so the artifacts are written.

---

## Test fixture articles

Use real articles from the [MicrosoftDocs/azure-docs](https://github.com/MicrosoftDocs/azure-docs) repo. Clone locally or use the raw GitHub paths.

| ID | Article | Why this is a good test fixture |
|----|---------|-------------------------------|
| **F1** | `articles/load-balancer/load-balancer-custom-probe-overview.md` | Dense with feature/config/limit claims. Well-documented service — easy to verify findings manually. |
| **F2** | `articles/load-balancer/manage-probes-how-to.md` | How-to with portal steps, CLI commands, and prerequisites. Good for UI verb and procedural accuracy. |
| **F3** | `articles/virtual-network/virtual-network-peering-overview.md` | Concept article. Cross-service claims (VNet + region + subscription). Tests service-area grouping. |
| **F4** | `articles/app-service/overview.md` | Overview article. Broad feature claims, pricing tiers, limits. Tests claim density extraction. |
| **F5** | `articles/cosmos-db/introduction.md` | Different service area entirely. Tests that batch workflows handle mixed service groups. |

> **Tip**: Pick articles with `ms.date` older than 6 months — these are more likely to contain outdated claims, giving the agent real work to do.

---

## T1 — Claim manifest extractor (supporting step)

**Goal**: Verify that `claim-manifest.prompt.md` accurately extracts and categorizes claims without making any MCP calls.

### T1.1 — Basic extraction accuracy

**Fixture**: F1 (`load-balancer-custom-probe-overview.md`)

**Procedure**:

1. Open the article in VS Code
2. Run: `Use @claim-manifest to extract all verifiable claims from this article`
3. Wait for manifest output

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Claim count | ≥ 15 claims extracted (this article is dense) |
| Claim types present | At least 3 different types (feature, config, limit expected) |
| Service area grouping | Primary group is "Azure Load Balancer" |
| Line numbers | Each claim has a line number that maps to the actual article |
| `topic_key` assigned | High-risk claims (config, limit, pricing, status, prereq) each have a stable kebab-case `topic_key` |
| No MCP calls | Zero tool calls to `microsoft_docs_search`, `microsoft_docs_fetch`, or `microsoft_code_sample_search` |
| Include resolution | If article has `[!INCLUDE ...]`, those files are read and claims extracted |

**Manual verification**: Open the article side-by-side with the manifest. Spot-check 5 random claims — confirm the quoted text exists at the stated line number and the type classification is reasonable.

### T1.2 — Non-claim filtering

**Fixture**: F2 (`manage-probes-how-to.md`)

**Procedure**: Same as T1.1.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Navigation text excluded | "In this article, you learn how to..." is NOT a claim |
| Subjective guidance excluded | "We recommend..." is NOT a claim |
| Portal steps extracted | "Select **Health probes** in Settings" → extracted as a `feature` or `prereq` claim about the portal path |
| CLI commands extracted | Any `az network lb probe` commands → extracted as `cli` type |

### T1.3 — Cross-service article

**Fixture**: F3 (`virtual-network-peering-overview.md`)

**Procedure**: Same as T1.1.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Multiple service groups | At minimum "Azure Virtual Network" group; may also have "Cross-service" for region/subscription claims |
| Claim density summary | Chat output includes estimated verification effort |

---

## T2 — Single article check

**Goal**: Verify that `single-article-check.prompt.md` scopes by product area, classifies every claim, and only bumps `ms.date` on fetch-verified content.

### T2.1 — Full single-article verification

**Fixture**: F1 (`load-balancer-custom-probe-overview.md`)

**Procedure**:

1. Open the article in VS Code agent mode
2. Run: `Use @single-article-check to fact-check this article`

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Product-area scoping | Step 0 detects the product area from `ms.service`/`ms.prod` |
| Classification | Every claim gets one of the 7 canonical status icons (✅⚠️❌🕐❓🔗⚖️ — see `assets/_taxonomy.md`) |
| Contract gate | Numeric/default/enum claims carry `contract_value`/`contract_source` or are ⚖️ contested |
| `ms.date` discipline | `ms.date` bumped only when at least one claim was fetch-verified |
| Chat-only default | No report file written unless `--report <path>` was supplied |
| Report opt-in | With `--report <path>`, a markdown report is written to that path |

**Manual verification**: Pick the claims marked ❌ or ⚠️ (if any). Open the source URL cited by the agent. Confirm the agent's finding is correct — the official docs actually say what the agent claims they say.

### T2.2 — Seeded error detection (the trust test)

**Fixture**: Create a modified copy of F1 with 3 deliberate errors:

```markdown
<!-- Error 1: Wrong default value -->
The health probe attempts to check the configured health probe port every 10 seconds by default.
(Actual: 5 seconds)

<!-- Error 2: Wrong protocol list -->
Health probes support HTTP and TCP protocols.
(Missing: HTTPS)

<!-- Error 3: Outdated claim -->
Basic Load Balancer is the recommended SKU for production workloads.
(Actual: Standard is recommended; Basic is being deprecated)
```

**Procedure**: Run `single-article-check` on the modified article.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Error 1 caught | Marked ❌ or 🕐, corrected to "5 seconds" |
| Error 2 caught | Marked ⚠️ or ❌, corrected to include HTTPS |
| Error 3 caught | Marked ❌ or 🕐, corrected with note about Standard SKU |
| Detection rate | ≥ 2 of 3 seeded errors detected (67%+ minimum, target 100%) |
| False positive rate | ≤ 2 false ❌ classifications on claims that are actually correct |

> **This is the trust test.** If the agent catches all 3 seeded errors with correct source citations, and doesn't falsely flag more than 2 correct claims, the workflow is trustworthy for production use.

---

## T3 — PR review

**Goal**: Verify that `pr-review.prompt.md` executes Step 1.5 triage, selects the correct tier route, and escalates only when triggers are present.

**Fixture**:

- PR A: 2 changed docs, editorial/metadata only (low risk)
- PR B: 7 changed docs with at least one security or retirement claim (high risk)

**Procedure**:

1. Run on PR A: `Use @pr-review to fact-check PR #<low-risk-pr>`
2. Confirm triage output includes file count, estimated claim density band, and risk classification.
3. Run on PR B: `Use @pr-review to fact-check PR #<high-risk-pr>`
4. Confirm triage output includes high-risk flags and escalated routing for flagged files.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Step 1.5 evidence | Output explicitly shows triage checklist fields were evaluated |
| Low-risk routing (PR A) | Uses Tier 2 or Tier 3 first, no blanket Tier 1 across all files |
| High-risk routing (PR B) | Applies Tier 1 adjudication to flagged files or contested claims |
| Trigger fidelity | Escalations are tied to listed triggers (source conflict, unverifiable rate, safety impact, confidence drop, policy/retirement risk) |
| Over-escalation control | No escalation to Tier 1 for purely editorial findings without trigger |
| Chat-only default | Findings presented in chat; report written only with `--report <path>` |

**Manual verification**:

- For one escalated claim in PR B, open cited sources and confirm a genuine trigger existed.
- For one non-escalated editorial claim in PR A, confirm no trigger condition was present.

---

## T4 — Fleet batch verification

**Goal**: Verify that `fleet-batch-verify.prompt.md` parallelizes across multiple articles, builds the shared `topic_key` index, and reconciles cross-article conflicts.

### T4.1 — Two-article parallel run

**Fixture**: F1 + F2 (both Load Balancer articles — same service area)

**Procedure** (Copilot CLI):

```
/fleet Fact-check these 2 articles using @fleet-batch-verify:
1. articles/load-balancer/load-balancer-custom-probe-overview.md
2. articles/load-balancer/manage-probes-how-to.md
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Track plan | Both articles appear exactly once in one bounded thematic track or valid split tracks |
| Parallel execution | When the plan has multiple tracks, `/tasks` shows them running concurrently |
| Shared claim ledger | A batch-wide `topic_key` index is built before fan-out |
| Cross-article patterns | Consolidated findings note any shared issues (e.g., both articles reference the same deprecated feature) |
| Chat-only default | No report files unless `--report <dir>` was supplied |
| Report opt-in | With `--report <dir>`, per-article + consolidated reports are written there without colliding |

### T4.2 — Cross-service batch run

**Fixture**: F1 + F4 + F5 (Load Balancer + App Service + Cosmos DB — 3 different service areas)

**Procedure** (Copilot CLI):

```
/fleet Fact-check these 3 articles using @fleet-batch-verify:
1. articles/load-balancer/load-balancer-custom-probe-overview.md
2. articles/app-service/overview.md
3. articles/cosmos-db/introduction.md
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Thematic decomposition | Orchestrator keeps unrelated service areas in separate bounded tracks |
| Service isolation | Each track's MCP searches are scoped to its service area |
| Per-file summary | Consolidated findings include a per-file summary table with all 3 articles |
| Runtime | Completes faster than 3x the single-article time (parallelism working) |

### T4.3 — VS Code agent mode (runSubagent)

**Fixture**: F1 + F2

**Procedure** (VS Code, NOT Copilot CLI):

```
Use @fleet-batch-verify to fact-check these 2 articles:
1. articles/load-balancer/load-balancer-custom-probe-overview.md
2. articles/load-balancer/manage-probes-how-to.md
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| runSubagent dispatch | Agent uses one `runSubagent` unit per planned thematic track when parallel tools are available |
| Same output format | Schema-valid track envelopes and consolidated findings still produced |
| No errors from /fleet syntax | Agent adapts to the runtime environment |

### T4.4 — Cross-article reconciliation

**Fixture**: Two articles that state the same fact with conflicting values (e.g., one says the outbound idle timeout max is 100 minutes, the other 120).

**Procedure**: Run `fleet-batch-verify` over both.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Shared `topic_key` | Both claims share the same `topic_key` |
| Conflict detected | The consolidated reconciliation table lists the conflicted `topic_key` first |
| Highest tier wins | The authoritative value cites the highest-tier source |
| Both files flagged | Every file asserting a non-authoritative value is marked inaccurate/outdated |

### T4.5 — Empty response and bounded retry

**Fixture**: A three-article thematic track with a harness or runtime stub that returns an empty response on attempt 1 and valid article-level results on attempt 2.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Initial failure | Empty response is rejected before merge |
| Retry scope | Track splits into article-level assignments |
| Retry bound | Each affected assignment has at most two attempts; no recursive or third attempt |
| Accounting | Every article and claim ends completed or explicitly failed |
| Consolidation | Available results are consolidated even if one retry is exhausted |

### T4.6 — Malformed and oversized results

**Fixture**: Inject one malformed JSON response and one completed attempt whose measured response exceeds 12 KiB.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| JSON validation | Malformed response is rejected with `malformed_json` |
| Size validation | Oversized response is rejected with `output_limit_exceeded` |
| Retry budget | Attempt 2 uses an 8 KiB limit and smaller scope |
| No truncation | No finding disappears or contains truncated text |

### T4.7 — Completeness invariants

**Fixture**: Three in-scope documentation files, including one zero-claim file and one exhausted verification failure.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| File equation | `3 discovered = 2 completed + 1 explicitly failed` |
| Zero-claim file | Counts as completed, not skipped |
| Claim equation | Every manifest claim has one finding or failed-claim record |
| Accounted failure | Run is `degraded` when the failure-rate threshold is not exceeded |
| Missing failure record | Removing the explicit failure creates an accounting gap and forces `failed` |

### T4.8 — Merge-time evidence gate

**Fixture**: A high-risk `accurate` finding with search-only evidence and a numeric/default/enum `accurate` finding without Contract confirmation.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| High-risk gate | Search-only `accurate` is rejected by schema or downgraded during merge |
| Contract gate | Unchecked Contract-required `accurate` is rejected or downgraded |
| Downgrade | Final status is `unverifiable` with `unverifiable_evidence_gate_failed` |
| Audit | `gate_notes` preserves the original verdict and failure reason |

The repository fixtures `findings-high-risk-search.invalid.json` and `findings-contract-unchecked.invalid.json` exercise the schema-rejection path in CI.

### T4.9 — Manifest topic authority

**Fixture**: Return a different `topic_key` for one known compound claim identity and an unknown identity for another result.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Known identity | Manifest topic key replaces the returned key and a contract-violation gate note is recorded |
| Unknown identity | Attempt is rejected with `unknown_claim_id` and is retryable |
| Reconciliation | Only canonical manifest keys form reconciliation groups |

### T4.10 — Adaptive packing

**Fixture**: A synthetic batch manifest containing light related articles, unrelated service areas, one 40-claim article, and one article over 40 claims or 10 high-risk claims.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Standard target | Related tracks target 3-7 articles |
| Hard limits | Standard tracks never exceed 40 claims or 10 high-risk claims |
| Stable plan | Sorting identical inputs produces identical track assignments |
| Heavy handling | Oversized article is dedicated and split by service area/claim group when needed |
| Accounting | Article and compound claim identities survive every split |

### T4.11 — Telemetry availability

**Fixture**: Run in an environment that does not expose model name or token counts.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Missing values | Model and token fields are `null` |
| Availability | Missing fields appear in `unavailable_fields` |
| Provenance | Available metrics identify `runtime`, `orchestrator`, or `subagent` source |
| Honesty | No token, model, or call value is estimated |
| Routing | Verification uses default behavior and records `default_capability_unavailable` |

### T4.12 — JSON and Markdown parity

**Fixture**: An AVNM subset with at least one reconciliation conflict, one failed claim, and multiple finding statuses.

**Procedure**: Run Fleet Batch with `--report <dir>`, then compare `findings_<runid>.json` with rendered `factcheck_batch_<runid>.md`.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Counts | File, claim, failure, and status counts match exactly |
| Reconciliation | Every JSON conflict appears in Markdown with the same authoritative value |
| Must-fix findings | Every non-accurate JSON finding appears in Markdown |
| Source of truth | Markdown contains no finding absent from the reconciled JSON model |

---

## T5 — Helper scripts (smoke tests)

**Goal**: Verify that `batch-presearch.sh` extracts *claim text* (never `topic_key` slugs) from any manifest casing/layout, degrades gracefully without the Learn CLI, and that `contract-lookup.sh` never leaves a silently empty cache.

**Fixtures**: `tests/fixtures/claims_sample.md` (current 6-column layout, normal casing) and `tests/fixtures/claims_empty.md` (repo root, outside the skill folder).

### T5.1 — Manifest parsing (the B1/B2 regression test)

**Procedure**:

```bash
./scripts/batch-presearch.sh ../tests/fixtures/claims_sample.md ./test_cache/
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Exit code | 0 |
| Claim text extracted | Queries contain claim wording (e.g., "Health probes HTTP, HTTPS, and TCP") — never `topic_key` slugs like `loadbalancer-probe-protocols` |
| Low-risk claims included | The `cli` claim (`topic_key` = `—`) appears in the query set |
| Case-insensitive sections | A manifest with `### AZURE LOAD BALANCER` extracts identically |
| Old 5-column layout | A manifest without the `topic_key` column still extracts claim text (header-aware column lookup) |
| Links section skipped | No queries generated from the `### Links` table |
| Valid JSON | With the Learn CLI installed, every `search_*.json` passes `jq .` |

### T5.2 — Degraded mode (no Learn CLI)

**Procedure**: Run T5.1 on a machine (or PATH) without `learn`/`npx @microsoft/learn-cli`.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Exit code | 0 (degradation is not failure) |
| Query lists | `queries_<area>_<runid>.txt` emitted per service area |
| Instruction | Console tells the agent to run the queries via `microsoft_docs_search` |

### T5.3 — Empty manifest handling

**Procedure**: Run against `tests/fixtures/claims_empty.md`.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Graceful exit | Script prints the "no service-area sections" error and exits non-zero |
| No empty files | No JSON or query files created |

### T5.4 — Contract lookup honesty

**Procedure**:

```bash
./scripts/contract-lookup.sh microsoft.fake/widgets maxWidgets ./test_cache/
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Exit code | 2 when nothing can be captured (no Learn CLI, no az, unmapped provider) |
| No debris | No metadata/schema/help files left behind on the nothing-captured path |
| Agent fallback | Console prints the exact `microsoft_docs_fetch` call to run in-agent |
| Known provider | With az installed, `microsoft.network/loadbalancers` resolves to `az network lb --help` via the static map |

### T5.5 — Link check

**Procedure**: Run `./scripts/link-check.sh` against an article fixture containing one live URL, one dead URL, and one `#anchor` link.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Verdicts | `ok`, `broken`, and `unchecked-anchor` respectively in the JSON output |
| Valid JSON | Output passes `jq .` |
| Relative links | Relative doc links are checked against the filesystem |

---

## T6 — Accuracy scoring

Run this after completing T2.2 (seeded error test) on at least 3 different articles.

### Scoring method

For each test run, count:

- **True Positives (TP)**: Seeded errors correctly detected
- **False Negatives (FN)**: Seeded errors missed
- **False Positives (FP)**: Correct claims incorrectly flagged as ❌
- **True Negatives (TN)**: Correct claims correctly marked ✅

Calculate:

- **Precision** = TP / (TP + FP) — "When it flags an error, is it right?"
- **Recall** = TP / (TP + FN) — "Does it find all the errors?"
- **F1 Score** = 2 × (Precision × Recall) / (Precision + Recall)

### Target thresholds

| Metric | Minimum | Target |
|--------|---------|--------|
| Precision | 70% | 85%+ |
| Recall | 67% (2/3 seeded errors) | 90%+ |
| F1 Score | 68% | 87%+ |
| False positive rate | ≤ 3 per article | ≤ 1 per article |

> **80-90% accuracy goal**: If F1 Score is ≥ 80% across 3+ test articles, the workflow meets the stated accuracy target.

### Tracking table

| Test article | Seeded errors | TP | FN | FP | TN | Precision | Recall | F1 |
|-------------|---------------|----|----|----|----|-----------|--------|----|
| F1 (modified) | 3 | | | | | | | |
| F4 (modified) | 3 | | | | | | | |
| F5 (modified) | 3 | | | | | | | |
| **Totals** | **9** | | | | | | | |

---

## T7 — Taxonomy load canary (the design's load-bearing assumption)

**Goal**: Verify that each runtime actually loads `assets/_taxonomy.md` when a workflow prompt references it in Setup. The whole single-source-of-truth design depends on this — if a runtime skips the referenced file, the agent falls back to whatever taxonomy fragments it remembers, and drift returns silently.

**Detection mechanism**: `_taxonomy.md` carries a version stamp (`Taxonomy version: 1.3.0`) that exists **nowhere else** in the skill, and the run gate requires every summary/report header to cite it (`run_status: <value> · Taxonomy: 1.3.0`). An agent that cannot produce the version did not load the file.

Run T7.1 and T7.2 **in each runtime** (VS Code agent mode; Copilot CLI) and record results in the tracking table. Re-run after any VS Code / Copilot / CLI version change.

### T7.1 — Direct probe (fast, no MCP)

**Procedure**: In a fresh chat, run:

```
Use @single-article-check. Before verifying anything, state: (a) the taxonomy
version you loaded, (b) the full status enum you will use, (c) the run gate levels.
```

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Version | `1.3.0` cited — not guessed, not absent |
| Status enum | All 7 values including `broken` 🔗 and `contested` ⚖️ |
| Gate levels | `passed` / `degraded` / `failed` |
| Unverifiable semantics | Reason code is required; includes `unverifiable_evidence_gate_failed` and `unverifiable_out_of_scope_artifact` |

**Fail signature**: a 5- or 6-status enum, an invented gate, or no version — the runtime did not load the file. See mitigation below.

### T7.2 — Behavioral probe (end-to-end)

**Procedure**: Run `@single-article-check` on a seeded copy of F1 containing one dead URL and one numeric-limit claim.

**Pass criteria**:

| Check | Expected |
|-------|----------|
| Header | Output leads with `run_status: … · Taxonomy: 1.3.0` |
| 🔗 available | The dead URL is classified `broken`, not `inaccurate` |
| Contract behavior | The numeric claim carries `contract_value`/`contract_source` or is ⚖️ `contested` |
| Evidence behavior | Unsupported high-risk `accurate` is downgraded with `unverifiable_evidence_gate_failed` |
| Depth question | Agent does NOT ask "quick or thorough?" (removed in 1.2.0 — asking it means a stale prompt or unloaded taxonomy) |

### T7 tracking table

Append one row per run; keep history (do not overwrite).

| Date | Runtime | Runtime version | T7.1 | T7.2 | Notes |
|------|---------|-----------------|------|------|-------|
| | VS Code agent mode | | | | |
| | Copilot CLI | | | | |

### Mitigation if a runtime fails T7

Do not restore the duplicated tables. Instead, inline **only the status enum and gate levels** (the two smallest normative pieces) into each workflow prompt's Setup step, clearly marked `(mirror of _taxonomy.md vX.Y.Z — regenerate on taxonomy change)`, and keep everything else pointer-based. Record the failing runtime + version here so the mirror can be removed when the runtime improves.

---

## Test execution order

Run tests in this order for the most efficient validation:

1. **T7.1** — Taxonomy load canary, direct probe (fast; validates the load-bearing assumption first)
2. **T1.1** — Claim manifest basic (no MCP calls, fast, validates extraction)
3. **T1.2** — Claim manifest filtering (confirms non-claims excluded)
4. **T5.1** — Presearch script parsing regression (also runs in CI)
5. **T5.2–T5.5** — Script degradation, empty manifest, contract-lookup honesty, link-check
6. **T2.1** — Single article basic (first MCP-dependent test)
7. **T7.2** — Taxonomy load canary, behavioral probe (piggybacks on T2 fixtures)
8. **T2.2** — Single article seeded errors (**the trust test**)
9. **T3** — PR review triage thresholds
10. **T4.1** — Fleet two-article parallel
11. **T4.2** — Fleet cross-service
12. **T4.4** — Fleet cross-article reconciliation
13. **T4.5–T4.11** — Fleet retry, completeness, evidence, authority, packing, and telemetry
14. **T4.12** — JSON/Markdown parity
15. **T6** — Accuracy scoring (after running T2.2 on 3+ articles)
