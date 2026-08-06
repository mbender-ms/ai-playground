#!/usr/bin/env bash
# contract-lookup.sh — Cache an API Contract source (Tier 1-C) for reuse across fleet tracks
#
# Fetches the ARM/Bicep templates schema page and (optionally) the Azure CLI `--help`
# for a given provider + property ONCE, so every track reconciling the same
# numeric/enum/default claim reads one cached lookup instead of re-fetching per track.
#
# Usage:
#   ./contract-lookup.sh <provider-path> <property> [cache-dir] [--cli-group "<az group>"]
#
# Examples:
#   ./contract-lookup.sh microsoft.network/loadbalancers idleTimeoutInMinutes ./cache/
#   ./contract-lookup.sh microsoft.network/loadbalancers idleTimeoutInMinutes ./cache/ --cli-group "network lb"
#
# Provider→CLI mapping is NOT mechanical (loadbalancers → `az network lb`), so the
# az-help capture uses a small static map for common providers and otherwise requires
# an explicit --cli-group. When neither applies, the az-help step is skipped and says so.
#
# Output (in cache-dir/):
#   contract_<provider-slug>_<property>_<runid>.json   metadata + resolved URLs
#   contract_<provider-slug>_<property>_<runid>.md     fetched templates schema page (markdown)
#   contract_<provider-slug>_<property>_<runid>.help   az <group> --help output (when resolvable)
#
# Exit codes:
#   0 — at least one artifact (schema page or az help) was captured
#   1 — usage error
#   2 — nothing could be captured; the agent should fetch the templates URL via
#       microsoft_docs_fetch instead (the exact call is printed)
#
# Notes:
#   - Read-only. Fetches public learn.microsoft.com pages and local `az --help` only.
#   - Never creates or mutates Azure resources (that is Live Validation, Tier 4b).

set -euo pipefail

PROVIDER_PATH="${1:?Usage: $0 <provider-path> <property> [cache-dir] [--cli-group \"<az group>\"]}"
PROPERTY="${2:?Missing <property>   e.g. idleTimeoutInMinutes}"
CACHE_DIR="./cache"
CLI_GROUP=""

shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --cli-group) CLI_GROUP="${2:?--cli-group needs a value}"; shift 2 ;;
    *) CACHE_DIR="$1"; shift ;;
  esac
done

RUNID=$(date +%Y%m%d-%H%M%S)
BUDGET=2000        # token budget for the in-agent microsoft_docs_fetch fallback
MAX_CHARS=8000     # mslearn fetch uses --max-chars (~4 chars/token)

mkdir -p "$CACHE_DIR"

PROVIDER_SLUG=$(echo "$PROVIDER_PATH" | tr '/' '-' | tr '[:upper:]' '[:lower:]')
BASENAME="contract_${PROVIDER_SLUG}_${PROPERTY}_${RUNID}"
TEMPLATES_URL="https://learn.microsoft.com/azure/templates/${PROVIDER_PATH}"

# Static map for common providers whose CLI group is not mechanical.
if [ -z "$CLI_GROUP" ]; then
  case "$(echo "$PROVIDER_PATH" | tr '[:upper:]' '[:lower:]')" in
    microsoft.network/loadbalancers)        CLI_GROUP="network lb" ;;
    microsoft.network/virtualnetworks)      CLI_GROUP="network vnet" ;;
    microsoft.network/publicipaddresses)    CLI_GROUP="network public-ip" ;;
    microsoft.network/networksecuritygroups) CLI_GROUP="network nsg" ;;
    microsoft.network/applicationgateways)  CLI_GROUP="network application-gateway" ;;
    microsoft.network/azurefirewalls)       CLI_GROUP="network firewall" ;;
    microsoft.compute/virtualmachines)      CLI_GROUP="vm" ;;
    microsoft.compute/virtualmachinescalesets) CLI_GROUP="vmss" ;;
    microsoft.storage/storageaccounts)      CLI_GROUP="storage account" ;;
    microsoft.keyvault/vaults)              CLI_GROUP="keyvault" ;;
    *) CLI_GROUP="" ;;
  esac
fi

echo "=== API Contract Lookup (Tier 1-C) ==="
echo "Provider:  $PROVIDER_PATH"
echo "Property:  $PROPERTY"
echo "Templates: $TEMPLATES_URL"
echo "CLI group: ${CLI_GROUP:-<unresolved — pass --cli-group to enable az-help capture>}"
echo "Cache:     $CACHE_DIR"
echo ""

