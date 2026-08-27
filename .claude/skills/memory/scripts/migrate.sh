#!/usr/bin/env bash
# Migrate the JUDGEMENT half of the legacy store to schema 1. DRY RUN BY DEFAULT.
#
#   migrate.sh                                    derive and print before -> after
#   migrate.sh --json | --summary                 the same derivation, other shapes
#   migrate.sh --create  --confirm-write       --backup F --map M
#   migrate.sh --verify                                     --map M
#   migrate.sh --prune   [--confirm-destructive]            --map M
#   migrate.sh --reseal  [--confirm-destructive] --backup F --map M
#
# SCOPE — [LESSON] [ENV] [IDEA], and [EXPERIMENT] rewritten to [LESSON].
# [OBSERVATION] belongs to regen.sh, which rebuilds measurements from archive
# ground truth. This script never touches an [OBSERVATION]; the two scripts
# cannot both claim a record. Judgement text is re-posted VERBATIM: nothing here
# rewrites prose, only the marker on the four [EXPERIMENT] rows.
#
# WHY [EXPERIMENT] BECOMES [LESSON] AND NOT [OBSERVATION]
# Each of the four is a cross-run comparison carrying a verdict that exists in no
# archive. As [OBSERVATION] they would need one model/test/depth/conc/bench and
# they cite several, so they could never earn the warranty; as [LESSON] with
# basis= naming the bench ids, the judgement is preserved and the numbers stay
# traceable to the archive regen.sh owns rather than duplicated out of it.
#
# THE SERVICE HAS NO UPDATE ROUTE
# It exposes POST /memories, POST /search, POST /memories/list, DELETE
# /memories/{id}, GET /health, and MemoryCreate carries neither id nor
# created_at. A metadata change is therefore DELETE + re-POST. The order here is
# CREATE -> VERIFY -> PRUNE, never the reverse: a failure then leaves a
# DUPLICATE, which is recoverable, instead of a hole, which is not.
#
# THE DEDUPE KEY FORCES A FOURTH HOP
# /memories short-circuits on metadata.sha256: if a record with that sha256
# already exists it returns the old id and {"deduped": true} without writing.
# All 208 legacy records carry the true sha of their text, so a verbatim re-post
# WITH the key while the old record still exists creates nothing. So --create
# posts the new record WITHOUT sha256, and --reseal — after the old id is gone
# and the key is free — posts the record again WITH it and drops the keyless
# interim. Every hop creates before it deletes, so the text is never absent.
#
# SCHEMA 1 IS A WARRANTY, NOT A LABEL
# schema="1" is stamped ONLY when every field the class requires was recovered
# from evidence. PARTIAL takes what was recovered and NO stamp, so
# `--filter schema=1` keeps meaning "meets the contract". Create-first changes
# what is safe to attempt, not what the stamp asserts, so the rule is unchanged.
#
# NO epoch.image IS DERIVED FROM PROSE
# Three records name `dgx-vllm-eugr-nightly:<n>`. That is a TAG; epoch.image is
# the DIGEST of the image the box ran, and regen.sh refuses the same string for
# the same reason. A key holding tags in some records and digests in others
# makes equality filtering over it unsound, so nothing is stamped — the tag
# stays readable in the record's own text.
#
# LEGACY RECORDS ARE LEFT BEHIND
# A record whose derivation recovers almost nothing gets verdict LEGACY, and
# --create migrates FULL and PARTIAL only. LEGACY rows are not copied, not
# stamped and not deleted: they stay exactly as they are, and --create prints
# their ids so the operator sees what is being left in place rather than
# discovering it later from a count that does not add up.
#
# THE BACKUP IS WRITTEN ONCE
# --create REFUSES an existing --backup path. Run one's backup is the store
# before any of this started and it is the only undo; a resume re-deriving over
# a store that now holds interims would otherwise replace it with a mixture.
# Resume with the same --map and a fresh --backup path.
#
# A RESUME DOES NOT RE-DERIVE ITS OWN INTERIMS
# The interims from an earlier pass carry no sha256, and a PARTIAL one carries
# no schema stamp either, so a plain re-derivation reads them as fresh legacy
# rows. Every id already recorded as a `new` in the map is therefore excluded
# from the plan; otherwise a record finds itself as its own keyless twin and
# maps old == new.
#
# THE DERIVATION lives in migrate-derive.jq beside this script.
#
set -uo pipefail

