# Derive schema-1 metadata for one legacy record. Read by migrate.sh; the
# script feeds it the raw store snapshot as an array.
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
