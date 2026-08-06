# Microsoft GitHub Repository Catalog

Source-of-truth catalog of repositories across key Microsoft GitHub organizations, designed for
agent-based research and to reduce token usage by pointing agents to specific repos and files.

## Organizations indexed

The per-org monolith files (`Azure.yml`, `microsoft.yml`, `MicrosoftDocs.yml`, `MicrosoftCopilot.yml`, and the `general.yml` catch-all — ~1.4 MB combined) live at the repo root under **`tools/sources-orgs/`** and are **not shipped with the installed skill**. Fact-checking workflows only need the per-category files below; org-wide browsing is a maintenance activity, not a verification step.

**Total repos indexed: 3,000** (non-archived, pushed since 2024-03-20; the GitHub API caps listings at the 1,000 most recently pushed repos per org)

## Category cross-reference files

Each category file aggregates repos across all 4 organizations. See [categories-index.yml](categories-index.yml) for the master index.

### Product areas

| Category | Repos | File |
|---|---|---|
| `general` | 1,118 | `tools/sources-orgs/general.yml` (repo root — not shipped) |
| `azure-general` | 343 | [azure-general.yml](azure-general.yml) |
| `azure-compute` | 231 | [azure-compute.yml](azure-compute.yml) |
| `developer-tools` | 215 | [developer-tools.yml](developer-tools.yml) |
| `azure-ai` | 212 | [azure-ai.yml](azure-ai.yml) |
| `azure-iac` | 148 | [azure-iac.yml](azure-iac.yml) |
| `m365` | 102 | [m365.yml](m365.yml) |
| `windows` | 99 | [windows.yml](windows.yml) |
| `azure-data` | 80 | [azure-data.yml](azure-data.yml) |
| **`azure-networking`** | **73** | [**azure-networking.yml**](azure-networking.yml) |
| `azure-devops` | 61 | [azure-devops.yml](azure-devops.yml) |
| `dynamics` | 55 | [dynamics.yml](dynamics.yml) |
| `azure-security` | 50 | [azure-security.yml](azure-security.yml) |
| `power-platform` | 45 | [power-platform.yml](power-platform.yml) |
| `copilot` | 43 | [copilot.yml](copilot.yml) |
| `azure-iot` | 37 | [azure-iot.yml](azure-iot.yml) |
| `azure-monitor` | 34 | [azure-monitor.yml](azure-monitor.yml) |
| `azure-integration` | 17 | [azure-integration.yml](azure-integration.yml) |
| `gaming` | 13 | [gaming.yml](gaming.yml) |
| `azure-storage` | 12 | [azure-storage.yml](azure-storage.yml) |
| `azure-messaging` | 12 | [azure-messaging.yml](azure-messaging.yml) |

### Function types (tags within each repo entry)

| Type | Description |
|---|---|
| `documentation` | Docs, Learn content, articles, reference guides |
| `sdk` | Client libraries, SDKs |
| `cli-tool` | CLI tools, extensions, utilities |
| `sample` | Samples, quickstarts, demos, tutorials, workshops |
| `template` | Templates, blueprints, accelerators, landing zones |
| `iac` | Bicep, ARM, Terraform, infrastructure-as-code |
| `service` | Backend services, APIs, microservices |
| `specification` | OpenAPI specs, schemas, protocols, standards |
| `community` | Community resources, governance, awesome lists |
| `other` | Repositories not matching other function types |

## YAML schema

Each org file and category file follows this structure:

```yaml
# Per-org files
organization:
  name: <org-name>
  url: "https://github.com/<org>"
  total_repos: <count>
  generated: <YYYY-MM-DD>

summary:
  by_product_area:
    <area>: <count>
  by_function_type:
    <type>: <count>

repos:
  - name: <repo-name>
    url: <github-url>
    description: <repo description>
    product_area: <product area tag>
    function_type: <function type tag>
    language: <primary language>
    last_pushed: <YYYY-MM-DD>
    stars: <count>
    forks: <count>
```

```yaml
# Cross-reference category files
category: <area-name>
total_repos: <count>
generated: <YYYY-MM-DD>

sources:
  - org: <org-name>
    count: <count>

repos:
  - name: <repo-name>
    org: <org-name>
    url: <github-url>
    description: <description>
    product_area: <area>
    function_type: <type>
    stars: <count>
```

## Agent usage

Agents can reference these catalogs to:

1. **Find relevant repos** — Look up the category file (e.g., `azure-networking.yml`) to find repos related to a specific topic
2. **Reduce token usage** — Instead of searching GitHub broadly, start from a known catalog of repos
3. **Navigate by org** — Use org files under `tools/sources-orgs/` (repo checkout only; not shipped with the skill) to find repos in a specific organization
4. **Filter by function** — Use `function_type` to find SDKs vs. documentation vs. samples for a given topic
5. **Check freshness** — `last_pushed` dates help agents prioritize actively maintained repos

### Example queries an agent might resolve