USER_ID="dgx-spark-tuner"
PORT=8888
LIMIT=2000

mode=print stage="" confirm_w="" confirm_d="" backup="" map=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) mode=print; shift ;;
    --json)    mode=json; shift ;;
    --summary) mode=summary; shift ;;
    --create|--verify|--prune|--reseal) stage="${1#--}"; shift ;;
    --confirm-write)       confirm_w=1; shift ;;
    --confirm-destructive) confirm_d=1; shift ;;
    --backup) [ $# -ge 2 ] || { echo 'migrate: --backup needs a path' >&2; exit 2; }
              backup="$2"; shift 2 ;;
    --map)    [ $# -ge 2 ] || { echo 'migrate: --map needs a path' >&2; exit 2; }
              map="$2"; shift 2 ;;
    --help)   sed -n '2,74p' "$0" >&2; exit 0 ;;
    *) echo "migrate: unknown argument $1" >&2; exit 2 ;;
  esac
done

host="$(jq -r '.host // empty' "$(git rev-parse --show-toplevel)/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "migrate: no box configured" >&2; exit 0; }

call() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
      "curl -sS --max-time 30 -X $method -H 'Content-Type: application/json' \
       --data-binary @- 'http://127.0.0.1:${PORT}${path}'" 2>/dev/null
  else
    ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$host" \
      "curl -sS --max-time 30 -X $method 'http://127.0.0.1:${PORT}${path}'" 2>/dev/null
  fi
}

snapshot() {
  call POST /memories/list "$(jq -nc --arg u "$USER_ID" --argjson l "$LIMIT" \
    '{user_id: $u, limit: $l}')" \
  | jq -c '(if type == "array" then . else (.results // []) end)' 2>/dev/null
}

recs="$(snapshot)"
[ -n "$recs" ] || { echo "migrate: store unreadable, nothing done" >&2; exit 0; }
echo "migrate: store holds $(jq length <<<"$recs") records" >&2

DERIVE="$(dirname "$0")/migrate-derive.jq"
[ -f "$DERIVE" ] || { echo "migrate: missing $DERIVE" >&2; exit 2; }
all="$(jq -c -f "$DERIVE" <<<"$recs" 2>/dev/null)"
[ -n "$all" ] || { echo "migrate: derivation failed" >&2; exit 1; }
plan="$(jq -c 'select(.owner == "judgement")' <<<"$all")"

fp_of() { printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1; }

need_map() { [ -n "$map" ] || { echo "migrate: --$stage needs --map <file>" >&2; exit 2; }; }

# A row is confirmed only when its new id reads back with the same text.
confirmed() {  # confirmed <snapshot> <new_id> <fingerprint>
  local got
  got="$(jq -r --arg i "$2" '.[] | select(.id == $i) | .memory' <<<"$1" 2>/dev/null)"
  [ -n "$got" ] || return 1
  [ "$(fp_of "$got")" = "$3" ]
}

