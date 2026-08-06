#!/usr/bin/env bash
# link-check.sh — Deterministic link checker for documentation articles
#
# Pre-computes 🔗 broken-link findings so agents never spend fetch budget on them.
# Extracts markdown link targets from the given articles, checks each one, and
# emits a JSON report the agent copies into its findings.
#
# Usage:
#   ./link-check.sh article.md [more.md ...] [-o links_output.json]
#
# Checks performed:
#   http(s) URLs      → curl HEAD (falls back to ranged GET when HEAD is rejected),
#                       follows redirects, retries 429/5xx twice with backoff
#   relative paths    → filesystem existence, resolved against the article's directory
#   #anchor fragments → NOT resolvable without rendered HTML; reported as
#                       "unchecked-anchor" for the agent to verify only if it matters
#
# Verdicts: ok | broken | redirected | unchecked-anchor
#
# Output: JSON array of {file, line, target, kind, status_code, verdict}
# Requires: curl. Uses jq for output when available; emits escaped JSON otherwise.

set -uo pipefail

OUTPUT=""
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUTPUT="${2:?-o needs a path}"; shift 2 ;;
    *)  FILES+=("$1"); shift ;;
  esac
done
[ ${#FILES[@]} -gt 0 ] || { echo "Usage: $0 <article.md> [more.md ...] [-o output.json]"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required."; exit 1; }

RUNID=$(date +%Y%m%d-%H%M%S)
[ -n "$OUTPUT" ] || OUTPUT="links_${RUNID}.json"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

check_url() {
  # echoes "<final_http_code> <num_redirects>"
  local url="$1" attempt code redirects
  for attempt in 1 2 3; do
    read -r code redirects <<<"$(curl -sI -L -o /dev/null --max-time 15 \
      -w '%{http_code} %{num_redirects}' "$url" 2>/dev/null || echo '000 0')"
    # Some servers reject HEAD (403/405) — retry once with a 1-byte ranged GET
    if [ "$code" = "405" ] || [ "$code" = "403" ]; then
      read -r code redirects <<<"$(curl -s -L -o /dev/null -r 0-0 --max-time 15 \
        -w '%{http_code} %{num_redirects}' "$url" 2>/dev/null || echo '000 0')"
    fi
    case "$code" in
      429|5??|000) sleep $((attempt * 2)) ;;
      *) break ;;
    esac
  done
  echo "$code $redirects"
}

TMP_ENTRIES=$(mktemp)
TOTAL=0
BROKEN=0

for FILE in "${FILES[@]}"; do
  [ -f "$FILE" ] || { echo "WARN: not found, skipping: $FILE" >&2; continue; }
  DIR=$(dirname "$FILE")

  # Extract "line<TAB>target" for markdown link/image targets and bare autolink URLs.
  while IFS=$'\t' read -r line target; do
    [ -z "$target" ] && continue
    TOTAL=$((TOTAL + 1))
    kind="" code="" verdict=""

    if [[ "$target" =~ ^https?:// ]]; then
      kind="url"
      base="${target%%#*}"
      read -r code redirects <<<"$(check_url "$base")"
      case "$code" in
        2??) verdict="ok"; [ "${redirects:-0}" -gt 0 ] && verdict="redirected" ;;
        *)   verdict="broken" ;;
      esac
      # A live page with a #fragment: the anchor itself is unverifiable here.
      if [ "$verdict" != "broken" ] && [[ "$target" == *"#"* ]]; then
        verdict="unchecked-anchor"
      fi
    elif [[ "$target" =~ ^# ]]; then
      kind="in-file-anchor"; code=""; verdict="unchecked-anchor"
    elif [[ "$target" =~ ^(mailto:|xref:) ]]; then
      kind="special"; code=""; verdict="unchecked-anchor"
    else
      kind="relative"
      path="${target%%#*}"; path="${path%%\?*}"
      if [ -e "$DIR/$path" ] || [ -e "$path" ]; then
        verdict="ok"
        [[ "$target" == *"#"* ]] && verdict="unchecked-anchor"
      else
        verdict="broken"
      fi
      code=""
    fi

    [ "$verdict" = "broken" ] && BROKEN=$((BROKEN + 1))
    printf '{"file":"%s","line":%s,"target":"%s","kind":"%s","status_code":"%s","verdict":"%s"}\n' \
      "$(json_escape "$FILE")" "${line:-0}" "$(json_escape "$target")" "$kind" "${code:-}" "$verdict" \
      >> "$TMP_ENTRIES"
  done < <(
    {
      # [text](target) and ![alt](target) — capture target up to closing paren
      grep -onE '\]\(([^)[:space:]]+)[^)]*\)' "$FILE" | sed -E 's/^([0-9]+):\]\(([^)[:space:]]+).*$/\1\t\2/'
      # bare URLs in <...> autolinks or plain text
      grep -onE '<https?://[^>]+>' "$FILE" | sed -E 's/^([0-9]+):<([^>]+)>$/\1\t\2/'
    } | sort -u
  )
done

if command -v jq >/dev/null 2>&1; then
  jq -s '.' "$TMP_ENTRIES" > "$OUTPUT"
else
  { echo '['; paste -sd ',' "$TMP_ENTRIES" 2>/dev/null || sed '$!s/$/,/' "$TMP_ENTRIES"; echo ']'; } > "$OUTPUT"
fi
rm -f "$TMP_ENTRIES"

echo "Checked $TOTAL link(s): $BROKEN broken → $OUTPUT"
echo "Agent: copy every \"broken\" entry into the findings as a 🔗 finding;"
echo "verify \"unchecked-anchor\" targets only when the finding matters."
