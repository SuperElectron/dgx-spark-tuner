#!/usr/bin/env bash
# Derive mem0's [VERDICT]/[CRASH] entries for one experiment from its
# canonical RESULTS.md table. Every emitted line is a DATED OBSERVATION
# carrying its own provenance (date, benchId, sampling, configuration,
# comparison basis) because recall.sh returns only the memory text —
# created_at and metadata never reach the caller.
#
# Two table schemas are recognised, detected from the header row:
#   per-RUN   benchId | date | mutation | tg t/s | tg σ | pp t/s | pp σ | ttfr ms | verdict
#   per-CELL  benchId | date | Cell | Configuration | Ours | Runs | Board top | [Like-for-like] | Margin/Verdict/Note
#
# Default mode is add-only, deduped server-side by exact sha256 via
# POST /memories/list (a failed dedupe check is a SKIP, never an add).
# --reconcile additionally deletes index entries this table no longer
# produces, so the index can actually converge on its source.
#
# Usage: memory-backfill.sh [-n] [--reconcile] <experiment-dir>
#   -n           dry run: print instead of posting (no network writes)
#   --reconcile  also delete stale [VERDICT]/[CRASH] entries for this entity

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

DRY_RUN=0
RECONCILE=0
LIST_LIMIT=1000

usage() {
  echo "usage: memory-backfill.sh [-n] [--reconcile] <experiment-dir>" >&2
  exit 2
}

ARGS=()
for a in "$@"; do
  case "$a" in
    --reconcile) RECONCILE=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

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

# Reconcile reads the index even on a dry run (to show intended deletes),
# so it needs the box either way; a plain dry run stays fully offline.
if [ "$DRY_RUN" -eq 0 ] || [ "$RECONCILE" -eq 1 ]; then
  require_box_host
fi

EXPECTED="$(mktemp)"
INDEXED="$(mktemp)"
trap 'rm -f "$EXPECTED" "$INDEXED"' EXIT INT TERM

# --- table parsing -----------------------------------------------------------

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Cell text as it should read in a memory: markdown emphasis stripped,
# placeholder dashes treated as absent.
clean() {
  local s
  s="$(trim "$1")"
  s="${s//\*/}"
  s="${s//\`/}"
  s="${s//⚠/}"
  s="$(trim "$s")"
  case "$s" in
    "—"|"-"|"–"|"n/a"|"N/A") s="" ;;
  esac
  printf '%s' "$s"
}

HDR=()
COLS=()
SCHEMA=""
SECTION=""

col() {
  local want="$1" i
  for i in "${!HDR[@]}"; do
    if [ "${HDR[$i]}" = "$want" ]; then
      clean "${COLS[$i]:-}"
      return
    fi
  done
}