case "$stage" in
create)
  need_map
  [ -n "$confirm_w" ] || { echo "migrate: REFUSED — --create needs --confirm-write." >&2; exit 3; }
  [ -n "$backup" ]    || { echo "migrate: REFUSED — --create needs --backup <file>." >&2; exit 3; }
  # The backup is written once and never overwritten. On a resume this store
  # already holds interims, so re-writing the same path would replace the only
  # snapshot that means "before any of this started" with a mixture.
  if [ -e "$backup" ]; then
    echo "migrate: REFUSED — $backup already exists." >&2
    echo "  That file is the store before this migration began, and it is the" >&2
    echo "  only undo. Resuming reuses the same --map but needs a NEW --backup" >&2
    echo "  path; move the existing one aside only on purpose." >&2
    exit 3
  fi
  # snapshot() already emits an array; -s here would wrap it in a second one and
  # the length check below could never pass.
  jq . <<<"$recs" > "$backup" || { echo "migrate: backup write failed" >&2; exit 3; }
  [ "$(jq length "$backup" 2>/dev/null)" = "$(jq length <<<"$recs")" ] \
    || { echo "migrate: backup did not read back intact — refusing" >&2; exit 3; }
  echo "migrate: backup of $(jq length "$backup") records at $backup" >&2
  # The map is APPENDED, never truncated: a --create that dies partway has
  # already created interims, and the rows naming them are the only route by
  # which --prune and --reseal can reach those records.
  [ -s "$map" ] && echo "migrate: resuming — $(wc -l <"$map" | tr -d ' ') rows already mapped" >&2
  [ -e "$map" ] || : > "$map"
  legacy="$(jq -r 'select(.verdict == "LEGACY") | "  \(.id)  [\(.class)]  \(.entity)"' <<<"$plan")"
  if [ -n "$legacy" ]; then
    echo "migrate: SKIPPING $(wc -l <<<"$legacy" | tr -d ' ') LEGACY records — left in place, unstamped:" >&2
    echo "$legacy" >&2
  fi
  # Ids this map already names as replacements. They are the keyless interims a
  # previous pass created; re-deriving over them would map each to itself.
  interims="$(jq -r '.new // empty' "$map" 2>/dev/null | sort -u)"
  while IFS= read -r row; do
    v="$(jq -r .verdict <<<"$row")"
    case "$v" in FULL|PARTIAL) ;; *) continue ;; esac
    old="$(jq -r .id <<<"$row")"; txt="$(jq -r .text <<<"$row")"
    if [ -n "$interims" ] && grep -qxF -- "$old" <<<"$interims"; then
      echo "migrate: ${old:0:8} is an interim from an earlier --create — not re-derived" >&2
      continue
    fi
    fp="$(fp_of "$txt")"
    jq -se --arg o "$old" 'any(.[]; .old == $o)' "$map" >/dev/null 2>&1 && continue
    # The interim carries no sha256, so the server will not dedupe it. A keyless
    # twin means an earlier --create already made it and its map row was lost:
    # adopt that id rather than skipping, or the record is orphaned — no row, so
    # --prune never removes the old one and --reseal never seals the new one.
    twin="$(jq -r --arg t "$txt" \
      'map(select(.memory == $t and (.metadata.sha256 | not))) | first | .id // empty' \
      <<<"$recs")"
    if [ -n "$twin" ]; then
      new="$twin"
      echo "migrate: ${old:0:8} -> ${twin:0:8} interim already existed — remapped" >&2
    else
      body="$(jq -c --arg t "$txt" --arg u "$USER_ID" \
        '{messages: [{role: "user", content: $t}], user_id: $u,
          metadata: .derived, infer: false}' <<<"$row")"
      res="$(call POST /memories "$body")"
      new="$(jq -r '.results[0].id // empty' <<<"$res" 2>/dev/null)"
      dd="$(jq -r '.deduped // false' <<<"$res" 2>/dev/null)"
      if [ -z "$new" ] || [ "$dd" = true ] || [ "$new" = "$old" ]; then
        echo "migrate: ${old:0:8} NOT created (deduped=$dd) — old record untouched" >&2
        continue
      fi
      echo "migrate: ${old:0:8} -> ${new:0:8} $v" >&2
    fi
    jq -nc --arg o "$old" --arg n "$new" --arg e "$(jq -r .entity <<<"$row")" \
      --arg f "$fp" --arg c "$(jq -r .class <<<"$row")" --arg v "$v" \
      '{old: $o, new: $n, entity: $e, fp: $f, class: $c, verdict: $v}' >> "$map"
  done <<<"$plan"
  echo "migrate: mapping of $(wc -l < "$map" | tr -d ' ') rows at $map" >&2
  exit 0 ;;

