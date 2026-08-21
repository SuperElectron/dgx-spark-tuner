#!/usr/bin/env bash
# Backfill mem0 from an experiment's canonical files: RESULTS.md table rows
# and journal.md "## Round N outcome ... — keep/revert/crash" headings.
# Dedupes by exact memory text (searches before adding).
#
# Usage: memory-backfill.sh [-n] <experiment-dir>
#   -n  dry run: print the one-liners instead of posting them

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=./_common.sh
source ./_common.sh

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
JOURNAL_FILE="$EXP_DIR/journal.md"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

already_exists() {
  local text="$1" body resp hit
  body="$(jq -nc --arg q "$text" --arg uid "$MEM0_USER_ID" '{query: $q, filters: {user_id: $uid}, top_k: 10}')"
  mem0_search "$body"
  resp="$CURL_BODY"
  [[ "$CURL_STATUS" =~ ^2 ]] || return 1
  hit="$(jq -r --arg t "$text" '
    (if type == "array" then . else (.results // []) end)
    | map(select(.memory == $t)) | length
  ' <<<"$resp" 2>/dev/null)"
  [ "${hit:-0}" -gt 0 ]
}

emit() {
  local text="$1" body
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' "$text"
    return
  fi
  if already_exists "$text"; then
    return
  fi
  body="$(jq -nc --arg text "$text" --arg entity "$ENTITY" --arg uid "$MEM0_USER_ID" \
    '{messages: [{role: "user", content: $text}], user_id: $uid, metadata: {entity: $entity}, infer: false}')"
  mem0_add "$body" >/dev/null
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
    case "$(lower "$benchid") $(lower "$verdict")" in
      *crash*) tag="CRASH" ;;
    esac
    emit "[$tag] ${benchid}: ${mutation} — ${verdict}"
  done <"$RESULTS_FILE"
}

parse_journal() {
  [ -f "$JOURNAL_FILE" ] || return 0
  local line last last_lc tag heading
  while IFS= read -r line; do
    case "$line" in
      '## Round '*) ;;
      *) continue ;;
    esac
    last="$(trim "${line##*" — "}")"
    last_lc="$(lower "$last")"
    case "$last_lc" in
      keep|revert) tag="VERDICT" ;;
      crash) tag="CRASH" ;;
      *) continue ;;
    esac
    heading="$(trim "${line#"## "}")"
    emit "[$tag] ${heading}"
  done <"$JOURNAL_FILE"
}

parse_results
parse_journal
