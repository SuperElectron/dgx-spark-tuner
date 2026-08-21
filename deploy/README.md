# deploy/ — box access + lifecycle

Everything that touches the DGX Spark box. The rest of the repo runs on the
laptop and reaches the box only through `./deploy/connect.sh`.

```
./deploy/connect.sh sync              # rsync deploy/box/ -> box:~/spark-tuner/
./deploy/connect.sh setup             # one-time box verification (sudo prompt)
./deploy/connect.sh start MODEL=...   # start benchmark engine (parks standing ones)
./deploy/connect.sh stop [--restore]  # stop it; --restore brings runKali engines back
./deploy/connect.sh status            # JSON env fingerprint
./deploy/connect.sh ssh <cmd...>      # anything else
```

Connection config lives in `.claude/box.json` (gitignored — never
committed); overrides via `BOX_TARGET`, `SSH_KEY`, `BOX_DOMAIN`.

## The box

GB10 (sm_121a, arm64), one unified 121 GB memory pool shared by GPU, host,
and page cache. Rules the scripts encode (learned the hard way):

- **Sequential engine starts.** vLLM sizes its KV cache from free memory at
  boot; two engines starting together race and the second dies.
- **Drop the page cache before every engine start.** 60+ GiB weight loads
  leave clean pages CUDA cannot claim; the next engine OOMs at context
  creation.
- **Exact KV bytes, not fractions.** `--kv-cache-memory-bytes` — the
  fraction flag measures whatever is free at boot, and unified-memory
  profiling can abort without it.
- **Digest-pinned image.** One known-good vllm-gb10 build to roll back to.

## Files

| File | Runs on | Does |
|---|---|---|
| `connect.sh` | laptop | the entry point above |
| `box/setup.sh` | box | one-time: docker, CDI, image, HF cache, drop-caches sudo helper |
| `box/start.sh` | box | park standing `vllm-*` → drop caches → boot `vllm-bench` → wait → fingerprint |
| `box/stop.sh` | box | kill `vllm-bench` + drop caches; `--restore` reruns runKali's start-models.sh |
| `box/status.sh` | box | JSON fingerprint (temp, driver, free mem, running engines, image digest) |

## Benchmark round shape

```
spark start MODEL=... → [benchmark against :PORT] → spark stop → next round …
finally: spark stop --restore
```

`stop --restore` returns the box to normal serving via runKali's own
`start-models.sh` (called in place, never copied — that config belongs to
runKali and drifts with it), and only if `start` actually parked something.
