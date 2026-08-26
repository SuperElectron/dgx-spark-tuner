---
name: spark-board
description: Read the live Spark Arena leaderboard for a cell — the whole ranked field, not a scrape. Use before setting an Objective's target number, before claiming a result beats the board, and before publishing anything.
---

# spark-board

## Role

The board is the yardstick every experiment is judged against. This skill
reads it live.

It only ever reads. The endpoint has no write path, and **nothing is ever
submitted to Spark Arena**.

Use it when:

- opening an experiment, to set the Objective's target from the real frontier
- concluding a round that claims to beat the board
- before publishing any figure anywhere

## The one rule

**Never compute a board margin from a stored scrape. Fetch the cell.**

A cell holds ~200 entries and regenerates every 30 minutes. Five entries
copied into a doc three days ago is not the board, and treating it as the
board has already produced a wrong published-facing claim — see
[compare-results.md](references/compare-results.md) for what it cost.

Any board number stored in this repo is a date-stamped observation, never the
current standing.

## How to use it

1. **Pull the cell.** One `curl`, one JSON document, whole ranked field.
   → [pull-results.md](references/pull-results.md) — endpoint, the cells that
   exist, the response shape, benchmark links, and the two gotchas (Cloudflare
   403s `Python-urllib`; a missing cell answers HTTP 200 with an error body).

2. **Compare against the peer set, not the board.** The board mixes every
   model, so its top is small models. Rank against same model, same runtime,
   same cluster size, same quantization.
   → [compare-results.md](references/compare-results.md) — the peer filter,
   `jq` for both ranks, why only `tg` is comparable for us, and sizing a claim
   against our own scatter.

3. **Write it up so it cannot be misread**, to
   `.cache/results/<YYYY-MM-DD-HHMM>.md` — one file per read, never
   overwriting an earlier one, so the series records whether we are gaining
   or losing ground.
   → [document-results.md](references/document-results.md) — `our-`/`their-`
   column naming, linking competitors, and what must never appear in a
   comparison table.

## Quick reference

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)'
```

```
metrics      tg128  tg32  pp2048  pp4096  ctx_tg  ctx_pp
concurrency  1 2 4 5 10
depth        appended as " @ d<N>"; omit it entirely for the depth-0 cell
```

Peer set for this model:

```
modelName == "Qwen3.6-35B-A3B-NVFP4" and runtime == "vLLM"
  and clusterSize == 1 and quantization == "NVFP4"
```

`tg` only. Our `pp` and `ttfr` are cold-cache and run 4x low, so they are not
comparable to any board figure.
