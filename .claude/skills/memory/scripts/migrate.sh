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
    --help)   sed -n '2,45p' "$0" >&2; exit 0 ;;
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
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
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

DERIVE='
def hits(re):   [match(re; "g").string] | unique;
def groups(re): [match(re; "g") | .captures[0].string] | unique;

# Bench ids read verbatim: research/**/id.txt, and benchmark_id in each archived
# run state.yaml (only 5 archive dirs carry id.txt). Never reconstructed.
def bench_08b: "03b5a04e760a 0b07765e053f 0b93f5cfe862 129a556cce47 1851f83d3653
185d381aeeb2 2e246bc5b280 4f9da10931e0 59e87386d131 7270eca7baa2 7a7591590f70
bf8f0926acb8 c2ed1165fcfc c6db5d02e496 eb6e39538b5e";
def bench_35b: "0509b2a740f6 064550e26525 064fc6128314 076db52d341c 0954971b5dfa
0bd1f20dca74 0ef7af8997ce 0f4c34c12223 10496035f7fd 107f95223a60 10bd1b5f24ea
12f458ba7348 25a0e7f36ab0 2b0f7bc8fb7b 30d6586cc70a 3d8149654d1b 433eeaf9827e
5399a85d7aec 5eea211b9a30 647b25c13d9f 6921c874daee 6c1d46e5fd36 76bccce3d8b3
858173ba5753 860b43edd154 8707c27ce1a4 9379c15468ec 93e361742c94 964a188f3d16
a062dab1eed0 a769c1142e15 ac37f5b64487 b20062a3c5c5 b56686c32206 bb4b8ef8a193
be900399e857 c9518e3e96a3 d6cec044441c d9fdc68576f2 dab043abba20 dd3afc9e1c94
ddfac4b975ed deb3090b9a29 f58c56da6658 f6e4a4c51f71 fa5630a4ac79 e7394e3e361b
0277635a209e 5bd6407a051e 40d5cd24568c 2ebcb63db398 00f6e273f26c 02f9548d80da
0a988a464b5a 26c64e5c27b8 270c9926d658 4363a52d9d21 44dd96bddd72 457ef6a4d80a
594c47d62013 685e42bde522 6bd19fe9a3c2 7d27a25ac7f2 7e811800d715 8ced4b0ea3c2
95fdfa8922a3 99d4f92d70a2 9db1360b8e5e a0c409874de1 bcde52479f68 c003c48ede71
c77f38339d26 da8989775690 e86574ff0e1e fa59c397c082 fb2698042a7e fbb28a3df00f
ff46b9fac055";
def cited_in($t; $ids): [$t | hits("bench_[0-9a-f]{6,}")[] | .[6:12]]
                        | any(. as $b | $ids | test($b));

def model_of($t; $e):
  if   ($e | startswith("model:")) then {v: ($e[6:]), why: "entity names the checkpoint"}
  elif (cited_in($t; bench_08b))
       then {v: "Qwen/Qwen3.5-0.8B", why: "cites a bench archived under qwen35-08b-tg128-c1 (Qwen/Qwen3.5-0.8B, BF16)"}
  elif (cited_in($t; bench_35b))
       then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "cites a bench archived under a qwen36-35b campaign or the research tree (NVFP4)"}
  elif ($t | test("nvidia/Qwen3\\.6-35B-A3B-NVFP4")) then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "text names the checkpoint"}
  elif ($t | test("Qwen3\\.6-35B-A3B-FP8"))          then {v: "Qwen/Qwen3.6-35B-A3B-FP8", why: "text names the checkpoint"}
  elif ($t | test("qwen3\\.5-0\\.8b|qwen35-08b|Qwen3\\.5-0\\.8B"))
       then {v: "Qwen/Qwen3.5-0.8B", why: "text names the qwen35-08b-tg128-c1 campaign; that archive is Qwen/Qwen3.5-0.8B BF16 throughout"}
  elif ($t | test("Qwen3\\.6-35B-A3B-NVFP4"))        then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "text names the checkpoint (unprefixed)"}
  elif ($t | test("qwen36-35b-nvfp4|qwen36-35b-quant"))
       then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "text names a qwen36-35b campaign; every archived run in both is this checkpoint"}
  elif ($t | test("\\bR[0-9]{1,2}[a-z]?\\b"))
       then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "R-series round: .cache/_archive/qwen36-35b-nvfp4-cells/experiments/_archive/R01..R25 are all this checkpoint"}
  elif ($t | test("decode-tg|concurrency/h|depth-curve"))
       then {v: "nvidia/Qwen3.6-35B-A3B-NVFP4", why: "names an experiment under research/Qwen3.6-35B-A3B-NVFP4, whose recipe.yaml pins this checkpoint"}
  elif ($e | startswith("family:")) then {v: "", why: "family-wide claim: no single checkpoint is warranted"}
  elif ($e | startswith("stack:")) then {v: "", why: "stack-wide claim: no single checkpoint is warranted"}
  elif ($e | startswith("box:"))   then {v: "", why: "box-wide claim: no single checkpoint is warranted"}
  else {v: "", why: ""} end;

