---
mode: agent
description: "Extract and categorize all verifiable technical claims from a Microsoft documentation article. Produces a structured claim manifest (markdown table) without performing verification. Use as the pre-stage input for fleet-batch-verify."
tools:
  - read/readFile
  - read/problems
  - search/fileSearch
  - search/textSearch
  - edit/createFile
  - todo
---

# Claim Manifest Extractor

Read a Microsoft documentation article and produce a **structured claim manifest** — every verifiable technical assertion cataloged by type, service area, and line number. No MCP calls, no verification. Pure text analysis.

Load [_taxonomy.md](./_taxonomy.md) for the normative claim risk classes and [`schemas/claims.schema.json`](../schemas/claims.schema.json) for the sidecar contract.

This is a lightweight helper. Use it to:
- Pre-stage claims before running fleet-batch verification
- Audit an article's claim density before deciding on depth
- Generate a manifest for external tools or scripts to consume

## Step 1 — Read the article

Read the file. Extract from frontmatter:
- `title`
- `ms.service` / `ms.prod`
- `ms.topic`
- `ms.date`

Scan for `[!INCLUDE ...]` references. Read and catalog include files.

## Step 2 — Extract claims

Walk every line. A **verifiable claim** is any statement that can be confirmed or denied by checking official Microsoft documentation. Extract:

### Claim types

| Type | What to look for | Examples |
|------|-----------------|---------|
| `feature` | Capability or behavior assertions | "supports HTTP, HTTPS, and TCP" |
| `config` | Default values, settings, thresholds | "default interval is 15 seconds" |
| `api` | REST API endpoints, parameters, responses | "PUT /subscriptions/{id}/..." |
| `cli` | Azure CLI or PowerShell commands and flags | "az network lb probe create --protocol" |
| `code` | Code examples, SDK usage, syntax | "new BlobServiceClient(connectionString)" |
| `limit` | Quotas, maximums, rate limits | "max 1000 rules per NSG" |
| `pricing` | Cost, tier, SKU information | "Standard tier starts at $0.025/hour" |
| `status` | Preview/GA/deprecated/retired status | "currently in public preview" |
| `link` | URLs to other docs, tools, or resources | "https://learn.microsoft.com/..." |
| `prereq` | Required versions, tools, permissions | "requires Azure CLI 2.50+" |

### What is NOT a claim

Skip these — they're not verifiable against docs:
- Subjective guidance ("we recommend...", "consider using...")
- Structural text ("in this article, you learn how to...")
- Navigation text ("see Related content below")
- Generic descriptions that don't assert specific facts

### Assign a `topic_key` to every claim (cross-article correlation)

A `topic_key` is a short, stable, article-independent slug naming the *fact* a claim asserts — **not** the wording. Two claims in different files that describe the same underlying fact MUST share the same `topic_key`. This is what lets the batch reconciler catch cross-article conflicts (e.g., one article says an outbound idle timeout is 100 minutes while another says 120).

