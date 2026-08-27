#!/usr/bin/env bash
# Prune one round's tier-1 memories — but only after the promotion is proven.
# DRY RUN BY DEFAULT.
#
#   prune-round.sh <round-entity> --promoted-to <entity> [--promoted-to <entity> ...]
#                  [--confirm-destructive]
#
#   prune-round.sh round:decode-tg/h1 --promoted-to flag:max_num_seqs
#   prune-round.sh round:decode-tg/h1 --promoted-to flag:max_num_seqs --confirm-destructive
#
# WHY THIS EXISTS
# The old canonical prune was `recall.sh --list <round> 200 | cut -f1 |
# forget.sh --yes -`. forget.sh does refuse without --yes and does print what it
# would delete — but that pipeline passes --yes, so the guard never fires and
# the ids are never surfaced to the agent. The review step existed on paper
# only. This script is that review step, made to actually run.
#
# WHAT IT GUARANTEES
#   - the round's memories are READ BACK AND PRINTED before anything is deleted
#   - a promotion carrying this round in its `basis=` must ALREADY EXIST at a
#     wider entity, or nothing is deleted. The round named anywhere else in the
#     promotion — its prose included — does not count.
#   - deletion needs --confirm-destructive; without it this prints and stops
#   - only `round:<exp>/h<N>` entities can be pruned, so a typo cannot aim it at
#     a tier-2 entity
#   - re-running after a successful prune is a no-op, not an error
#
# Deletion is permanent and the server keeps no undo. Every refusal below is the
# last thing standing between a typo and a round's notebook.
#
# EXIT CODES
#   0  pruned, or nothing left to prune
#   1  dry run — this is what it WOULD delete, re-run with --confirm-destructive
#   2  usage
#   3  REFUSED — bad entity, unreadable store, or no promotion found
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
recall="$here/recall.sh"
forget="$here/forget.sh"

usage() {
  sed -n '2,9p' "$0" >&2
  exit 2
}

round="" confirm="" promoted=()
while [ $# -gt 0 ]; do
  case "$1" in
    --promoted-to) [ $# -ge 2 ] || usage; promoted+=("$2"); shift 2 ;;
    --confirm-destructive) confirm=1; shift ;;
    --help) usage ;;
    -*) echo "prune-round: unknown flag $1" >&2; usage ;;
    *)  [ -z "$round" ] || { echo "prune-round: one round entity, got '$1' as well" >&2; usage; }
        round="$1"; shift ;;
  esac
done

[ -n "$round" ] || usage

# --- guard: only a tier-1 round entity may be pruned -------------------------
case "$round" in
  round:*/h[0-9]*) ;;
  *) echo "prune-round: REFUSED — '$round' is not a round entity." >&2
     echo "  Only round:<experiment>/h<N> may be pruned. Tier-2 entities" >&2
     echo "  (model: family: stack: box: flag:) are durable and are never pruned." >&2
     exit 3 ;;
esac

# `decode-tg/h1` — the token a promotion's basis= must name.
token="${round#round:}"

[ "${#promoted[@]}" -gt 0 ] || {
  echo "prune-round: REFUSED — no --promoted-to given." >&2
  echo "  Nothing is deleted until a promotion carrying '$token' is found at a" >&2
  echo "  wider entity. Promote first, then name where it went." >&2
  exit 3
}

for p in "${promoted[@]}"; do
  case "$p" in
    "$round") echo "prune-round: REFUSED — --promoted-to '$p' is the round itself." >&2
              echo "  A promotion is a NEW memory at a WIDER entity." >&2; exit 3 ;;
    round:*)  echo "prune-round: REFUSED — --promoted-to '$p' is another round." >&2
              echo "  Tier 1 does not promote into tier 1." >&2; exit 3 ;;
  esac
done

