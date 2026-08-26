# Example — a real filled report

Excerpt from `.cache/results/2026-08-26-1733.md`, trimmed to show formatting.
Every number here is real. Use it to see exactly how the template resolves.

---

# Results vs leaderboard

Board read live **2026-08-26 17:33 UTC** via the `spark-board` skill.

## Legend

Everything prefixed **our-** is us. Everything prefixed **their-** is the
competition. Scores are `tg` tokens/sec — higher is better.

| column | meaning |
|---|---|
| **depth** | context already in the prompt before generation. `d0` = none, `d100000` = 100k tokens |
| **conc** | requests hitting the server at once. `c1` = one at a time, `c10` = ten |
| **our-h3 / h5 / h6** | what each of our three board-comparable runs scored. h3 = `max_num_seqs 10`, h5 = baseline, h6 = baseline + `temperature 0.6` |
| **our-best** | best of those three |
| **our-run** | which run produced it |
| **our-rank-all** | where our-best would place against **every model** on the board |
| **our-rank-peers** | where our-best would place among the **11 peer entries**. **This is the apples-to-apples number.** |
| **their-best** | best score of those 11 peers — click it to open their run |
| **their-rank-all** | where **that peer entry** places against every model |
| **delta** | our-best vs their-best. Positive and **bold** = we win |

Peer = same model `Qwen3.6-35B-A3B-NVFP4`, runtime vLLM, single node,
quantization NVFP4. 11 such entries in every cell.

## The grid

| depth | conc | our-h3 | our-h5 | our-h6 | our-best | our-run | our-rank-all | our-rank-peers | their-best | their-rank-all | delta |
|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|
| d0 | c1 | 99.91 | 96.59 | 89.45 | 99.91 | h3 | 29 | 7 | [118.91](https://spark-arena.com/benchmark/sub1782803609803) | #11 | -16.0% |
| d0 | c10 | 276.83 | 154.20 | 166.66 | **276.83** | h3 | 14 | **1** | [272.32](https://spark-arena.com/benchmark/sub1779001966608) | #14 | **+1.7%** |
| d8192 | c1 | 115.58 | 102.98 | 118.17 | **118.17** | h6 | 8 | **1** | [115.2](https://spark-arena.com/benchmark/sub1782731055332) | #12 | **+2.6%** |
| d16384 | c10 | 141.46 | 48.91 | 49.90 | 141.46 | h3 | 27 | 3 | [236.97](https://spark-arena.com/benchmark/sub1779001966608) | #10 | -40.3% |
| d100000 | c10 | 5.49 | 5.35 | 5.32 | 5.49 | h3 | 109 | 12 | [116.26](https://spark-arena.com/benchmark/sub1779001966608) | #4 | -95.3% |

Note what the four columns do together on the `d16384 c10` row: we score
141.46, which is 27th of everyone but **3rd of 11 peers**, while the peer
leader scores 236.97 and is 10th of everyone. Two ranks, two questions.

## Wins: 2 of 28

| cell | our-best | their-best | delta | our-rank-peers |
|---|---:|---:|---:|---|
| d0 c10 | 276.83 | [272.32](https://spark-arena.com/benchmark/sub1779001966608) | **+1.7%** | **1 of 12** |
| d8192 c1 | 118.17 | [115.20](https://spark-arena.com/benchmark/sub1782731055332) | **+2.6%** | **1 of 12** |

Both inside our own run-to-run scatter. Ties, not wins.

## Our best board placings

| cell | our-best | our-rank-all |
|---|---:|---|
| d65535 c1 | 103.27 | **2** |
| d100000 c1 | 91.02 | **6** |

Four top-10 board placings, all at **c1** — and no round ever targeted c1
placings.

## Who we are actually up against

Seven entries lead all 28 cells. One leads eleven of them.

| entry | cells led |
|---|---|
| [sub1779001966608](https://spark-arena.com/benchmark/sub1779001966608) | **11** — every c5/c10 from d16384 up, plus d0/d4096/d8192 c10 |
| [sub1782803609803](https://spark-arena.com/benchmark/sub1782803609803) | 5 |

## Shape

- **c1 is our column** — 7 of 7 within 16%, four within 10%, two within 0.3%.
- **c2 is uniformly weak** — −9% to −56%, our-rank-peers 5–10 in every cell.
- **c5/c10 above d32768 collapses** — our-rank-peers 12 of 12, −76% to −95%.

## Note

The Objective targeted 102.31 — rank 44 in its cell, −40% behind the peer
leader. The measurements were sound; the target was not.