Rules for forming a `topic_key`:
- Use `{service}-{subject}-{attribute}` in kebab-case, lowercase. Examples: `loadbalancer-outbound-idle-timeout-max`, `loadbalancer-basic-sku-lifecycle`, `loadbalancer-udp-acronym`.
- Name the fact, not the value. `...-idle-timeout-max` is correct; `...-idle-timeout-120min` is wrong (it bakes in the value you're trying to verify).
- Reuse keys across articles. If you've already coined a key for this fact in another file, use the identical string.
- Only **high-risk** claim types need a precise shared key: `config`, `limit`, `pricing`, `status`, `prereq`, and any `feature` claim that states a number, version, date, or lifecycle state. For pure prose `feature` claims and `link`/`code`/`cli` claims, set `topic_key` to `—`.

Maintain a running **topic-key index** as you extract, so the same fact gets the same key every time.

### Assign `risk_class`

Set `risk_class: high|low` using `_taxonomy.md`. Do not infer risk from article count or service area. In Fleet Batch mode, the batch orchestrator owns the canonical topic-key index; reuse its supplied key instead of independently renaming a fact.

## Step 3 — Group by service area

Assign each claim to a service area based on content. Use `ms.service` as the primary indicator but override if a claim clearly belongs to a different service.

Common service areas:
- Azure Networking (Load Balancer, App Gateway, Front Door, Firewall, VNet, DNS, etc.)
- Azure Compute (VMs, VMSS, AKS, Container Apps, Functions, App Service, etc.)
- Azure Identity (Entra ID, RBAC, Managed Identity, Key Vault, etc.)
- Azure Storage (Blob, Files, Queue, Table, Data Lake, etc.)
- Azure Data (SQL, Cosmos DB, Synapse, Data Factory, etc.)
- Azure AI (OpenAI, Cognitive Services, ML, etc.)
- Azure DevOps (Pipelines, Boards, Repos, Artifacts, etc.)
- M365 (Exchange, SharePoint, Teams, etc.)
- Security (Defender, Sentinel, Purview, Intune, etc.)
- Cross-service (general Azure concepts, portal, ARM, Bicep, etc.)

## Step 4 — Output the manifest

Create two artifacts (use the run ID `YYYYMMDD-HHMMSS` so runs never collide):

1. **`claims_[articlename]_<runid>.md`** — the human-readable table below.
2. **`claims_[articlename]_<runid>.json`** — a machine-readable sidecar: a JSON array conforming to [`claims.schema.json`](../schemas/claims.schema.json). Each object includes `schema_version: "1.3.0"`, repo-relative `article_path`, `claim_id`, `line`, `type`, explicit `risk_class`, canonical `topic_key`, `text`, `service_area`, `context`, and `include_file`. The top-level array is retained because `batch-presearch.sh` consumes it directly.

Markdown manifest format:

```markdown
# Claim Manifest: [Article Title]

**File**: [path]
**Date**: YYYY-MM-DD
**ms.service**: [value]
**ms.topic**: [value]
**ms.date**: [value]
**Total claims**: [count]
**Include files**: [count] resolved

## Claim density

| Service area | Claims | Types |
|-------------|--------|-------|
| [area] | N | feature(X), config(Y), cli(Z) |
| [area] | N | ... |

## Claims by service area

### [Service Area 1] ([N] claims)

| ID | Line | Type | Risk | topic_key | Claim text | Include file |
|----|------|------|------|-----------|------------|--------------|
| C001 | 23 | feature | low | — | "Health probes support HTTP, HTTPS, and TCP" | — |
| C002 | 31 | config | high | loadbalancer-probe-interval-default | "Default probe interval is 15 seconds" | — |
| C003 | 45 | cli | low | — | "az network lb probe create --protocol Https" | — |
| C004 | 52 | code | low | — | "`New-AzLoadBalancerProbeConfig -Protocol Tcp`" | — |

### [Service Area 2] ([N] claims)

| ID | Line | Type | Risk | topic_key | Claim text | Include file |
|----|------|------|------|-----------|------------|--------------|
| C009 | 78 | feature | low | — | "VNet peering supports cross-region connectivity" | — |

### Links ([N] links)

| ID | Line | URL | Context |
|----|------|-----|---------|
| L001 | 12 | https://learn.microsoft.com/... | Prerequisites link |
| L002 | 89 | https://learn.microsoft.com/... | Related content |

## Include files resolved

| Include path | Claims extracted | Service area |
|-------------|-----------------|-------------|
| ~/includes/clean-up-resources.md | 0 | — |
```

## Step 5 — Present summary

In chat, provide:
- Total claims and breakdown by type
- Largest service-area group (this will be the heaviest subagent)
- Any red flags: very old `ms.date`, missing frontmatter, broken include paths
- Estimated verification weight from total and high-risk claim counts; do not predict track count until the Fleet orchestrator packs the batch manifest

## Usage with other workflows

### As input to fleet-batch-verify

```
1. Run claim-manifest on every in-scope article before dispatch
2. Build one batch-wide canonical topic index and adaptive track plan
3. Validate the batch manifest, then dispatch the planned tracks
```

### Standalone audit

Use the manifest to assess documentation quality without running full verification:
- High claim density + old `ms.date` = high staleness risk
- Many `api` or `cli` claims = high breakage risk from API changes
- Many `link` claims = link rot risk
