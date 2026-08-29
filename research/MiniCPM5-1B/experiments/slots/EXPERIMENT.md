# slots — the control on LFM2.5-350M's slots result

## Objective

This experiment is not trying to win a cell, and saying so is the point.

`tg128 (c10)` at d0 is held by our own `LFM2.5-350M` submission
`sub1787965681732` at 2044.66 t/s. `MiniCPM5-1B`'s best published entry is
704.63 (`sub1787650717319`, rank 5 in that cell). A 1B model will not pass a
350M model by a factor of three on decode throughput, so no configuration of
this recipe takes the cell.

What it is for: `LFM2.5-350M` gained +96% at `tg128 d0 c10` from lifting
`max_num_seqs` 4 -> 16. If that mechanism is what it claims — admission, slots
that were never filled — then a model whose recipe **already runs
`max_num_seqs: 64`** has nothing left to gain from more of them, and should not
move. `sub1787650717319` is the only top-10 entry in that cell already at 64.

Objective: establish whether the slots mechanism is spent on a model that has
already spent it.

Reached when: an arm that adds slot capacity is measured against our own
control on this model and the difference is stated against this cell's scatter.

## Strategy

The campaign plan calls this track "the control" and says it is only worth
running once Track 1 has a result to interpret. Track 1 has one:
`max_num_seqs` 4 -> 16 took `tg128 d0 c10` from 1021.87 to 2197.72 on
LFM2.5-350M, and the engine log showed the mechanism directly — at `mns 4` the
scheduler held `Running 4 / Waiting 6` of ten offered requests.

This model cannot show that pattern. At `mns 64` and an offered concurrency of
10, nothing queues: our control read `max running 10, max waiting 6` over only
3 frames, and the waiting figure is prompt arrival, not admission starvation.

So the prediction is a null, and a null is the useful outcome. If adding
capacity moves this model materially, the admission account of Track 1 is
incomplete and something else — graph shape, memory pressure — was doing work
we attributed to slots.

Two facts from the control worth carrying into any arm. Prefix cache hit rate
read **31.5%** here, against 0.0% on both LFM2.5-350M and Qwen3.6-35B-A3B — the
first non-zero cache we have measured on this box, so this model's figures are
not cold-cache comparable to the rest of the tree. And its cudagraph capture
list runs `[1 ... 128]`, 19 sizes, so 10 is not an exact capture size here
either.

Measured scatter, this model, `tg128 (c10)`:

    d0:     cv 0.1% at runs=3   (667.05, sd 0.96)
    d4096:  cv 0.3% at runs=3   (474.22, sd 1.43)

Among the quietest cells measured on this box. A 3% difference is readable
here; treat anything under 1% as a tie.

## Held

- Box `spark-6f0e`, and the container image digest recorded at h1's first run.
- Checkpoint `openbmb/MiniCPM5-1B`, unmodified.
- Runtime vLLM. Cells are `tg128` at d0 and d4096, concurrency 10.
- Grid and cell order fixed for every arm: d0 then d4096, `runs: 3`.
- Only `tg` is compared.

Deliberately not held: `max_num_seqs`, `max_model_len`,
`max_num_batched_tokens`, `gpu_memory_utilization`.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | a model already at `max_num_seqs: 64` gains nothing from more slot capacity | |

## Conclusion

Open.
