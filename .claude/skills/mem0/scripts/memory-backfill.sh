#!/usr/bin/env bash
# Backfill mem0 from an experiment's canonical RESULTS.md table. Every row
# becomes a one-liner ([CRASH] when the verdict column starts with
# "crash", [VERDICT] otherwise), deduped server-side by exact sha256 of
# the text via POST /memories/list (never adds on an uncertain dedupe
# check — a failed check is a skip, not an add).
#
# Usage: memory-backfill.sh [-n] <experiment-dir>
#   -n  dry run: print the one-liners instead of posting them (no network)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

DRY_RUN=0

usage() {
  echo "usage: memory-backfill.sh [-n] <experiment-dir>" >&2
  exit 2
}

while getopts "n" opt; do
  case "$opt" in
    n) DRY_RUN=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || usage
EXP_DIR="${1%/}"
[ -d "$EXP_DIR" ] || { echo "mem0: not a directory: $EXP_DIR" >&2; exit 2; }
EXP_NAME="$(basename "$EXP_DIR")"
ENTITY="experiment:${EXP_NAME}"
RESULTS_FILE="$EXP_DIR/RESULTS.md"

[ "$DRY_RUN" -eq 1 ] || require_box_host

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

emit() {
  local text="$1" sha add_body hit
  sha="$(sha256_of "$text")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' "$text"
    return
  fi

  mem0_list "$(jq -nc --arg uid "$MEM0_USER_ID" --arg sha "$sha" '{user_id: $uid, filters: {sha256: $sha}, limit: 1}')"
  if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
    echo "mem0: dedupe check failed (status ${CURL_STATUS}); skipping without adding: $text" >&2
    return
  fi
  hit="$(jq -r '(if type == "array" then . else (.results // []) end) | length' <<<"$CURL_BODY" 2>/dev/null)"
  if [ "${hit:-0}" -gt 0 ]; then
    return
  fi

  add_body="$(jq -nc --arg text "$text" --arg entity "$ENTITY" --arg sha "$sha" --arg uid "$MEM0_USER_ID" \
    '{messages: [{role: "user", content: $text}], user_id: $uid, metadata: {entity: $entity, sha256: $sha}, infer: false}')"
  mem0_add "$add_body"
  if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
    echo "mem0: failed to add memory (status ${CURL_STATUS}): $text" >&2
  fi
}

parse_results() {
  [ -f "$RESULTS_FILE" ] || return 0
  local line content cols n benchid mutation verdict tag
  while IFS= read -r line; do
    case "$line" in
      '|'*'|') ;;
      *) continue ;;
    esac
    content="${line#|}"
    content="${content%|}"
    IFS='|' read -r -a cols <<<"$content"
    n=${#cols[@]}
    [ "$n" -lt 2 ] && continue
    benchid="$(trim "${cols[0]}")"
    [ "$benchid" = "benchId" ] && continue
    [ -z "$benchid" ] && continue
    case "$benchid" in
      -*|:*) continue ;; # markdown separator row (---, :---:, ...)
    esac
    mutation="$(trim "${cols[2]:-}")"
    verdict="$(trim "${cols[$((n - 1))]:-}")"
    [ -z "$verdict" ] && continue
    tag="VERDICT"
    case "$(lower "$verdict")" in
      crash*) tag="CRASH" ;;
    esac
    emit "[$tag] ${benchid}: ${mutation} — ${verdict}"
  done <"$RESULTS_FILE"
}

parse_results
