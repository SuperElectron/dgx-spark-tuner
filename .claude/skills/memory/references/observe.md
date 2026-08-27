# Sweeping the box

Every benchmark measures the box through a model. The sweep measures the box.

It exists because the things that move underneath an experiment — a driver
bump, a reboot that dropped persistence mode, a governor gone back to
`powersave`, a new image digest under the same `:latest` tag — change no figure
until they change every figure, and by then nobody knows which run was the
first one after the change. A dated `[ENV]` line closes that gap.

Sweep before an experiment opens, after a reboot or an image pull, and when a
run's figures moved with no recipe change. Never while a benchmark is running.

## Standing rules

- **Read-only on the box, always.** Clocks, power policy, driver, kernel and
  `apt` are Mat's decisions. The sweep measures them and records what it saw.
  It never sets, resets, installs, or reboots anything.
- **No benchmarks.** Nothing here starts an engine, serves a model, or loads
  the GPU. If a question needs a run, it belongs to `experiment`.
- **Never sweep while the card is busy.** `sweep.sh` refuses (exit 3) when
  `nvidia-smi --query-compute-apps` returns any process. A reading taken under
  someone else's load is not a reading at rest, and the sweep's own ssh is a
  guest on a card a benchmark is timing.
- **Write only what moved.** Compare the sweep against the last `[ENV]` for
  this box. Unchanged fields are already in the store with an earlier and
  better date. One memory per change, none for a quiet sweep.
- **Record the observation, not the verdict.** "governor is `powersave`, was
  `performance` on 2026-08-19" is the memory. "so the box is misconfigured, set
  it back" is not — that is a decision, and it is Mat's.
- **The hostname lives in `.claude/box.json`.** The script reads it there. It
  is gitignored, so it is never hardcoded and never quoted into a memory beyond
  its short alias.

## The sweep

```bash
.claude/skills/memory/scripts/sweep.sh
```

One ssh, one screenful: driver and CUDA, kernel and OS, current and max clocks,
power draw and limit, idle temperature, persistence mode, perf state, CPU
governor, the throttle bitmask and any active clock-event reason, RAM, disk,
uptime, and the digests of the vLLM images present alongside what is running.

Exit 2 is the box unreachable or `box.json` incomplete; exit 3 is the card
busy. Neither is a reason to sweep anyway.

## Then write what changed

```bash
.claude/skills/memory/scripts/recall.sh --list box:spark-6f0e 50
```

`--list` needs no embedder — never start it for a sweep; it shares the card
with every benchmark. Read back the last `[ENV]` lines for this box, diff them
against the sweep by eye, and write one memory per field that moved:

```bash
.claude/skills/memory/scripts/remember.sh \
  "[ENV] driver 580.173.02 (was 580.65.06 on 2026-08-19); kernel 6.17.0-1029-nvidia unchanged" \
  box:spark-6f0e \
  --meta date=2026-08-26 --meta scope="idle sweep, no run in flight" \
  --meta epoch.image=sha256:4894c3f1
```

`[ENV]` requires `date` and `scope`. `scope` says what the reading covers — an
idle sweep, one host, one moment — because an environment fact with no scope
cannot be checked later.

## `memory` is the only producer of `epoch.image`

`epoch.image` is **the digest of the image the box actually ran**, and the
sweep is the only thing that can supply it. The sweep's `images` block is
`docker images --digests`; its next line is `docker ps`, which names the image
the running container was started from. Take the digest of that repository:tag
pair — today `ghcr.io/spark-arena/dgx-vllm-eugr-nightly:latest` — and nothing
else. That is the artifact that executed, so it is what an epoch break is
judged on. Stamp it whenever the sweep saw it.

Do not confuse it with `epoch.build_source`, the upstream digest sparkrun built
that image *from* — `container_dev_sparkrun_source_digest`. That one lives in
run archives, not in the sweep, and `experiment` is its producer. The sweep
does not print it, so a sweep normally leaves it unset. Never fill either key
from the other. See [the two image keys](write.md).

`epoch.vllm` / `epoch.flashinfer` likewise only when a run archive gave them;
the sweep alone does not know them.

`box:` is the entity: a hardware fact belongs to the hardware, at the widest
scope it is true for. Writing it directly is not a breach of the promotion rule
in [tiers.md](tiers.md) — that rule bounds what a round may promote, and a
sweep belongs to no round, which is exactly why it refuses to run inside one.

A repeated sweep that finds nothing changed writes nothing. If it does write
the same sentence twice, the store's sha256 on the text returns the first
memory's id instead of a second row, so a nervous re-sweep costs nothing.

## Detail

- [env-fields.md](env-fields.md) — every field the sweep prints, what moves it,
  and what a change under it does to a figure.