verify)
  need_map
  snap="$(snapshot)"
  ok=0; bad=0
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    n="$(jq -r .new <<<"$r")"; f="$(jq -r .fp <<<"$r")"; o="$(jq -r .old <<<"$r")"
    if confirmed "$snap" "$n" "$f"; then ok=$((ok+1))
    else bad=$((bad+1)); echo "migrate: ${o:0:8} -> ${n:0:8} NOT CONFIRMED" >&2; fi
  done < "$map"
  echo "migrate: verify — $ok confirmed, $bad not confirmed" >&2
  [ "$bad" -eq 0 ] || exit 3
  exit 0 ;;

prune)
  need_map
  snap="$(snapshot)"
  todo=() ; refused=0
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    o="$(jq -r .old <<<"$r")"; n="$(jq -r .new <<<"$r")"; f="$(jq -r .fp <<<"$r")"
    if [ "$o" = "$n" ]; then
      echo "REFUSE ${o:0:8} — replacement id equals the old id"; refused=$((refused+1)); continue
    fi
    if ! confirmed "$snap" "$n" "$f"; then
      echo "REFUSE ${o:0:8} — replacement ${n:0:8} does not read back with the same text"
      refused=$((refused+1)); continue
    fi
    echo "DELETE ${o:0:8} — replaced by ${n:0:8}, confirmed"
    todo+=("$o")
  done < "$map"
  echo "migrate: prune — ${#todo[@]} deletable, $refused refused" >&2
  if [ -z "$confirm_d" ]; then
    echo "migrate: DRY RUN — --prune needs --confirm-destructive to delete." >&2; exit 0
  fi
  for o in ${todo[@]+"${todo[@]}"}; do
    call DELETE "/memories/$o" >/dev/null
    echo "migrate: ${o:0:8} pruned" >&2
  done
  exit 0 ;;

reseal)
  need_map
  [ -n "$backup" ] || { echo "migrate: REFUSED — --reseal needs --backup <file>." >&2; exit 3; }
  snap="$(snapshot)"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    o="$(jq -r .old <<<"$r")"; n="$(jq -r .new <<<"$r")"; f="$(jq -r .fp <<<"$r")"
    if jq -e --arg i "$o" 'any(.id == $i)' <<<"$snap" >/dev/null; then
      echo "REFUSE ${n:0:8} — old ${o:0:8} still present, prune first"; continue
    fi
    confirmed "$snap" "$n" "$f" || { echo "REFUSE ${n:0:8} — interim not readable"; continue; }
    echo "RESEAL ${n:0:8} — re-post with sha256=${f:0:8}, then drop the interim"
    [ -n "$confirm_d" ] || continue
    rec="$(jq -c --arg i "$n" '.[] | select(.id == $i)' <<<"$snap")"
    txt="$(jq -r .memory <<<"$rec")"
    body="$(jq -c --arg t "$txt" --arg u "$USER_ID" --arg s "$f" \
      '{messages: [{role: "user", content: $t}], user_id: $u,
        metadata: (.metadata + {sha256: $s}), infer: false}' <<<"$rec")"
    res="$(call POST /memories "$body")"
    sealed="$(jq -r '.results[0].id // empty' <<<"$res" 2>/dev/null)"
    if [ -z "$sealed" ] || [ "$sealed" = "$n" ]; then
      echo "migrate: ${n:0:8} reseal failed — interim KEPT" >&2; continue
    fi
    if confirmed "$(snapshot)" "$sealed" "$f"; then
      call DELETE "/memories/$n" >/dev/null
      echo "migrate: ${n:0:8} -> ${sealed:0:8} sealed" >&2
    else
      echo "migrate: ${sealed:0:8} not readable — interim KEPT" >&2
    fi
  done < "$map"
  [ -n "$confirm_d" ] || echo "migrate: DRY RUN — --reseal needs --confirm-destructive." >&2
  exit 0 ;;