# The trailing column is the row's verdict/note whatever the table calls it
# ("Note", "Verdict", "Why it is not scored"); only fall back to it when it
# is not one of the fields already consumed above.
last_col() {
  local i=$(( ${#HDR[@]} - 1 ))
  case "${HDR[$i]:-}" in
    benchid|date|cell|configuration|ours|runs|'board top'|margin|'like-for-like') return ;;
  esac
  clean "${COLS[$i]:-}"
}

# Board incumbents are quoted from a dated arena scrape named in the file's
# own preamble; without one the provenance clause is omitted, not guessed.
board_scrape_date() {
  grep -o -E '[0-9]{4}-[0-9]{2}-[0-9]{2} scrape' "$RESULTS_FILE" 2>/dev/null \
    | head -1 | cut -d' ' -f1
}

# per-RUN row: marker, date, benchId, mutation, measurements, verdict.
line_from_run_row() {
  local bench="$1" date="$2" text tag
  local mutation tg tgs pp pps ttfr verdict
  mutation="$(col mutation)"
  tg="$(col 'tg t/s')"
  tgs="$(col 'tg σ')"
  pp="$(col 'pp t/s')"
  pps="$(col 'pp σ')"
  ttfr="$(col 'ttfr ms')"
  verdict="$(col verdict)"
  [ -n "$verdict" ] || return 1

  tag="VERDICT"
  case "$(lower "$verdict")" in crash*) tag="CRASH" ;; esac

  text="[$tag]"
  [ -n "$date" ] && text="$text $date"
  text="$text ${bench}:"
  [ -n "$mutation" ] && text="$text $mutation"
  [ -n "$tg" ] && text="$text — tg $tg"
  [ -n "$tg" ] && [ -n "$tgs" ] && text="$text (σ $tgs)"
  [ -n "$pp" ] && text="$text pp $pp"
  [ -n "$pp" ] && [ -n "$pps" ] && text="$text (σ $pps)"
  [ -n "$ttfr" ] && text="$text ttfr $ttfr ms"
  printf '%s — %s' "$text" "$verdict"
}

# per-CELL row: marker, date, benchId, cell, sampling, configuration,
# then the verdict with the board figure it is measured against.
line_from_cell_row() {
  local bench="$1" date="$2" text tag basis
  local cell config ours runs board margin l4l note
  cell="$(col cell)"
  config="$(col configuration)"
  ours="$(col ours)"
  runs="$(col runs)"
  board="$(col 'board top')"
  margin="$(col margin)"
  l4l="$(col 'like-for-like')"
  note="$(col note)"
  [ -n "$note" ] || note="$(col verdict)"
  [ -n "$note" ] || note="$(last_col)"
  [ -n "$ours" ] || [ -n "$note" ] || return 1

  tag="VERDICT"
  case "$(lower "$note")" in crash*) tag="CRASH" ;; esac

  text="[$tag]"
  [ -n "$date" ] && text="$text $date"
  text="$text ${bench}:"
  [ -n "$cell" ] && text="$text $cell"
  [ -n "$runs" ] && text="$text runs=$runs"
  [ -n "$ours" ] && text="$text median $ours"
  [ -n "$config" ] && text="$text at $config"

  # The WIN/LOSS label is the standings section the row sits in, and only
  # applies to a row that carries a figure.
  basis=""
  if [ -n "$ours" ]; then
    case "$SECTION" in
      *WON*) basis="WIN" ;;
      *LOST*) basis="LOSS" ;;
    esac
  fi
  [ -n "$margin" ] && basis="$(trim "$basis $margin")"
  if [ -n "$board" ]; then
    basis="$(trim "$basis over board $board")"
    [ -n "$BOARD_SCRAPE" ] && basis="$basis (arena scrape $BOARD_SCRAPE)"
  fi
  [ -n "$l4l" ] && basis="$(trim "$basis, like-for-like $l4l")"
  if [ -n "$note" ]; then
    [ -n "$basis" ] && basis="$basis — "
    basis="${basis}${note}"
  fi
  [ -n "$basis" ] || return 1
  printf '%s — %s' "$text" "$basis"
}

parse_results() {
  [ -f "$RESULTS_FILE" ] || return 0
  local line content first text sha i
  while IFS= read -r line; do
    case "$line" in
      '## '*) SECTION="${line#\#\# }"; HDR=(); SCHEMA="" ; continue ;;
      '|'*'|') ;;
      *) continue ;;
    esac
    content="${line#|}"
    content="${content%|}"
    IFS='|' read -r -a COLS <<<"$content"
    [ "${#COLS[@]}" -lt 2 ] && continue
    first="$(lower "$(clean "${COLS[0]}")")"

    if [ "$first" = "benchid" ]; then
      HDR=()
      for i in "${!COLS[@]}"; do
        HDR[i]="$(lower "$(clean "${COLS[$i]}")")"
      done
      SCHEMA="run"
      for i in "${!HDR[@]}"; do
        case "${HDR[$i]}" in cell|configuration) SCHEMA="cell" ;; esac
      done
      continue
    fi

    [ -n "$SCHEMA" ] || continue
    case "$first" in
      bench*) ;;
      *) continue ;;
    esac

    if [ "$SCHEMA" = "cell" ]; then
      text="$(line_from_cell_row "$(clean "${COLS[0]}")" "$(col date)")" || continue
    else
      text="$(line_from_run_row "$(clean "${COLS[0]}")" "$(col date)")" || continue
    fi
    sha="$(sha256_of "$text")"
    printf '%s\t%s\n' "$sha" "$text" >>"$EXPECTED"
  done <"$RESULTS_FILE"
}

