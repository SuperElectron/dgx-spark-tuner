# Writing a memory

```bash
.claude/skills/memory/scripts/remember.sh "<text>" <entity> [--meta k=v ...]
```

Every write is stamped `metadata.schema = "1"`. The entity is stored in the
metadata, and the text's sha256 is the server's dedupe key — the same text
posted twice returns the first memory's id rather than writing a second.

As of 2026-08-26 the store holds 980 records. 881 carry the schema-1 stamp; the
other 99 predate the contract and carry no stamp at all — 83 PARTIAL (their
`basis` was not recoverable), 9 LEGACY, 7 legacy `[OBSERVATION]`s. Treat an
unstamped record as a claim you cannot filter and cannot date by metadata: read
its `created_at` and judge it by hand.

## Why the metadata exists

A memory is a record of what one benchmark measured, under one protocol, on one
day. Before the contract, 14% of the store carried a bench id, 25% a date, and
none carried quant, runtime, cell or test type. A line like that cannot be
judged: it is a claim with no way to ask whether it applies to your cell.

The contract makes that structural. The fields are metadata, not prose, so
`recall.sh` can filter on them and print them back in every scan line.

## The four markers

The leading marker in the text picks the class, and the class decides which
fields are required.

| marker | what it is | requires |
|---|---|---|
| `[OBSERVATION]` | what one benchmark measured | `model test depth conc bench date` |
| `[ENV]` | an environment fact: image, driver, clock policy, a box quirk | `date scope` |
| `[LESSON]` | a takeaway not tied to one row | `date basis` |
| `[IDEA]` | a candidate intervention | `date evidence` |

`[OBSERVATION]` names one cell because a RECORD writes one run, and a run
measures one cell. A claim spanning several cells, or fusing a `pp` and a `tg`
figure, cannot name a single `test`/`depth`/`conc` and is not an observation —
it is a `[LESSON]`, and its `basis` cites the bench ids it rests on.

`[EXPERIMENT]` is **retired** and rejected. It was the old catch-all: it named
the activity rather than the epistemic status, so measurements and judgements
were written under one marker and neither could be filtered from the other.
Write what a benchmark measured as `[OBSERVATION]`; write what you concluded
from several as `[LESSON]`, with `basis=` naming what it rests on.

Text with no recognised marker is rejected.

## Meta keys

All values are stored as strings. Dotted keys nest. An unknown key exits 2.

```
date model quant runtime test depth conc runs bench protocol
epoch.image epoch.build_source epoch.vllm epoch.flashinfer
scope basis evidence
```

### Dotted keys nest — the stored shape

`--meta epoch.vllm=e85d1b69` is **not** a key called `"epoch.vllm"`. The dot is
a path: the value lands inside an `epoch` object. Every writer emits this shape
— `remember.sh` and anything else that POSTs — and it is the shape
`recall.sh --filter epoch.vllm=…` is built around.

```json
{
  "entity": "model:nvidia/Qwen3.6-35B-A3B-NVFP4",
  "schema": "1",
  "test": "tg128", "depth": "16384", "conc": "10",
  "epoch": {
    "build_source": "sha256:1f2e…",
    "vllm": "e85d1b69",
    "flashinfer": "9c40a7c"
  }
}
```

A flat literal `"epoch.vllm": "e85d1b69"` is wrong and must not be written. It
is nonetheless *readable*: `recall.sh --filter` tries the flat literal key first
and falls back to the nested path, so a stray flat key from some future writer
is still reachable rather than silently invisible. That tolerance is a safety
net for readers, not a licence for writers.

- **`depth` and `conc` are the cell** — carried as two fields, never as a single
  `cell` key. `--meta depth=16384 --meta conc=10` prints back as `d16384 c10`.
- **`test`** is the test type: `tg128`, `pp2048`, `ctx_tg` — the thing the
  figure measures. A number without it is not comparable to anything.
- **`bench`** is the `bench_*` id, so the figure can be traced to its archive.
- **`protocol`** names the measurement regime — `exact_tg`, `temperature 0`,
  pinned prompt. A figure taken before a protocol change is a different
  quantity, not an older version of the same one.
- **`epoch.*`** stamp the software the figure was taken under. An image or vLLM
  change is a new epoch; stamp it and a later round can tell whether comparing
  across it is legitimate. `epoch.vllm` and `epoch.flashinfer` are the two build
  commits. The two image keys are **not** interchangeable — see below.

