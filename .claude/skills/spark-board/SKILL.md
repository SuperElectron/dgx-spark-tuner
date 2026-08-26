---
name: spark-board
description: Read the live Spark Arena leaderboard for a cell — the whole ranked field, not a scrape. Use before setting an Objective's target number, before claiming a result beats the board, and before publishing anything.
---

# spark-board

## Role

The board is the yardstick every experiment is judged against. This skill reads
it live. It only ever reads — the endpoint below has no write path, and
**nothing is ever submitted to Spark Arena**.

Use it when:

- opening an experiment, to set the Objective's target from the real frontier
- concluding a round that claims to beat the board
- before publishing any figure anywhere

## The endpoint

The leaderboard is a Next.js app. Its table comes from one static JSON
snapshot per cell:

```
https://spark-arena.com/static/snapshot/test?test=<METRIC> @ d<DEPTH> (c<CONC>)
```

URL-encode it. No login, no key, no pagination — one request returns the whole
ranked field.

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)'
```

`curl` works with its own default user-agent. **Cloudflare 403s
`Python-urllib`**, so send a `User-Agent` header from any other client. A 403
is agent filtering, not a block on automation, and not a reason to stop.

A cell that does not exist answers `{"error":"Leaderboard test not found"}`,
still with HTTP 200 — check the body, not the status. A body starting
`<!DOCTYPE` means the path was wrong, not the cell.

### What exists

```
metrics      tg128  tg32  pp2048  pp4096  ctx_tg  ctx_pp
depths       128 512 1024 2048 4096 8192 16384 28672 32768 65535 65536
             100000 128768 131072 163840 190000 200000 259000 262144 524288
concurrency  1 2 4 5 10
```

`tg128`, `pp2048` and `pp4096` also exist bare, with no ` @ d<DEPTH>`.

Snapshots regenerate every 30 minutes; `generatedAt` says when.

### What comes back

```json
{"generatedAt": "...", "testName": "tg128 @ d16384 (c10)", "entries": [
  {"rank": 1, "modelName": "...", "runtime": "vLLM", "quantization": "NVFP4",
   "clusterSize": 1, "tokensPerSec": 411.47, "benchmarkId": "sub...",
   "submittedAt": "...", "userId": "...", "recipeType": "sparkrun"}
]}
```

## How to read it

**Rank is across all models.** The top of every cell is small models — a 350M
model reads 411 t/s at `d16384 c10`. A rank alone says little about a 35B MoE.
Filter `modelName` to the field that is actually comparable, and say which
ranking you are quoting.

**Rank our figure, do not eyeball it.** Count entries above it:

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)' \
| jq --argjson ours 141.46 '
    {cell: .testName, generated: .generatedAt, entries: (.entries|length),
     our_rank: ((.entries|map(select(.tokensPerSec > $ours))|length) + 1)}'
```

The same-model field, which is usually the honest comparison:

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)' \
| jq -r --arg m "Qwen3.6-35B-A3B-NVFP4" '.entries[]
    | select(.modelName | ascii_downcase | contains($m|ascii_downcase))
    | "\(.rank)\t\(.tokensPerSec)\t\(.runtime)\t\(.quantization)\tn=\(.clusterSize)\t\(.modelName)"'
```

**Only `tg` is comparable for us.** Every figure this campaign produces is
cold-cache — MTP defeats the prefix cache, so our hit rate is 0.0% while a
board entry runs warm. Measured price: `pp` 4.1x, `ttfr` 4.0x, `tg` +2.3%.
Never set our `pp` or `ttfr` beside a board `pp` or `ttfr`.

## The rule this skill exists to enforce

**Never compute a board margin from a stored scrape. Fetch the cell.**

On 2026-08-25 a result was reported as **+38.3% over the best board entry** at
`tg128 d16384 c10`. It was computed against five entries scraped two days
earlier into `docs/arena-recipe.md`. That cell holds 219. Read live, the same
figure ranks **27 of 220**, a same-model same-quant single-node entry reads
**236.97** against our 141.46, and the **102.31** the whole experiment was
aimed at is **rank 44** — mid-table, not the frontier.

Nothing about the measurement was wrong. The comparison set was.

A scraped figure ages the moment it is written. Snapshots regenerate every
half hour, and entries are submitted continuously. Treat any board number in
this repo as a date-stamped observation, never as the current standing.

## Setting a target

An Objective's target number comes from a live read at the cell it names, and
records the `generatedAt` alongside it. Quote both the all-model rank and the
same-model rank, because they answer different questions and only one of them
is usually the one being claimed.