# --- index writes ------------------------------------------------------------

add_memory() {
  local text="$1" sha="$2" add_body
  add_body="$(jq -nc --arg text "$text" --arg entity "$ENTITY" --arg sha "$sha" --arg uid "$MEM0_USER_ID" \
    '{messages: [{role: "user", content: $text}], user_id: $uid, metadata: {entity: $entity, sha256: $sha}, infer: false}')"
  mem0_add "$add_body"
  if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
    echo "mem0: failed to add memory (status ${CURL_STATUS}): $text" >&2
  fi
}

# Add-only path: one exact-match dedupe check per row. An uncertain check
# is a skip — this script would rather leave a gap than risk a duplicate.
emit() {
  local text="$1" sha="$2" hit

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
  [ "${hit:-0}" -gt 0 ] && return

  add_memory "$text" "$sha"
}

# Reconcile: regenerate the expected set, then add what is missing and
# delete what the table no longer produces. Only [VERDICT]/[CRASH] entries
# under this experiment's entity are ever deletion candidates —
# [LESSON]/[ENV]/[IDEA]/[COST] are hand-written observations that RESULTS.md
# cannot regenerate, so deleting them would destroy real findings.
reconcile() {
  local id sha text marker adds=0 dels=0

  mem0_list "$(jq -nc --arg uid "$MEM0_USER_ID" --arg e "$ENTITY" --argjson n "$LIST_LIMIT" \
    '{user_id: $uid, filters: {entity: $e}, limit: $n}')"
  if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
    echo "mem0: reconcile aborted — index listing failed (status ${CURL_STATUS}); nothing added or deleted" >&2
    exit 1
  fi

  jq -r '(if type == "array" then . else (.results // []) end)
         | .[] | [(.id // ""), (.metadata.sha256 // ""), ((.memory // "") | gsub("[\t\n]"; " "))] | @tsv' \
    <<<"$CURL_BODY" >"$INDEXED" 2>/dev/null

  while IFS=$'\t' read -r id sha text; do
    [ -n "$id" ] || continue
    [ -n "$sha" ] || sha="$(sha256_of "$text")"
    marker="${text%%]*}]"
    case "$marker" in
      '[VERDICT]'|'[CRASH]') ;;
      *) continue ;;
    esac
    cut -f1 "$EXPECTED" | grep -qxF "$sha" && continue
    dels=$((dels + 1))
    if [ "$DRY_RUN" -eq 1 ]; then
      printf -- '- %s %s\n' "$id" "$text"
      continue
    fi
    mem0_delete "$id"
    if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
      echo "mem0: failed to delete stale memory ${id} (status ${CURL_STATUS})" >&2
    fi
  done <"$INDEXED"

  while IFS=$'\t' read -r sha text; do
    [ -n "$sha" ] || continue
    cut -f2 "$INDEXED" | grep -qxF "$sha" && continue
    adds=$((adds + 1))
    if [ "$DRY_RUN" -eq 1 ]; then
      printf -- '+ %s\n' "$text"
      continue
    fi
    add_memory "$text" "$sha"
  done <"$EXPECTED"

  echo "mem0: reconcile ${ENTITY} — ${adds} add(s), ${dels} delete(s)$([ "$DRY_RUN" -eq 1 ] && echo ' (dry run)')" >&2
}

BOARD_SCRAPE="$(board_scrape_date)"
parse_results

if [ "$RECONCILE" -eq 1 ]; then
  reconcile
else
  while IFS=$'\t' read -r sha text; do
    [ -n "$sha" ] && emit "$text" "$sha"
  done <"$EXPECTED"
fi