esac

if [ "$mode" = json ]; then jq -s . <<<"$plan"; exit 0; fi

if [ "$mode" = print ]; then
  jq -r '
    "── \(.id[0:8])  \(.verdict)  [\(.class)]  \(.entity)\(if .rewrote_experiment then "  «[EXPERIMENT]→[LESSON], sha256 changes»" else "" end)",
    "   text   : \(.text[0:150])\(if (.text|length) > 150 then "…" else "" end)",
    "   before : \(.before | to_entries | map("\(.key)=\(.value|tostring[0:16])") | sort | join("  "))",
    "   after  : \(.derived | to_entries | map("\(.key)=\(.value|tostring[0:60])") | sort | join("  "))",
    (if (.missing|length) > 0 then "   MISSING: \(.missing | join(" ")) — not fabricated, no schema stamp" else empty end),
    (if (.ambiguous|length) > 0 then "   spans  : \(.ambiguous | join(", ")) — left blank, record covers more than one" else empty end),
    "   why    : \(.evidence | to_entries | map("\(.key)←\(.value)") | join("; "))",
    ""' <<<"$plan"
fi

echo "════════ SUMMARY (judgement set only) ════════"
jq -s -r '
  "judgement records  : \(length)",
  "verdict            : " + ([group_by(.verdict)[] | "\(.[0].verdict)=\(length)"] | join("  ")),
  "class              : " + ([group_by(.class)[]   | "\(.[0].class)=\(length)"]   | join("  ")),
  "entity prefix      : " + ([group_by(.entity | split(":")[0])[]
                              | "\(.[0].entity|split(":")[0])=\(length)"] | join("  ")),
  "date= from text    : \([.[] | select(.date_src == "text")] | length)",
  "date= from created : \([.[] | select(.date_src == "created_at")] | length)",
  "model= stamped     : \([.[] | select(.derived.model)] | length)",
  "model= blank, deliberate (family/stack/box-wide): \([.[] | select((.derived.model|not) and .evidence.model)] | length)",
  "model= blank, UNRESOLVED                        : \([.[] | select((.derived.model|not) and (.evidence.model|not))] | length)",
  "[EXPERIMENT] → [LESSON]: \([.[] | select(.rewrote_experiment)] | length)",
  "",
  "── text stamp disagrees with created_at (text wins) ──",
  ([.[] | select(.date_clash) | "  \(.id[0:8])  text=\(.text_date)  created_at=\(.created_at)  \(.entity)"] | join("\n")),
  "",
  "── model= evidence rules used ──",
  ([.[] | select(.evidence.model) | .evidence.model] | group_by(.) | map("  \(length)  \(.[0])") | join("\n")),
  "",
  "── UNRESOLVED (no model evidence of any kind) ──",
  ([.[] | select((.derived.model|not) and (.evidence.model|not))
        | "  \(.id[0:8])  \(.entity)  \(.text[0:80])"] | join("\n")),
  "",
  "── records still missing a required field ──",
  ([.[] | select((.missing|length) > 0) | "\(.class)/\(.missing|join("+"))"]
     | group_by(.) | map("  \(length)  \(.[0])") | join("\n"))
' <<<"$plan"

jq -s -r '"", "not ours: " + ([group_by(.owner)[] | "\(.[0].owner)=\(length)"] | join("  "))
  + "  (regen = [OBSERVATION], regen.sh owns them)"' <<<"$all"

echo
echo "migrate: DRY RUN — nothing written. Store untouched." >&2
exit 0