### The two image keys

They name two different objects, and one is not a stand-in for the other.

| key | names | who can supply it |
|---|---|---|
| `epoch.image` | the image the box **actually ran** — the digest of `ghcr.io/spark-arena/dgx-vllm-eugr-nightly`, read off the running container | this skill's box sweep, and nothing else — see [observe.md](observe.md) |
| `epoch.build_source` | the **upstream image sparkrun built from** — `container_dev_sparkrun_source_digest`, a digest of `docker.io/eugr/spark-vllm`, named by the sibling keys `..._source_image` and `..._source_tag` | anything reading a run archive: `experiment`, and the records rebuilt from the archives |

`epoch.image` is the one an epoch break is judged on. It is the artifact that
executed, so it is what "an image change is a new epoch, re-measure the
incumbent" is about. `epoch.build_source` moves for its own reasons — a rebuild
off the same upstream digest changes the run image and not the build source,
and a re-tagged upstream changes the build source without necessarily changing
what ran.

A record may carry one, both, or neither. **A missing key is never filled with
the other.** Writing the build-source digest under `epoch.image` makes every
comparison against a real run-image digest read as an epoch break that did not
happen — which is worse than the silence, because a wrong field is believed and
an absent one is not. The archives record no run-image digest anywhere, so
records regenerated from them carry `epoch.build_source` only, and that is
correct.
- **`scope`** on `[ENV]`, **`basis`** on `[LESSON]`, **`evidence`** on `[IDEA]`
  — each says what the claim rests on, so a reader can check it rather than
  take it.

## Exit codes

| code | meaning |
|---|---|
| 0 | written, **or** the service was unreachable |
| 2 | usage error, or an unknown `--meta` key |
| 3 | refused — retired class, absent or unrecognised marker, or missing required fields (the message names which) |

Exit 0 on an unreachable store is deliberate: a down memory service must never
block research. It is also why stderr matters — `remember: NOT written` on exit
0 means the line is gone. A refusal is not the service being down; that is 3.

## Examples

```bash
.claude/skills/memory/scripts/remember.sh \
  "[OBSERVATION] max_num_seqs 4→64: tg flat within ±3% across all five, so single-stream decode does not use the extra slots" \
  round:decode-tg/h1 \
  --meta date=2026-08-22 --meta model=Qwen3.6-35B-A3B-NVFP4 --meta quant=NVFP4 \
  --meta runtime=vLLM --meta test=tg128 --meta depth=0 --meta conc=1 \
  --meta runs=5 --meta bench=bench_2ebcb63db398

.claude/skills/memory/scripts/remember.sh \
  "[LESSON] max_num_seqs governs decode only when concurrency exceeds 1; at c1 it is inert" \
  flag:--max-num-seqs \
  --meta date=2026-08-22 --meta basis="decode-tg h1 c1 flat, h2 c10 2.89x" \
  --meta model=Qwen3.6-35B-A3B-NVFP4 --meta test=tg128
```

## Choosing an entity

Pick the **widest scope the observation is actually true for**. That is what
makes it findable from another experiment. Too narrow and it is invisible; too
wide and it is a claim you have not earned.

```
round:<exp>/<hN>    tier 1 — this round only, e.g. round:decode-tg/h1
model:<hf-id>       this exact checkpoint
family:<name>       across a family — family:qwen3.6-35b-a3b spans NVFP4/FP8/BF16
stack:<runtime>     the serving stack, any model — stack:vllm
box:<alias>         this hardware, any model or stack — box:spark-6f0e
flag:<vllm-flag>    this flag — flag:--async-scheduling
```

`round:` is transient by construction and is pruned at round close; everything
else is durable and is only reached by promotion. See
[tiers.md](tiers.md).

## What the text must not be

- A standing verdict. `WIN 4.6x` expires the moment anything is re-measured.
  `WIN 4.6x over board 28.11 (scraped 2026-08-21)` survives, because it states
  its basis and its date.
- A restatement of prose written elsewhere. The line stands alone; recall prints
  the line and its config, nothing else.
- A summary of several runs written as if it were one measurement. That is a
  `[LESSON]`, and it needs `basis=`.
- Silent about which arm it measured. A bench that holds two arms in one cell —
  two response sizes, say — yields records identical in metadata and different
  only in the figure, because `test` does not name the arm. Name the arm in the
  text.
