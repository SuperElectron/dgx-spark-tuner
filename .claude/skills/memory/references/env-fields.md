# What the sweep reads

Each row: the field, what a healthy idle box shows, and what a change under it
does to a figure. The right-hand column is why the field is swept at all — a
field nothing can move is not worth a memory.

| field | at rest | what a change does |
|---|---|---|
| `driver` / `cuda` | 580.173.02 / 13.0 | new kernels, new scheduling, new bugs. Comparing across a driver bump is comparing across an epoch. |
| `kernel` / OS | 6.17.0-1029-nvidia, Ubuntu 24.04 | an `apt` upgrade or a reboot into a different kernel changes the whole host. |
| `clocks now / max` | ~200 MHz idle, 3003 MHz max | a max below 3003 means something capped the card. The idle figure is only a sanity anchor. |
| `power draw / limit` | ~4 W idle; GB10 reports no settable limit (`[N/A]`) | a limit appearing where there was none is a cap somebody set. Under load, `experiment` owns this check. |
| `thermal` | ~34 C | an idle temperature well above that is a cooling or airflow change, and it is where a thermal-slowdown run starts. |
| `persistence` | `Enabled` | disabled, the driver unloads between runs; first-run figures then carry initialisation cost that later runs do not. |
| `perf state` | `P8` idle | anything else at rest means the card is not actually idle — check compute-apps again. |
| `cpu governor` | `performance` | `powersave` throttles the host side: dispatch, tokenisation, and the client loop all slow, and `tg` moves with no engine change. |
| `throttle` | `0x0` and nothing active | a nonzero bitmask at rest is the strongest single reason to stop and record before anything is run. The GB10 power-delivery fault is the exception: it pins clocks with an all-clear mask, so a clean bitmask is not proof. |
| `memory` | 121 GiB total, ~116 available | a leaked container holding host RAM changes what the engine can page. |
| `disk` | ~19% used of 2.9T | checkpoints and archives fill it; a full disk fails a run in a way that looks like an engine fault. |
| `uptime` | days | a reset uptime means a reboot, and a reboot silently resets everything above. |
| `images` | `ghcr.io/spark-arena/dgx-vllm-eugr-nightly` digests | `:latest` moving under an unchanged tag is a new epoch that no recipe records. This is the field most likely to change without anyone noticing. |
| `running` | the memory store's two containers | anything else is a neighbour that will contend for the card during a run. |

## Reading the fault signature

Two GB10 power-delivery faults pin the GPU at 513 or 721 MHz while reporting an
all-clear throttle bitmask — plausible numbers, roughly 3x wrong. At rest the
card sits near 200 MHz, so an idle sweep cannot see the fault. It is caught
under load, by `experiment`, by reading the clock out of the run's
`telemetry.jsonl`. Note the clock has read a constant 208 MHz in every frame of
every run so far, including frames at 96% utilisation — so it is currently
unmeasured under load, not measured in band.

What the idle sweep contributes is the before-and-after: a dated record of the
box's resting state on either side of the day the fault first appeared.

## What is deliberately not swept

- **Anything requiring a change to read.** No `nvidia-smi -ac`, no
  `-pm`/`-pl`, no governor writes, no `apt`.
- **Anything inside a container.** The vLLM and flashinfer versions come from a
  run's own archive, where they are stamped against the run that used them.
  Starting a container to ask would be a load on the card.
- **Model checkpoints.** They belong to `spark-model`, not to the box.
