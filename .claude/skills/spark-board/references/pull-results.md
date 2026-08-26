# Pulling a cell

## The endpoint

The leaderboard is a Next.js app. Its table comes from one static JSON
snapshot per cell:

```
https://spark-arena.com/static/snapshot/test?test=<METRIC> @ d<DEPTH> (c<CONC>)
```

One request returns the whole ranked field. No login, no key, no pagination,
and **no write path** — nothing can be submitted through it.

```bash
curl -s --get 'https://spark-arena.com/static/snapshot/test' \
  --data-urlencode 'test=tg128 @ d16384 (c10)'
```

## Two gotchas that cost time

- **Cloudflare 403s the default `Python-urllib` user-agent.** `curl`'s own
  default works. Send any real user-agent from other clients. A 403 here is
  agent filtering, not a block on automation, and not a reason to stop.
- **A cell that does not exist answers HTTP 200** with
  `{"error":"Leaderboard test not found"}`. Check the body, not the status. A
  body starting `<!DOCTYPE` means the path was wrong, not the cell.

## What exists

```
metrics      tg128  tg32  pp2048  pp4096  ctx_tg  ctx_pp
depths       128 512 1024 2048 4096 8192 16384 28672 32768 65535 65536
             100000 128768 131072 163840 190000 200000 259000 262144 524288
concurrency  1 2 4 5 10
```

`tg128`, `pp2048` and `pp4096` also exist bare, with no ` @ d<DEPTH>` — that
form is the depth-0 cell.

Snapshots regenerate every 30 minutes; `generatedAt` says when.

## What comes back

```json
{"generatedAt": "...", "testName": "tg128 @ d16384 (c10)", "entries": [
  {"rank": 1, "modelName": "...", "runtime": "vLLM", "quantization": "NVFP4",
   "clusterSize": 1, "tokensPerSec": 411.47, "benchmarkId": "sub...",
   "submittedAt": "...", "userId": "...", "recipeType": "sparkrun"}
]}
```

`rank` is the board's own, across all models.

## Linking to an entry

```
https://spark-arena.com/benchmark/<benchmarkId>
```

Renders that submission's page. A bogus id returns an error page, so a
rendering page means the id is real.

## Pulling a whole grid

Our grid is 7 depths x 4 concurrencies. Depth 0 is the bare metric name:

```bash
for d in 0 4096 8192 16384 32768 65535 100000; do
  for c in 1 2 5 10; do
    [ "$d" = 0 ] && T="tg128 (c$c)" || T="tg128 @ d$d (c$c)"
    curl -s --get 'https://spark-arena.com/static/snapshot/test' \
      --data-urlencode "test=$T" -o "cell_${d}_${c}.json"
  done
done
```

Cache to disk first, then analyse. Re-fetching per question wastes requests
and risks mixing two snapshot generations into one table.
