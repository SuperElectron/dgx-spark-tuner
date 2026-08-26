#!/usr/bin/env python3
"""Read the live Spark Arena leaderboard.

The site is a Next.js app whose leaderboard reads one static snapshot per
cell. That endpoint serves plain JSON to any client — no login, no key, no
user-agent games. This only ever reads.

    board.py cells                          # what cells exist
    board.py tg128 @ d16384 --conc 10       # the whole cell, ranked
    board.py tg128 @ d16384 --conc 10 --model qwen3.6-35b
    board.py tg128 @ d16384 --conc 10 --ours 141.46

`--ours` inserts our figure into the ranking so the standing is read off the
board rather than argued from a partial scrape. Doing that by hand is how the
+38.3% claim of 2026-08-25 happened: five entries had been scraped from a cell
holding two hundred.
"""

import argparse
import json
import sys
import urllib.parse
import urllib.request

SNAPSHOT = "https://spark-arena.com/static/snapshot/test"

DEPTHS = [128, 512, 1024, 2048, 4096, 8192, 16384, 28672, 32768, 65535,
          65536, 100000, 128768, 131072, 163840, 190000, 200000, 259000,
          262144, 524288]
METRICS = ["tg128", "tg32", "pp2048", "pp4096", "ctx_tg", "ctx_pp"]
CONCURRENCIES = [1, 2, 4, 5, 10]


def fetch(test: str, conc: int) -> dict:
    """One cell. `test` is like 'tg128 @ d16384'; the board appends (cN)."""
    name = f"{test} (c{conc})"
    url = f"{SNAPSHOT}?{urllib.parse.urlencode({'test': name})}"
    # Cloudflare 403s the default Python-urllib agent; curl's own default is
    # fine, so this is agent filtering rather than a block on automation.
    req = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "curl/8.7.1",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read().decode()
    if not body.lstrip().startswith(("{", "[")):
        raise SystemExit(f"not JSON — no such cell? {name}")
    return json.loads(body)


def render(snap: dict, model: str | None, ours: float | None, limit: int):
    entries = snap.get("entries", [])
    print(f"{snap.get('testName')}  ·  {len(entries)} entries  "
          f"·  generated {snap.get('generatedAt')}")

    shown = entries
    if model:
        needle = model.lower()
        shown = [e for e in entries if needle in e.get("modelName", "").lower()]
        print(f"filtered to {len(shown)} matching {model!r} "
              f"(rank column is the board's, across all models)")

    if ours is not None:
        better = sum(1 for e in entries if e.get("tokensPerSec", 0) > ours)
        print(f"\nours {ours}  ->  would rank {better + 1} of {len(entries) + 1} "
              f"overall")
        if model:
            mb = sum(1 for e in shown if e.get("tokensPerSec", 0) > ours)
            print(f"{'':>13}  {mb} matching entries beat it")

    print()
    print(f"{'rank':>4}  {'tok/s':>9}  {'runtime':<9} {'quant':<14} {'n':<3} model")
    inserted = False
    for e in shown[:limit]:
        tps = e.get("tokensPerSec", 0)
        if ours is not None and not inserted and tps < ours:
            print(f"{'->':>4}  {ours:>9.2f}  {'OURS':<9} {'':<14} {'':<3} "
                  f"(not submitted)")
            inserted = True
        print(f"{e.get('rank'):>4}  {tps:>9.2f}  {e.get('runtime',''):<9} "
              f"{e.get('quantization',''):<14} {e.get('clusterSize',''):<3} "
              f"{e.get('modelName','')}")
    if ours is not None and not inserted:
        print(f"{'->':>4}  {ours:>9.2f}  {'OURS':<9} {'':<14} {'':<3} "
              f"(below the {len(shown[:limit])} shown)")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("test", nargs="*", help="e.g. tg128 @ d16384")
    p.add_argument("--conc", type=int, default=1)
    p.add_argument("--model", help="substring filter on model name")
    p.add_argument("--ours", type=float, help="our figure, ranked into the board")
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--json", action="store_true", help="raw snapshot")
    a = p.parse_args()

    joined = " ".join(a.test)
    if joined == "cells" or not joined:
        print("metrics     :", " ".join(METRICS))
        print("depths      :", " ".join(f"d{d}" for d in DEPTHS))
        print("concurrency :", " ".join(str(c) for c in CONCURRENCIES))
        print('\nbare "tg128", "pp2048", "pp4096" also exist (no depth).')
        return

    snap = fetch(joined, a.conc)
    if a.json:
        json.dump(snap, sys.stdout, indent=2)
        return
    render(snap, a.model, a.ours, a.limit)


if __name__ == "__main__":
    main()
