#!/usr/bin/env bash
# batch-presearch.sh — Pre-search claims against Microsoft Learn before agent verification
#
# Reads a claim manifest (JSON sidecar preferred, markdown fallback), builds search
# queries per service area, and caches results as JSON so agents read the cache
# instead of making live MCP calls for every claim.
#
# Usage:
#   ./batch-presearch.sh claims_manifest.json [output_dir]     # preferred: JSON sidecar
#   ./batch-presearch.sh claims_manifest.md   [output_dir]     # fallback: markdown table
#
# Prerequisites:
#   jq (required)
#   @microsoft/learn-cli (optional — without it the script degrades to emitting
#   query lists that the agent runs via microsoft_docs_search instead)
#
# Markdown input: a claim manifest from claim-manifest.prompt.md. The parser is
# header-aware — it locates the "Claim text" column by name, so both the current
# 6-column layout (with topic_key) and the older 5-column layout work:
#   | ID | Line | Type | topic_key | Claim text | Include file |
# Section headers are matched case-insensitively:
#   ### Azure Load Balancer (8 claims)
#
# Output: one JSON file per service area in output_dir/
#   search_<area-slug>_<runid>.json        (when the Learn CLI is available)
#   queries_<area-slug>_<runid>.txt        (degraded mode — query list for the agent)

set -euo pipefail

MANIFEST="${1:?Usage: $0 <claims_manifest.(json|md)> [output_dir]}"
OUTPUT_DIR="${2:-./presearch_cache}"
RUNID=$(date +%Y%m%d-%H%M%S)
MAX_QUERIES_PER_AREA=20

[ -f "$MANIFEST" ] || { echo "ERROR: manifest not found: $MANIFEST"; exit 1; }

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# jq is mandatory only for JSON manifests; JSON cache output also needs it.
if [[ "$MANIFEST" == *.json ]] && [ "$HAVE_JQ" -eq 0 ]; then
  echo "ERROR: jq is required to read a JSON manifest. Install jq or pass the markdown manifest."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Learn CLI detection (shared invocation with contract-lookup.sh) ---------
# @microsoft/learn-cli v0.1.0 installs the binary `mslearn` (commands: search,
# fetch, code-search, doctor; flags: --json, --max-chars).
LEARN_CMD=""
if command -v mslearn >/dev/null 2>&1; then
  LEARN_CMD="mslearn"
elif command -v npx >/dev/null 2>&1 && npx -y @microsoft/learn-cli --help >/dev/null 2>&1; then
  LEARN_CMD="npx -y @microsoft/learn-cli"
fi
# Without jq we cannot safely assemble the JSON cache — fall back to query lists.
if [ -n "$LEARN_CMD" ] && [ "$HAVE_JQ" -eq 0 ]; then
  echo "NOTE: jq unavailable — degrading to query lists (no JSON cache assembly)."
  LEARN_CMD=""
fi

echo "=== Microsoft Learn Pre-Search ==="
echo "Manifest: $MANIFEST"
echo "Output:   $OUTPUT_DIR"
echo "Run ID:   $RUNID"
[ -z "$LEARN_CMD" ] && echo "Mode:     DEGRADED — Learn CLI unavailable; emitting query lists only"
echo ""

# --- Service-area discovery ---------------------------------------------------
list_areas() {
  if [[ "$MANIFEST" == *.json ]]; then
    jq -r '[.[].service_area] | unique | .[]' "$MANIFEST"
  else
    # H3 headers like: ### Azure Load Balancer (8 claims) — skip link sections
    grep -E '^### ' "$MANIFEST" \
      | sed -E 's/^### //; s/ \([0-9]+ (claims|links)\)$//' \
      | grep -viE '^links?$' \
      | sort -u
  fi
}

