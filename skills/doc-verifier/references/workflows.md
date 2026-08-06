# Doc-Verifier Workflows — Detailed Reference

Detailed procedures, outputs, and comparison for the four doc-verifier workflows.

All workflows are **chat-only by default**. To save a markdown report, pass `--report <path>` — a file path for Single Article, PR Review, and Research; a directory for Fleet Batch. If a report is requested without a path, ask for the path before completing.

---

## Routing and escalation

The Threshold Matrix and Escalation Triggers are defined normatively in [assets/_taxonomy.md](../assets/_taxonomy.md) — routing by claim volume is evaluated **after** claim extraction, never on estimates. Do not restate the tables here.

---

## Workflow 1: Single Article Check

**Prompt**: `single-article-check.prompt.md` | **Mode**: Agent

### When to use

- Full verification of a single article with product-area scoping
- Need product-area-specific search domains

### Key features

- Step 0 scoping: detects product area from `ms.service`/`ms.prod` metadata
- Uses product-area-specific search terms and paths
- Depth is driven by claim risk class and the threshold matrix — no user depth question

### Procedure

1. Scope: identify product area and service
2. Extract the claim manifest (all verifiable claims, including SKU/tier requirements), then route by actual claim count
3. Deterministic pre-pass: link-check script + fact-ledger lookup
4. Verify using product-area-specific search queries; Tier 1-C contract check for numeric/default/enum claims
5. Classify accuracy (canonical 7-status enum in `assets/_taxonomy.md`)
6. Apply corrections; bump `ms.date` only when at least one claim was fetch-verified
7. Run the quality gate; present results with per-issue details and source URLs

### Output

- Edited file with corrections
- Chat summary with source citations
- Optional markdown report when `--report <path>` is supplied

---

## Workflow 2: PR Review

**Prompt**: `pr-review.prompt.md` | **Mode**: Agent

### When to use

- Fact-check all changed files in a GitHub pull request
- Produce a verification summary for PR reviewers

### Procedure

1. Scope: PR number, repository, product area
2. Load PR: fetch metadata, list changed files, filter to `.md`/`.yml`/`.yaml`
3. Catalog and group files by service area
4. Verify per service group
5. Classify findings
6. Assemble findings; present in chat (or write to `--report <path>` if requested)

### Output

- Chat summary with per-file verification, link audit, and sources
- Optional markdown report when `--report <path>` is supplied
- Options: post findings as a PR comment, apply corrections

---

## Workflow 3: Research

**Prompt**: `microsoft-researcher.prompt.md` | **Mode**: Agent

### When to use

- Investigate a topic, not edit a file
- Answer a technical question with evidence, citations, and source tiers

### Key features

- 7-tier hierarchy (4 public + 3 internal)
- Output options: `output:chat` (default), `output:file` / `--report <path>`, `output:both`
- Does NOT edit existing files unless explicitly asked
- Claims classified: Verified / Partially Verified / Internally Verified / Unverifiable

### Procedure

1. Understand the research question (topic, scope, depth, audience, output)
2. Search broadly across public sources
3. Go deep — fetch full pages for key sources
4. Consult internal sources (if applicable)
5. Cross-reference and verify all claims
6. Validate code examples
7. Deliver output in the requested format

### Output

- Research findings: Summary, Details, Code Examples, Caveats, Sources table
- Optional: ⛔ Internal Findings section
- Optional markdown report when `--report <path>` (or `output:file`/`output:both`) is supplied

---

## Workflow 4: Fleet Batch

**Prompt**: `fleet-batch-verify.prompt.md` | **Mode**: Agent (parallel — CLI `/fleet` or Chat `runSubagent`)

### When to use

- Verify multiple articles in parallel

### Key features

- Builds one authoritative batch manifest before fan-out, including every in-scope article and compound claim identity
- Packs related articles into bounded adaptive thematic tracks while preserving per-article and per-claim accounting
- Validates JSON-only track results, retries failed assignments once with smaller scope, and never silently truncates findings
- Enforces evidence and Contract gates during merge, then reconciles canonical `topic_key` groups; the highest-tier source wins on conflict
- Computes exact file and claim completeness before assigning the run status

### Procedure

1. Discover and register every `.md`/`.yml`/`.yaml` path; zero-claim files remain completed in-scope work
2. Build and validate the batch manifest with article paths, claim identities/risk, canonical topic keys, and track plan
3. Run deterministic link/cache/ledger pre-passes, then dispatch bounded thematic tracks
4. Validate each track envelope and perform one scope-reduction retry wave for retryable failures
5. Merge against the manifest, enforce evidence gates, reconcile shared claims, and calculate completeness
6. Present rendered findings in chat, or persist manifest/track/findings JSON plus Markdown with `--report <dir>`

### Output

- Chat consolidated findings with cross-article reconciliation table
- Optional validated batch manifest, track summary/results, run findings JSON, and Markdown rendered from the reconciled model when `--report <dir>` is supplied
- Optional corrections applied to articles when requested

---

## Supporting step: Claim Manifest

**Prompt**: `claim-manifest.prompt.md`

Not a standalone workflow. The Fleet Batch workflow uses claim-manifest extraction to catalog every claim and assign a `topic_key` to each one, building the cross-article index that powers reconciliation. It can also be run ad hoc to inventory an article's claims before verification.

---

## Workflow comparison

| Feature | Single Article | PR Review | Research | Fleet Batch |
|---------|----------------|-----------|----------|-------------|
| Edits file | ✅ | Optional | ❌ | Optional |
| Report file | Opt-in (`--report`) | Opt-in (`--report`) | Opt-in (`--report`) | Opt-in (`--report`) |
| Product scoping | ✅ | ✅ | ❌ | ✅ |
| Internal sources | ❌ | ❌ | ✅ | ❌ |
| Multi-file | ❌ | ✅ | ❌ | ✅ |
| Parallel execution | ❌ | Optional (per service group) | ❌ | ✅ (adaptive thematic tracks) |
| Cross-article reconciliation | ❌ | ❌ | ❌ | ✅ |
