# Recalling

```bash
scripts/recall.sh "<query>" [entity] [k]      # semantic — needs the embedder up
scripts/recall.sh --list [entity] [limit]     # no embedder needed
scripts/recall.sh --get <id>                  # one full record, as JSON
scripts/recall.sh ... [--json] [--filter k=v,k=v]
```

The positional forms are unchanged from before the contract. Flags may appear
anywhere on the line.

## Scan, then get

The default output is a **scan** format, one line per memory:

```
<id>\t<entity>\t<text>  · model quant runtime test dDEPTH cCONC runs=N bench date
```

The config suffix is appended to the text and omits fields that are absent, so
legacy metadata-free memories print exactly as they always did. The suffix is
there so a scan can be triaged without a second call — it is not there so a
decision can be made from it.

**No decision rests on a summary line.** `--get <id>` before any lever choice,
any recipe, any hypothesis. The full record carries `protocol` and `epoch.*`,
which the scan line does not, and those are usually what decides whether the
memory transfers.

`--get` is client-side: the store has no get-one route, so the script pulls the
list and picks the id out of it. A missing id prints to stderr and exits 0.

`--json` prints full records including metadata as an array, and composes with
`--list`, with search, and with `--filter`.

## Filters

`--filter` is a client-side AND over metadata, comma-separated, dotted keys
supported.

**`k=v` matches only records where `k` is present and equal. A record missing
`k` is excluded, not passed through.** There is no "unknown counts as a match".
That has one practical consequence worth stating plainly: a filtered scan cannot
see a legacy memory (pre-contract writes carry only `sha256` and `entity`) and
cannot see a cross-model one (a `stack:vllm` lesson that deliberately carries no
`model=` because the claim spans models). Only the wide unfiltered form sees
everything the store holds:

```bash
scripts/recall.sh --list '' 2000 | head -60
scripts/recall.sh --list '' 2000 | grep -i '<the lever, by name>'
```

So filters narrow a result you have already looked at. They are never the first
look.

```bash
scripts/recall.sh --list '' 2000 --filter model=Qwen3.6-35B-A3B-NVFP4,depth=16384,conc=10
scripts/recall.sh --list --filter epoch.vllm=abc1234
scripts/recall.sh "does max_num_seqs help decode" stack:vllm 20 --filter test=tg128
```

The useful ones in practice:

- `depth=,conc=` — same cell as yours. Anything else needs a transfer argument.
- `test=` — same quantity. A `tg32` figure is not a slow `tg128` figure.
- `epoch.image=,epoch.vllm=` — same epoch. Across an epoch, re-measure the
  incumbent before comparing. `epoch.image` is the image the box ran and only
  `observe` writes it, so most `[OBSERVATION]`s carry `epoch.build_source`
  instead — a different object, never a substitute. Filtering one against the
  other matches nothing; see [write.md](write.md).
- `date=` — combined with a scan of the research tree, this is how you find out
  whether a memory predates the experiment that would have refuted it. Only
  schema-1 writes carry it, so this filter cannot reach a legacy record at all;
  for those, date from `created_at` in the full record.

## QUESTION THE MEMORY

A memory is evidence about **that** measurement, not about yours. It is a
reason to look. It is not evidence for your cell until you have said why it
transfers.

The failure this discipline exists to prevent: two memories said "match
`max_num_seqs` to probe concurrency, raise both knobs together". Both were
written **before** the concurrency experiment ran. Neither carried a cell.
`h1` took them at face value, spent a round on `max_num_batched_tokens` and got
the sign backwards. The dates alone would have flagged them as pre-experiment;
the missing cell would have flagged them as untransferable. Reading the line was
not recall. Reading the record would have been.

Before you let one shape a hypothesis, answer:

- **What cell was it measured at?** A finding at `d16384` may not transfer to
  `d0`, and the reason is usually mechanical. Worked example: a memory recorded
  `tg32` reading faster than `tg128` at `d16384`. At depth, every generated
  token is KV that every later step reads back, so longer generation costs more
  traffic — no transient needed. At `d0` that mechanism is absent. The memory
  was measuring KV growth wearing a generation-length label.
- **What date, and what ran after it?** A memory written before the experiment
  that tested its claim is a hypothesis someone held, not a result. Check the
  date against the research tree before you spend a round on it. Two fields
  carry a date and they are not the same field: **`created_at`** is the store's
  own timestamp, present on every record, and it is the date of record;
  **`metadata.date`** is stamped by schema-1 writes only, and is absent on every
  pre-contract memory — which is also why the scan line's config suffix, which
  reads `metadata.date`, shows no date for them. `--get` and read `created_at`.
- **What epoch and protocol?** Image, vLLM and flashinfer commits, and the
  measurement regime. A figure taken before `exact_tg`, `temperature 0` or a
  pinned prompt is a different quantity. If the embedder was resident on the
  card, it was sharing the GPU with the benchmark.
- **What objective did it serve?** A round chasing throughput records spread
  differently from one chasing stability. The figure may be sound and the
  emphasis still misleading.
- **Is it an observation or a judgement?** `[OBSERVATION] bench_X measured
  129.32 at runs=3` stays true forever. A `[LESSON]` is only as good as its
  `basis=`; read the basis, not the sentence.
- **Does a contradiction mean one is wrong?** Not necessarily. Two memories
  disagreeing about the same cell usually means different epochs or different
  protocols. That is a reason to run the experiment, not to pick the one you
  prefer.

## The embedder

Semantic search needs `memory.sh start`; `--list`, `--get` and `--filter` do
not. The embedder is a vLLM instance on the same GB10 as the benchmarks, so it
must be down for every run — `memory.sh stop` before dispatching one, and
`stop` is idempotent, so assert it rather than tracking it.

Prefer `--list` + `--filter` when you know the cell you are asking about. Reach
for semantic search when you do not know what to ask for by name.