# --- Claim extraction (header-aware, case-insensitive section match) ----------
extract_claims_for_area() {
  local area="$1"
  if [[ "$MANIFEST" == *.json ]]; then
    jq -r --arg area "$area" '.[] | select(.service_area == $area) | .text' "$MANIFEST"
  else
    awk -v header="$area" '
      BEGIN { found = 0; col = 0 }
      {
        low = tolower($0)
        if (index(low, "### " tolower(header)) == 1) { found = 1; col = 0; next }
        if (found && low ~ /^### /) { found = 0 }
        if (!found || $0 !~ /^\|/) next
        if ($0 ~ /^\|[-: |]+\|$/) next                     # separator row
        n = split($0, cols, "|")
        if (tolower($0) ~ /claim text/) {                   # header row → locate column
          for (i = 1; i <= n; i++) {
            c = cols[i]; gsub(/^[ \t]+|[ \t]+$/, "", c)
            if (tolower(c) == "claim text") col = i
          }
          next
        }
        if (col == 0 || n < col) next
        c = cols[col]
        gsub(/^[ \t]+|[ \t]+$/, "", c)
        gsub(/^"|"$/, "", c)
        if (c != "" && c != "\342\200\224") print c         # skip empty and em-dash
      }
    ' "$MANIFEST"
  fi
}

# --- Query building: strip filler verbs, dedupe, cap ---------------------------
build_search_queries() {
  sed -E 's/["""]//g; s/\b(supports?|enables?|allows?|requires?|provides?|configures?)\b//Ig' \
    | tr -s ' ' | sed -E 's/^ +| +$//g' \
    | awk 'length($0) > 0 { print substr($0, 1, 80) }' \
    | sort -u | head -n "$MAX_QUERIES_PER_AREA"
}

slugify() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+|-+$//g'; }

TOTAL_QUERIES=0
AREAS_PROCESSED=0

while IFS= read -r area; do
  [ -z "$area" ] && continue
  slug=$(slugify "$area")
  echo "--- $area ---"

  queries=$(extract_claims_for_area "$area" | build_search_queries)
  if [ -z "$queries" ]; then
    echo "  No claims found for this area, skipping."
    echo ""
    continue
  fi
  AREAS_PROCESSED=$((AREAS_PROCESSED + 1))

  if [ -z "$LEARN_CMD" ]; then
    # Degraded mode: emit the query list for the agent to run via microsoft_docs_search
    QFILE="$OUTPUT_DIR/queries_${slug}_${RUNID}.txt"
    printf '%s\n' "$queries" > "$QFILE"
    qcount=$(wc -l < "$QFILE" | tr -d ' ')
    TOTAL_QUERIES=$((TOTAL_QUERIES + qcount))
    echo "  Saved query list: $QFILE ($qcount queries)"
    echo ""
    continue
  fi

  OUTPUT_FILE="$OUTPUT_DIR/search_${slug}_${RUNID}.json"
  ENTRIES=$(mktemp)
  qcount=0

  while IFS= read -r query; do
    [ -z "$query" ] && continue
    echo "  Querying: $query"
    result=$($LEARN_CMD search "$query" --json 2>/dev/null || true)
    if ! jq -e . >/dev/null 2>&1 <<<"$result"; then
      jq -n --arg q "$query" '{query: $q, response: {error: "search failed"}}' >> "$ENTRIES"
    else
      jq -n --arg q "$query" --argjson r "$result" '{query: $q, response: $r}' >> "$ENTRIES"
    fi
    qcount=$((qcount + 1))
    TOTAL_QUERIES=$((TOTAL_QUERIES + 1))
    sleep 0.5   # be polite
  done <<< "$queries"

  jq -s --arg area "$area" --arg runid "$RUNID" \
    '{service_area: $area, run_id: $runid, results: .}' "$ENTRIES" > "$OUTPUT_FILE"
  rm -f "$ENTRIES"

  jq -e . "$OUTPUT_FILE" >/dev/null || { echo "ERROR: invalid JSON written to $OUTPUT_FILE"; exit 1; }
  echo "  Saved: $OUTPUT_FILE ($qcount queries)"
  echo ""
done < <(list_areas)

if [ "$AREAS_PROCESSED" -eq 0 ]; then
  echo "ERROR: no service-area sections with claims found in $MANIFEST."
  echo "Expected H3 headers like '### Azure Load Balancer (8 claims)' with a table containing a 'Claim text' column,"
  echo "or a JSON sidecar array of claim objects with service_area/text fields."
  exit 1
fi

echo "=== Pre-search complete ==="
echo "Areas:   $AREAS_PROCESSED"
echo "Queries: $TOTAL_QUERIES"
echo "Cache:   $OUTPUT_DIR"
if [ -z "$LEARN_CMD" ]; then
  echo ""
  echo "Learn CLI unavailable — the agent should run each query in queries_*_${RUNID}.txt"
  echo "via microsoft_docs_search and treat the results as the pre-search cache."
else
  echo ""
  echo "Next: run fleet-batch-verify. Agents read these cache files for initial search"
  echo "hits and use microsoft_docs_fetch only for pages that need full content."
fi
