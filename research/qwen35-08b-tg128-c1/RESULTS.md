# Results — qwen35-08b-tg128-c1

Target cell: tg128 (c1). Arena reference: 121.19 ± 0.23 tok/s
(docs/arena-recipe.md). One row per benchmark run, appended after archiving
the run into `experiements/<benchId>/`.

| benchId | date | mutation | tg t/s | tg σ | pp t/s | pp σ | ttfr ms | verdict |
|---|---|---|---:|---:|---:|---:|---:|---|
| bench_59e87386d131 | 2026-08-21 | baseline (arena recipe verbatim) | 108.35 | 0.27 | 17777 | 4733 | 140.6 | baseline — repro gap −10.6% vs 121.19 |
| bench_129a556cce47 | 2026-08-21 | max_num_seqs=1 | 108.90 | 0.09 | 23195 | 266 | 102.3 | revert — +0.55 tg (~1.9σ, inconclusive); pp normalized to arena level, round-0 pp dip was anomaly |
| bench_1851f83d3653 | 2026-08-21 | max_model_len=8192 | 108.95 | 0.23 | 22455 | 477 | 107.0 | revert — +0.60 tg (~1.7σ, inconclusive); same-magnitude nudge as max_num_seqs=1 |
| bench_eb6e39538b5e | 2026-08-21 | --async-scheduling (candidate recipe) | 108.96 | 0.28 | 21274 | 243 | 110.0 | revert — +0.61 tg (~1.6σ); third straight ~+0.6 result, baseline suspect |
| bench_59e87386d131-rebaseline | 2026-08-21 | none (re-run incumbent) | 108.67 | 0.17 | 21580 | 402 | 107.2 | re-baseline — incumbent band 108.4–109.0; rounds 1–3 flags = no-ops |
| bench_4f9da10931e0 | 2026-08-21 | +ngram spec decode (n=4, lookup 2-4) | 112.61 | 1.94 | 24986 | 595 | 103.7 | KEEP — +3.9 tg over band; first winner; σ up (acceptance-dependent) |
| bench_0b93f5cfe862 | 2026-08-21 | spec decode n=8, lookup 8 | 111.68 | 1.75 | 20064 | 2482 | 117.0 | revert — −0.9 vs n=4; deeper drafts waste verify, ttfr worse |
| bench_03b5a04e760a-crash | 2026-08-21 | --async-scheduling + ngram (cpu) | — | — | — | — | — | crash — vLLM rejects async sched with CPU ngram; NGram GPU variant exists |
| bench_bf8f0926acb8 | 2026-08-21 | ngram_gpu + --async-scheduling | 124.88 | 20.69 | 15971 | 7083 | 196.9 | verify — per-run tg 153.7/114.9/106.0, one outlier run; repeat before verdict |
| bench_bf8f0926acb8-verify | 2026-08-21 | ngram_gpu + async (repeat) | 106.69 | 2.92 | — | — | 114.8 | revert — 6-run picture: 153.7 was outlier; combo worse than CPU ngram |
| bench_2e246bc5b280 | 2026-08-21 | +cudagraph FULL_AND_PIECEWISE | 107.54 | 5.64 | 20620 | — | 111.2 | revert — no gain, one 99.7 run; likely already default or spec-decode-limited |
| bench_185d381aeeb2 | 2026-08-21 | EPOCH: plain recipe on image 2026052903 (May) | 109.33 | 0.39 | 25816 | — | 105.3 | epoch test — same band as latest image; version regression ruled out |
| bench_4f9da10931e0-clocks | 2026-08-21 | none (incumbent re-run + clock telemetry) | 115.22 | 4.84 | — | — | — | instrumentation — SM capped 2405/3003 MHz under load, 43°C, P0; one run hit 122.0 |
| bench_7a7591590f70 | 2026-08-21 | +--disable-log-stats | 117.95 | 8.41 | 22113 | — | 105.6 | verify — runs 113.0/111.0/129.8, high-run outlier again; repeat pending |
| bench_7a7591590f70-verify | 2026-08-21 | --disable-log-stats (repeat) | 110.81 | 0.87 | — | — | — | revert — 6-run median ≈ incumbent; no-op |
| bench_0b07765e053f | 2026-08-21 | spec n=6, lookup 4 | 112.44 | 5.79 | — | — | — | revert — median 108.5 < incumbent ~112; n=4 optimal on n axis |
| bench_c2ed1165fcfc | 2026-08-21 | prompt_lookup_min=1 | 113.74 | 2.21 | — | — | — | revert — median 112.3 ≈ incumbent; no clear gain |
| bench_7270eca7baa2 | 2026-08-21 | --attention-backend flashinfer | 111.87 | 2.24 | 23134 | — | 102.6 | revert — median 111.4 ≈ incumbent; backend swap no-op |
