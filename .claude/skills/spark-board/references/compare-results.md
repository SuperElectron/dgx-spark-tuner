# Comparing our figures to the board

## Define the peer set first

A board rank alone says almost nothing. The board mixes every model, so the
top of every cell is small models — a 350M model reads 411 t/s at
`d16384 c10`. A 35B MoE is not competing there.

The comparison that means something is **like for like**:

```
modelName    == "Qwen3.6-35B-A3B-NVFP4"
runtime      == "vLLM"
clusterSize  == 1
quantization == "NVFP4"
```

That excludes `-Fast` (a different HF repo) and `W4A16_NVFP4` (a different
quant). Say which set a number is ranked against, every time. Report both
ranks when they differ, because they answer different questions and only one
is usually the one being claimed.

## Rank our figure, never eyeball it

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)' \
| jq --argjson ours 141.46 '
    {cell: .testName, generated: .generatedAt, entries: (.entries|length),
     rank_all: ((.entries|map(select(.tokensPerSec > $ours))|length) + 1)}'
```

Rank within the peer set, plus the peer leader and a link to it:

```bash
PEER='.modelName=="Qwen3.6-35B-A3B-NVFP4" and .runtime=="vLLM"
      and .clusterSize==1 and .quantization=="NVFP4"'

jq -r --argjson ours 141.46 "
  [.entries[]|select($PEER)] as \$p
  | {peers: (\$p|length),
     rank_peers: ((\$p|map(select(.tokensPerSec > \$ours))|length) + 1),
     their_best: (\$p|max_by(.tokensPerSec)|.tokensPerSec),
     their_rank: (\$p|max_by(.tokensPerSec)|.rank),
     link: (\$p|max_by(.tokensPerSec)|\"https://spark-arena.com/benchmark/\"+.benchmarkId)}" cell.json
```

## Only `tg` is comparable for us

Every figure this campaign produces is cold-cache — MTP defeats the prefix
cache, so our hit rate is 0.0% while a board entry runs warm. Measured price:

    pp    4.1x
    ttfr  4.0x
    tg    +2.3%

So `tg` is safe to compare and `pp`/`ttfr` are not. Never set our `pp` or
`ttfr` beside a board `pp` or `ttfr`. See `experiments/decode-tg/h2`.

## Size the claim against our own scatter

A delta smaller than the cell's own run-to-run spread is a tie, not a win.
`d16384 c1` spans ±15% on a byte-identical configuration, so nothing at that
cell resolves below about 15%. Check the run's `measure.spread` before
calling a margin real.

## The rule this exists to enforce

**Never compute a board margin from a stored scrape. Fetch the cell.**

On 2026-08-25 a result was reported as **+38.3% over the best board entry** at
`tg128 d16384 c10`. It was computed against five entries scraped two days
earlier into `docs/arena-recipe.md`. That cell holds 219. Read live, the same
figure ranks **27 of 220**, a peer entry reads **236.97** against our 141.46,
and the **102.31** the whole experiment was aimed at is **rank 44** —
mid-table, not the frontier.

Nothing about the measurement was wrong. The comparison set was.

A scraped figure ages the moment it is written: snapshots regenerate every
half hour and entries arrive continuously. Any board number stored in this
repo is a date-stamped observation, never the current standing.

## Setting an Objective's target

Read the cell live, take the peer leader, and record `generatedAt` beside the
target. An Objective aimed at a mid-table number optimises against nothing.
