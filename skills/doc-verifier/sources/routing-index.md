# Sources Routing Index

Lightweight lookup table for the sources catalog. Use this to identify which category YAML to load for Tier 2 source verification — **load the full YAML only when you need repo-level detail**.

## Category index

| Category | File | Repos | Key services |
|----------|------|-------|-------------|
| Azure Networking | azure-networking.yml | 73 | Load Balancer, App Gateway, VPN Gateway, ExpressRoute, Firewall, Front Door, DNS, Bastion, DDoS, NAT Gateway, Virtual Network, AVNM, NSP, WAF, Traffic Manager, Private Link |
| Azure Compute | azure-compute.yml | 85+ | Virtual Machines, AKS, Container Apps, App Service, Functions, Batch, Service Fabric |
| Azure Storage | azure-storage.yml | 40+ | Blob, Files, Queue, Table, Data Lake, Managed Disks |
| Azure Security | azure-security.yml | 60+ | Defender, Sentinel, Key Vault, Entra ID, Purview, Intune |
| Azure Data | azure-data.yml | 70+ | Cosmos DB, SQL, PostgreSQL, MySQL, Redis, Data Factory, Synapse |
| Azure AI/ML | azure-ai.yml | 50+ | OpenAI Service, Cognitive Services, ML Studio, Bot Service |
| Azure DevOps | azure-devops.yml | 30+ | Pipelines, Repos, Boards, Artifacts, Test Plans |
| Azure Integration | azure-integration.yml | 25+ | Logic Apps, API Management, Event Grid, Service Bus, Event Hubs |
| Azure Monitor | azure-monitor.yml | 20+ | Monitor, Log Analytics, App Insights, Workbooks |
| Azure Identity | azure-security.yml | 35+ | Entra ID, B2C, Managed Identity, Conditional Access |
| Developer Tools | developer-tools.yml | 45+ | Visual Studio, VS Code, .NET, Azure CLI, PowerShell, SDKs |
| M365 | m365.yml | 30+ | Teams, SharePoint, Exchange, OneDrive, Outlook |
| Power Platform | power-platform.yml | 20+ | Power Apps, Power Automate, Power BI, Dataverse |

## Per-org files

Per-org monoliths (`Azure.yml`, `MicrosoftDocs.yml`, `microsoft.yml`, `MicrosoftCopilot.yml`, `general.yml`) live at the repo root under `tools/sources-orgs/` and are **not shipped with the installed skill** — fact-checking only needs the category files above. Use the repo checkout when org-wide browsing is genuinely required.

## Master index

See categories-index.yml for the complete category list with exact repo counts.

## Usage

1. Identify the product area from the article's ms.service or content.
2. Find the matching category in the table above.
3. Load the full YAML file only when you need repo-level detail.
4. For most fact-checking, category is sufficient to scope microsoft_docs_search.
