---
name: spark-board
description: Read the live Spark Arena leaderboard for a cell — the whole ranked field, not a stored scrape. Use before setting an Objective's target number, before claiming a result beats the board, and before publishing any figure.
when_to_use: Choosing an Objective's target; concluding a round that claims to beat the board; writing up how our results compare; any question about board standings, ranks, competitors, or whether a cell is contested.
allowed-tools: Bash(curl -s --get 'https://spark-arena.com/*) Bash(curl -s --get https://spark-arena.com/*) Bash(jq:*) Bash(mkdir:*) Bash(date:*) Read Write
disallowed-tools: Bash(.claude/skills/memory/scripts/memory.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(.claude/skills/memory/scripts/forget.sh:*) Bash(.claude/skills/memory/scripts/prune-round.sh:*) Bash(.claude/skills/memory/scripts/record-run.sh:*) Bash(.claude/skills/memory/scripts/update.sh:*)
---

# spark-board

The board is the yardstick every experiment is judged against. Read it live.

This skill only reads. The endpoint has no write path, and **nothing is ever
submitted to Spark Arena**.

**Memory:** nothing. No step here touches the store — the board is a live HTTP
endpoint and the output goes to `.cache/results/`. The `curl` grant is pinned to
`spark-arena.com` for that reason: a bare `curl` also reaches the store's own
`http://127.0.0.1:8888/memories`, which is a write and delete path. Matrix:
[../memory/references/access.md](../memory/references/access.md).

## Standing rules

- **Fetch the cell. Never compute a margin from a stored scrape.** A cell
  holds ~200 entries and regenerates every 30 minutes. Board numbers written
  into this repo are date-stamped observations, never current standings.
- **Rank against the peer set, not the whole board.** The board mixes every
  model, so its top is small ones. Peers for this model:
  `modelName == "Qwen3.6-35B-A3B-NVFP4"`, `runtime == "vLLM"`,
  `clusterSize == 1`, `quantization == "NVFP4"`.
- **Report both ranks when they differ**, and say which set each is against.
- **`tg` only.** Our runs are cold-cache, so our `pp` and `ttfr` read ~4x low
  and are comparable to nothing on the board.
- **A delta smaller than the cell's own run-to-run scatter is a tie**, not a
  win. Check `measure.spread` before calling a margin real.

## The call

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)'
```

Metrics `tg128 tg32 pp2048 pp4096 ctx_tg ctx_pp`; concurrency `1 2 4 5 10`;
depth appended as ` @ d<N>`, omitted entirely for the depth-0 cell.

## Detail

- [references/pull-results.md](references/pull-results.md) — every cell that
  exists, response shape, benchmark links, whole-grid loop, and the two
  gotchas (Cloudflare 403s `Python-urllib`; a missing cell answers HTTP 200
  with an error body).
- [references/compare-results.md](references/compare-results.md) — `jq` for
  both ranks and the peer leader, why `tg` is the only comparable metric, and
  what reasoning from a scrape already cost.
- [references/document-results.md](references/document-results.md) — write to
  `.cache/results/<YYYY-MM-DD-HHMM>.md`, one file per read, never
  overwriting. Copy [assets/results-example.md](assets/results-example.md)
  and replace the numbers.