| Question | Approach |
|---|---|
| "Find Azure Firewall documentation repos" | Search `azure-networking.yml` for `firewall` in name/description |
| "What SDKs does Azure publish?" | Filter `Azure.yml` for `function_type: sdk` |
| "Find the M365 Graph documentation" | Check `m365.yml` or filter `MicrosoftDocs.yml` for `graph` |
| "Which IaC templates exist for networking?" | Cross-reference `azure-networking.yml` with `function_type: iac` or `template` |

## Taxonomy — product area classification

Classification is based on keyword matching against repo name + description:

| Product area | Keywords / signals |
|---|---|
| `azure-networking` | network, firewall, dns, vpn, vnet, front-door, load-balancer, expressroute, bastion, private-link, application-gateway, traffic-manager, ddos, cdn, waf, nsg |
| `azure-compute` | vm, container, aks, kubernetes, app-service, functions, batch, service-fabric, container-app |
| `azure-storage` | storage, blob, data-lake, file-share, managed-disk |
| `azure-data` | sql, cosmos, synapse, databricks, data-factory, mysql, postgres, redis, hdinsight |
| `azure-ai` | cognitive, openai, ai, ml, machine-learning, bot-framework, speech, vision, semantic-kernel, foundry |
| `azure-security` | sentinel, defender, entra, identity, key-vault, msal, active-directory |
| `azure-devops` | devops, pipeline, boards, artifacts |
| `azure-iac` | bicep, arm-template, terraform, pulumi, quickstart, resource-manager |
| `azure-monitor` | monitor, log-analytics, app-insight, diagnostic, workbook, grafana, opentelemetry |
| `azure-messaging` | service-bus, event-grid, notification-hub, signalr, web-pubsub |
| `azure-iot` | iot, digital-twin, sphere, rtos |
| `azure-integration` | logic-app, api-management, apim, api-center |
| `azure-general` | azure (catch-all for Azure repos not in sub-categories) |
| `m365` | office, teams, sharepoint, outlook, exchange, onedrive, graph, microsoft-365 |
| `copilot` | copilot, ai-assistant |
| `developer-tools` | vscode, visual-studio, dotnet, typescript, powershell, cli, nuget, blazor, maui |
| `power-platform` | power-app, power-automate, power-bi, dataverse |
| `windows` | windows, win32, winui, wsl, uwp, wpf, directx |
| `dynamics` | dynamics, d365, business-central |
| `gaming` | xbox, playfab, game |
| `general` | Catch-all for repos not matching any product area |

## Refreshing the catalog

To regenerate, run from the repo root (build tooling lives in `tools/sources-build/`, outside the shipped skill):

```bash
# Fetch org repos (repeat for each org)
gh repo list <ORG> --limit 5000 --json name,description,url,stargazerCount,forkCount,pushedAt,isArchived,primaryLanguage --no-archived > tools/sources-build/<ORG>.json

# Classify and generate org YAML
node tools/sources-build/classify-repos.mjs <ORG> tools/sources-build/<ORG>.json tools/sources-orgs/<ORG>.yml

# Build cross-reference files
node tools/sources-build/build-crossrefs.mjs doc-verifier/sources
```

## File structure

```
doc-verifier/sources/            ← shipped with the skill (per-category only)
├── README.md                    ← This file
├── routing-index.md             ← Product area → category YAML routing
├── categories-index.yml         ← Master index of all categories
├── azure-networking.yml         ← Cross-org: Azure Networking repos (73)
├── azure-ai.yml                 ← Cross-org: Azure AI repos (212)
├── azure-compute.yml            ← Cross-org: Azure Compute repos (231)
├── azure-data.yml               ← Cross-org: Azure Data repos (80)
├── azure-devops.yml             ← Cross-org: Azure DevOps repos (61)
├── azure-general.yml            ← Cross-org: Azure General repos (343)
├── azure-iac.yml                ← Cross-org: Azure IaC repos (148)
├── azure-integration.yml        ← Cross-org: Azure Integration repos (17)
├── azure-messaging.yml          ← Cross-org: Azure Messaging repos (12)
├── azure-monitor.yml            ← Cross-org: Azure Monitor repos (34)
├── azure-security.yml           ← Cross-org: Azure Security repos (50)
├── azure-storage.yml            ← Cross-org: Azure Storage repos (12)
├── copilot.yml                  ← Cross-org: Copilot repos (43)
├── developer-tools.yml          ← Cross-org: Developer Tools repos (215)
├── dynamics.yml                 ← Cross-org: Dynamics repos (55)
├── gaming.yml                   ← Cross-org: Gaming repos (13)
├── m365.yml                     ← Cross-org: Microsoft 365 repos (102)
├── power-platform.yml           ← Cross-org: Power Platform repos (45)
└── windows.yml                  ← Cross-org: Windows repos (99)

tools/ (repo root — NOT shipped with the skill)
├── sources-orgs/                ← Per-org monoliths: Azure.yml, microsoft.yml,
│                                   MicrosoftDocs.yml, MicrosoftCopilot.yml, general.yml
└── sources-build/               ← Build scripts and raw data
    ├── classify-repos.mjs       ← Classification script
    ├── build-crossrefs.mjs      ← Cross-reference builder
    └── *.json                   ← Raw gh CLI output
```

---

*Last generated: 2026-03-20*
