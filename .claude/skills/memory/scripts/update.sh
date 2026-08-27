#!/usr/bin/env bash
# Correct one memory. The store has no update route, so this is create-then-
# delete: the replacement gets a NEW id and the old id stops resolving.
#
#   update.sh <id> --text "<new text>" [--meta k=v ...] [--backup <file>]
#             [--confirm-write]
#
# Dry run is the default. Nothing is written or deleted without
# --confirm-write.
#
# Order, and it matters. Everything that can refuse runs before anything is
# written, so a refusal leaves no half-done trace:
#   1. read the original; refuse (exit 3) if the id does not resolve
#   2. refuse (exit 3) if the new text is identical to the old
#   3. run the per-class guards via remember.sh --check
#   4. refuse (exit 3) if the text already exists as another record — the
#      server would dedupe, and step 6 would then match that stranger
#   5. append the original's full JSON to the backup (.cache/memory-updates.jsonl)
#   6. write the replacement through remember.sh, then read it back;
#      abort (exit 4) if it is not there, original untouched
#   7. delete the original, one quoted id
#   8. print  old -> new
#   9. scan the store for records whose text names the old id, and warn
#
# The replacement inherits the original's metadata; --meta overrides a key.
#
# Exits: 2 usage, 3 refusal (bad id, guard, identical text, text already exists
# as another record), 4 write or read-back failed and nothing was deleted.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
RECALL="$here/recall.sh"
REMEMBER="$here/remember.sh"
FORGET="$here/forget.sh"

usage() {
  sed -n '2,27p' "$0" >&2
  exit 2
}

id="" text="" backup="$repo/.cache/memory-updates.jsonl" confirm="" pairs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --text)          [ $# -ge 2 ] || usage; text="$2"; shift 2 ;;
    --meta)          [ $# -ge 2 ] || usage; pairs+=("$2"); shift 2 ;;
    --backup)        [ $# -ge 2 ] || usage; backup="$2"; shift 2 ;;
    --confirm-write) confirm=1; shift ;;
    --help)          sed -n '2,27p' "$0" >&2; exit 0 ;;
    -*)              echo "update: unknown flag $1" >&2; usage ;;
    *)               [ -z "$id" ] || { echo "update: unexpected argument $1" >&2; usage; }
                     id="$1"; shift ;;
  esac
done
[ -n "$id" ] && [ -n "$text" ] || usage

orig="$("$RECALL" --get "$id" 2>/dev/null)"
[ -n "$orig" ] || { echo "update: REFUSED — no memory $id" >&2; exit 3; }

old_id="$(jq -r '.id' <<<"$orig")"
old_text="$(jq -r '.memory // ""' <<<"$orig")"
entity="$(jq -r '.metadata.entity // "-"' <<<"$orig")"

# Identical text would short-circuit on the server's sha256 and hand back the
# original's own id — the delete would then destroy the only copy.
if [ "$text" = "$old_text" ]; then
  echo "update: REFUSED — new text is identical to the original; nothing to correct" >&2
  exit 3
fi

# Inherit the original's metadata, flattened to the dotted keys remember.sh
# takes. remember.sh itself lists those keys, so it stays the one source.
allowed="$("$REMEMBER" --help 2>&1 | sed -n 's/^  meta keys: //p')"

meta_args=()
while IFS= read -r kv; do
  [ -n "$kv" ] || continue
  k="${kv%%=*}"
  if ! grep -qw -- "$k" <<<"$allowed"; then
    echo "update: dropping metadata '$k' — remember.sh does not take it" >&2
    continue
  fi
  for p in ${pairs[@]+"${pairs[@]}"}; do [ "${p%%=*}" = "$k" ] && continue 2; done
  meta_args+=(--meta "$kv")