# --- guard: the store must be readable, or "empty" is a lie ------------------
# recall.sh exits 0 with no output when the service is down, so an unreadable
# store and a pruned round look identical. Probe the whole store first.
if [ -z "$("$recall" --list '' 1 2>/dev/null)" ]; then
  echo "prune-round: REFUSED — the store returned nothing at all." >&2
  echo "  Either it is unreachable or it is empty; from here those look the" >&2
  echo "  same, and deleting against an unreadable store is not survivable." >&2
  exit 3
fi

# --- read the round back and print it ----------------------------------------
recs="$("$recall" --list "$round" 500 --json 2>/dev/null)"
[ -n "$recs" ] || recs='[]'
count="$(jq 'length' <<<"$recs" 2>/dev/null || echo 0)"

if [ "$count" -eq 0 ]; then
  echo "prune-round: $round holds no memories — nothing to prune." >&2
  exit 0
fi

echo "prune-round: $round holds $count memories:" >&2
jq -r '.[] | "  \(.id)  \(.memory | gsub("\\s+"; " ") | .[0:96])"' <<<"$recs" >&2
echo >&2

# --- guard: the promotion must already exist ---------------------------------
found=0
for p in "${promoted[@]}"; do
  hits="$("$recall" --list "$p" 200 --json 2>/dev/null)"
  [ -n "$hits" ] || hits='[]'
  # basis= only. A memory that merely mentions the round in prose is not a
  # promotion of it, and this is the last guard before permanent deletion.
  #
  # The token must match WHOLE. A substring test would let a promotion whose
  # basis names decode-tg/h10 unlock the pruning of decode-tg/h1, which bites
  # from h10 up: no digit may follow, and no identifier character may precede.
  matched="$(jq -c --arg t "$token" '
    def esc: gsub("(?<c>[.^$|()\\[\\]{}*+?\\\\])"; "\\\(.c)");
    ("(^|[^A-Za-z0-9_/-])" + ($t | esc) + "([^0-9]|$)") as $re
    | map(select((.metadata.basis // "") | test($re)))' <<<"$hits" 2>/dev/null)"
  [ -n "$matched" ] || matched='[]'
  n="$(jq 'length' <<<"$matched")"
  if [ "$n" -gt 0 ]; then
    found=$((found + n))
    echo "prune-round: promotion confirmed at $p ($n with $token in basis=):" >&2
    jq -r '.[] | "  \(.id)  \(.memory | gsub("\\s+"; " ") | .[0:96])"' <<<"$matched" >&2
  else
    echo "prune-round: nothing at $p carries $token in basis=" >&2
  fi
done
echo >&2

if [ "$found" -eq 0 ]; then
  echo "prune-round: REFUSED — no promotion for $token exists yet." >&2
  echo "  Searched: ${promoted[*]}" >&2
  echo "  A promotion is a NEW memory at a wider entity carrying" >&2
  echo "    --meta basis=\"$token: <cells and figures>\"" >&2
  echo "  Write it, confirm it reads back, then run this again. The $count" >&2
  echo "  memories above are the only copy of this round's reasoning." >&2
  exit 3
fi

# --- dry run is the default ---------------------------------------------------
if [ -z "$confirm" ]; then
  echo "prune-round: DRY RUN — would delete the $count memories at $round." >&2
  echo "  $found promotion(s) carry $token in basis=, so the findings survive." >&2
  echo "  Re-run with --confirm-destructive to delete. There is no undo." >&2
  exit 1
fi

# --- delete, through the one deleter -----------------------------------------
jq -r '.[].id' <<<"$recs" | "$forget" --yes -
rc=$?

left="$("$recall" --list "$round" 500 --json 2>/dev/null)"
[ -n "$left" ] || left='[]'
remaining="$(jq 'length' <<<"$left" 2>/dev/null || echo 0)"
echo "prune-round: $round now holds $remaining memories." >&2
[ "$remaining" -eq 0 ] || echo "prune-round: some survived — re-run to finish." >&2
exit $rc