# 1. Fetch the ARM/Bicep templates schema page as markdown via the Learn CLI.
#    (No curl fallback: learn.microsoft.com serves a JS shell to plain HTTP clients,
#    which is unusable — an honest failure beats a poisoned cache.)
SCHEMA_FILE="${CACHE_DIR}/${BASENAME}.md"
# @microsoft/learn-cli v0.1.0 installs the binary `mslearn` (fetch flag: --max-chars).
LEARN_CMD=""
if command -v mslearn >/dev/null 2>&1; then
  LEARN_CMD="mslearn"
elif command -v npx >/dev/null 2>&1 && npx -y @microsoft/learn-cli --help >/dev/null 2>&1; then
  LEARN_CMD="npx -y @microsoft/learn-cli"
fi
if [ -n "$LEARN_CMD" ]; then
  $LEARN_CMD fetch "$TEMPLATES_URL" --max-chars "$MAX_CHARS" >"$SCHEMA_FILE" 2>/dev/null || true
fi
if [ -s "$SCHEMA_FILE" ] && grep -Fq \
  "The provided URL points to a page that could not be retrieved" "$SCHEMA_FILE"; then
  rm -f "$SCHEMA_FILE"
fi
[ -s "$SCHEMA_FILE" ] || rm -f "$SCHEMA_FILE"

# 2. Capture the Azure CLI parameter reference if az and a CLI group are available.
HELP_FILE="${CACHE_DIR}/${BASENAME}.help"
if command -v az >/dev/null 2>&1 && [ -n "$CLI_GROUP" ]; then
  # shellcheck disable=SC2086
  az $CLI_GROUP --help >"$HELP_FILE" 2>/dev/null || true
fi
[ -s "$HELP_FILE" ] || rm -f "$HELP_FILE"

# 3. Honest outcome: never leave a metadata record pointing at empty artifacts.
if [ ! -s "${SCHEMA_FILE:-/nonexistent}" ] && [ ! -s "${HELP_FILE:-/nonexistent}" ]; then
  echo "NOTHING CAPTURED:"
  [ -z "$LEARN_CMD" ] && echo "  - Learn CLI not available (install @microsoft/learn-cli or use in-agent fetch)"
  [ -z "$CLI_GROUP" ] && echo "  - CLI group unresolved (pass --cli-group \"<az group>\")"
  command -v az >/dev/null 2>&1 || echo "  - Azure CLI (az) not installed"
  echo ""
  echo "Agent fallback — fetch the contract in-agent instead:"
  echo "  microsoft_docs_fetch url=\"$TEMPLATES_URL\" maxTokenBudget=$BUDGET"
  echo "and record contract_source=$TEMPLATES_URL"
  exit 2
fi

# 4. Write the metadata record for tracks to locate the cached artifacts.
META_FILE="${CACHE_DIR}/${BASENAME}.json"
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg provider "$PROVIDER_PATH" --arg property "$PROPERTY" --arg runid "$RUNID" \
    --arg url "$TEMPLATES_URL" \
    --arg schema "$([ -s "$SCHEMA_FILE" ] && echo "$SCHEMA_FILE" || echo "")" \
    --arg help "$([ -s "$HELP_FILE" ] && echo "$HELP_FILE" || echo "")" \
    '{provider_path: $provider, property: $property, run_id: $runid,
      contract_source: $url, tier: "1-C",
      schema_file: (if $schema == "" then null else $schema end),
      cli_help_file: (if $help == "" then null else $help end)}' > "$META_FILE"
else
  cat >"$META_FILE" <<EOF
{
  "provider_path": "${PROVIDER_PATH}",
  "property": "${PROPERTY}",
  "run_id": "${RUNID}",
  "contract_source": "${TEMPLATES_URL}",
  "tier": "1-C",
  "schema_file": "$([ -s "$SCHEMA_FILE" ] && echo "$SCHEMA_FILE")",
  "cli_help_file": "$([ -s "$HELP_FILE" ] && echo "$HELP_FILE")"
}
EOF
fi

echo "Wrote:"
echo "  $META_FILE"
[ -s "$SCHEMA_FILE" ] && echo "  $SCHEMA_FILE" || echo "  (schema page not cached — fetch $TEMPLATES_URL via microsoft_docs_fetch in-agent)"
[ -s "$HELP_FILE" ] && echo "  $HELP_FILE" || echo "  (az --help not captured)"
echo ""
echo "Tracks read contract_value from the cached artifacts and record contract_source=${TEMPLATES_URL}"