done < <(jq -r '(.metadata // {})
  | [paths(scalars) as $p | {k: ($p | join(".")), v: (getpath($p) | tostring)}]
  | .[] | select(.k | test("^(entity|schema|sha256)$") | not)
  | "\(.k)=\(.v)"' <<<"$orig")

for p in ${pairs[@]+"${pairs[@]}"}; do meta_args+=(--meta "$p"); done

echo "update: $old_id  ($entity)" >&2
echo "  was: $old_text" >&2
echo "  now: $text" >&2

# The guards run in both modes, and before the backup, so a class refusal
# leaves no half-done trace behind it.
"$REMEMBER" --check "$text" "$entity" ${meta_args[@]+"${meta_args[@]}"} || exit $?

# The service dedupes on a client-supplied sha256 of the text. If this exact
# text is already some other record, the write is a no-op and the read-back
# below would match that record instead — deleting the original and reporting
# a stranger as its replacement. Refuse before anything is written.
twin="$("$RECALL" --list '' "${MEMORY_SCAN_LIMIT:-5000}" --json 2>/dev/null \
  | jq -r --arg t "$text" --arg old "$old_id" \
      '[.[] | select(.memory == $t and .id != $old) | .id] | first // empty')"
if [ -n "$twin" ]; then
  echo "update: REFUSED — that text already exists as $twin. Updating would delete" >&2
  echo "  $old_id and hand you $twin, which is a different record." >&2
  exit 3
fi

if [ -z "$confirm" ]; then
  echo "update: DRY RUN — re-run with --confirm-write to write, read back and delete $old_id" >&2
  exit 0
fi

mkdir -p "$(dirname "$backup")"
jq -c . <<<"$orig" >>"$backup" || { echo "update: cannot write backup $backup" >&2; exit 4; }
echo "update: backed up to $backup" >&2

"$REMEMBER" "$text" "$entity" ${meta_args[@]+"${meta_args[@]}"} || exit $?

# remember.sh reports the write on stderr but not the id, and exits 0 with the
# service down. The read-back is the only proof.
new_id="$("$RECALL" --list '' "${MEMORY_SCAN_LIMIT:-5000}" --json 2>/dev/null \
  | jq -r --arg t "$text" --arg old "$old_id" \
      '[.[] | select(.memory == $t and .id != $old) | .id] | last // empty')"

if [ -z "$new_id" ]; then
  echo "update: ABORTED — replacement did not read back. $old_id is untouched." >&2
  exit 4
fi

"$FORGET" --yes "$old_id" || { echo "update: replacement is $new_id but the delete failed — both exist" >&2; exit 4; }

echo "$old_id -> $new_id"

prefix="${old_id:0:8}"
hits="$("$RECALL" --list '' "${MEMORY_SCAN_LIMIT:-5000}" --json 2>/dev/null \
  | jq -r --arg p "$prefix" --arg old "$old_id" --arg new "$new_id" '
      .[] | select(.id != $new)
      | select(.memory | test("(^|[^0-9a-f])" + $p + "([^0-9a-f]|$)"; "i"))
      | (if (.memory | test("(BOUNDS|BOUNDED BY|read that one first|SEE)[^.]*" + $p; "i"))
           then "DIRECTIVE"
         elif (.memory | test("(formerly|replaces|replaced|superseded|was)[^.]*" + $p; "i"))
           then "HISTORICAL"
         else "UNCLASSIFIED" end) as $kind
      | "  \($kind)\t\(.id)\t\(.metadata.entity // "-")\t\(.memory)"')"

if [ -n "$hits" ]; then
  n="$(wc -l <<<"$hits" | tr -d ' ')"
  echo "update: WARNING — $n record(s) still name $prefix. Repair each one:" >&2
  echo "$hits" >&2
  echo "update: DIRECTIVE hits point a reader at a record that no longer exists and must be rewritten to $new_id. HISTORICAL hits are provenance and may be left. UNCLASSIFIED could not be told apart — read it." >&2
else
  echo "update: no record names $prefix" >&2
fi