def scope_of($t; $e):
  if   ($t | test("SM clock|clocks_throttle|MHz|nvidia-smi|power polic|W peak|thermal")) then "box telemetry: clock, power and thermal policy"
  elif ($t | test("llama-benchy"))  then "llama-benchy instrument behaviour"
  elif ($t | test("sparkrun"))      then "sparkrun tooling behaviour"
  elif ($t | test("filesystem|disk|Docker holds|root fs")) then "box storage"
  elif ($t | test("vllm/|vLLM|max_num_batched|prefix cach|chunked prefill")) then "vLLM engine configuration"
  elif ($t | test("MoE|layers|quant|BF16|FP8|NVFP4|vocab|MTP module|sampling")) then "checkpoint architecture and quantisation"
  else "" end;

def cites($t):
  ([ ($t | hits("bench_[0-9a-f]{6,}")[]),
     ($t | hits("\\bR[0-9]{1,2}[a-z]?\\b")[]),
     ($t | hits("(decode-tg|concurrency|depth-curve|arena-v2)/h?[0-9]*")[]),
     ($t | hits("qwen3[56]-[0-9a-z-]+")[]) ] | unique | join(" "));

.[] | . as $r
| ($r.metadata // {}) as $m
| ($m.entity // "") as $e
| ($r.memory) as $t0
| (if ($t0 | test("^\\[EXPERIMENT\\]")) then ($t0 | sub("^\\[EXPERIMENT\\]"; "[LESSON]")) else $t0 end) as $t
| ($t0 | test("^\\[EXPERIMENT\\]")) as $rewrote
| ((($t | capture("^\\[(?<c>[A-Z]+)\\]")).c) // "NONE") as $class
| (if ($class | test("^(LESSON|ENV|IDEA)$")) then "judgement"
   elif $class == "OBSERVATION" then "regen" else "none" end) as $owner
| (($t | capture("^\\[[A-Z]+\\] (?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})")).d // "") as $tdate
| ($r.created_at[0:10]) as $cdate
| (if $tdate != "" then {v: $tdate, src: "text", why: "date stamped in the text"}
   else {v: $cdate, src: "created_at", why: "server created_at (text carries no date)"} end) as $date
| (model_of($t; $e)) as $model
| ($t | hits("bench_[0-9a-f]{6,}")) as $benches
| ($t | groups("\\b(tg128|tg32|pp2048|pp128|ctx_tg|ctx_pp)\\b")) as $tests
| ($t | groups("\\bd([0-9]{1,7})\\b")) as $depths
| ($t | groups("\\bc([0-9]{1,2})\\b")) as $concs
| ($t | hits("NVFP4|FP8|BF16")) as $quants
| {
    id: $r.id, entity: $e, class: $class, owner: $owner,
    rewrote_experiment: $rewrote, text: $t, before: $m,
    created_at: $cdate, date_src: $date.src,
    date_clash: ($tdate != "" and $tdate != $cdate),
    text_date: $tdate,
    evidence: ({date: $date.why}
      + (if $model.why != "" then {model: $model.why} else {} end)),
    derived: ({schema_candidate: "1", entity: $e, date: $date.v}
      + (if $model.v != ""            then {model: $model.v} else {} end)
      + (if ($benches|length) == 1    then {bench: $benches[0]} else {} end)
      + (if ($tests|length) == 1      then {test: $tests[0]} else {} end)
      + (if ($depths|length) == 1     then {depth: $depths[0]} else {} end)
      + (if ($concs|length) == 1      then {conc: $concs[0]} else {} end)
      + (if ($quants|length) == 1     then {quant: $quants[0]} else {} end)
      + (if ($e | startswith("stack:")) then {runtime: ($e[6:])} else {} end)
      + (if ($t | test("dgx-vllm-eugr-nightly:[0-9]+"))
           then {"epoch.image": ($t | hits("dgx-vllm-eugr-nightly:[0-9]+")[0])} else {} end)
      + (if $class == "ENV"  and (scope_of($t; $e)) != "" then {scope: (scope_of($t; $e))} else {} end)
      + (if $class == "LESSON" and (cites($t)) != "" then {basis: (cites($t))} else {} end)
      + (if $class == "IDEA"   and (cites($t)) != "" then {evidence: (cites($t))} else {} end)),
    ambiguous: ([ (if ($benches|length) > 1 then "bench x\($benches|length)" else empty end),
                  (if ($tests|length)   > 1 then "test x\($tests|length)"    else empty end),
                  (if ($depths|length)  > 1 then "depth x\($depths|length)"  else empty end),
                  (if ($concs|length)   > 1 then "conc x\($concs|length)"    else empty end),
                  (if ($quants|length)  > 1 then "quant x\($quants|length)"  else empty end) ])
  }
| . as $x
| (if   $x.class == "ENV"    then ["date","scope"]
   elif $x.class == "LESSON" then ["date","basis"]
   elif $x.class == "IDEA"   then ["date","evidence"]
   else [] end) as $need
| ($need - ($x.derived | keys)) as $missing
| ($m.schema == "1") as $already
| $x + {missing: $missing,
        verdict: (if $already then "ALREADY"
                  elif ($missing|length) == 0 then "FULL"
                  elif (($x.derived | keys | length) > 3) then "PARTIAL"
                  else "LEGACY" end)}
| if .verdict == "FULL"
  then .derived |= (del(.schema_candidate) + {schema: "1"})
  else .derived |= del(.schema_candidate) end
'

all="$(jq -c "$DERIVE" <<<"$recs" 2>/dev/null)"
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
  jq -s . <<<"$recs" > "$backup" || { echo "migrate: backup write failed" >&2; exit 3; }
  [ "$(jq length "$backup" 2>/dev/null)" = "$(jq length <<<"$recs")" ] \
    || { echo "migrate: backup did not read back intact — refusing" >&2; exit 3; }
  echo "migrate: backup of $(jq length "$backup") records at $backup" >&2
  : > "$map"
  while IFS= read -r row; do
    v="$(jq -r .verdict <<<"$row")"
    case "$v" in FULL|PARTIAL) ;; *) continue ;; esac
    old="$(jq -r .id <<<"$row")"; txt="$(jq -r .text <<<"$row")"
    fp="$(fp_of "$txt")"
    # The interim carries no sha256, so the server will not dedupe it: skip a
    # text that already has a keyless twin, or a re-run double-creates.
    if jq -e --arg t "$txt" 'any(.memory == $t and (.metadata.sha256 | not))' \
         <<<"$recs" >/dev/null; then
      echo "migrate: ${old:0:8} interim already exists — skipped" >&2; continue
    fi
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
    jq -nc --arg o "$old" --arg n "$new" --arg e "$(jq -r .entity <<<"$row")" \
      --arg f "$fp" --arg c "$(jq -r .class <<<"$row")" --arg v "$v" \
      '{old: $o, new: $n, entity: $e, fp: $f, class: $c, verdict: $v}' >> "$map"
    echo "migrate: ${old:0:8} -> ${new:0:8} $v" >&2
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
