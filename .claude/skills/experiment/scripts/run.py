#!/usr/bin/env python3
"""Run one experiment from its run directory.

    uv run --project .claude/skills/experiment \
        .claude/skills/experiment/scripts/run.py <run_dir> [--keep-alive]

A run directory holds the recipe for that run and receives its results:

    experiments/<hypothesis>/run-0001/
        recipe.yaml         the recipe to run — serve config and, in its
                            `benchmark:` block, the probe grid
        id.txt              path to sparkrun's state dir for this run
        out/                written here
            results.yaml        sparkrun's export: recipe text and hash,
                                runtime fingerprint, args, results
            telemetry.jsonl     one GPU/occupancy frame per line
            engine-capture.log  vLLM's output, including the config it booted

To iterate: copy the run directory, change a parameter in its recipe, run it.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import threading
from dataclasses import asdict
from pathlib import Path

import sparkrun.api as api
import yaml

TELEMETRY_INTERVAL = 0.25
REQUIRED = ("results.yaml", "telemetry.jsonl", "engine-capture.log")


def die(msg: str) -> None:
    sys.exit(f"run: {msg}")


def say(msg: str) -> None:
    print(f"==> {msg}", file=sys.stderr, flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="run")
    p.add_argument("run_dir", type=lambda s: Path(s).resolve(), help="the run directory")
    p.add_argument("--keep-alive", action="store_true", help="leave the workload up")
    return p.parse_args()


def resolve_recipe(run_dir: Path) -> Path:
    if not run_dir.is_dir():
        die(f"not a directory: {run_dir}")
    recipe = run_dir / "recipe.yaml"
    if not recipe.is_file():
        die(f"no recipe at {recipe}")
    return recipe


def make_out(run_dir: Path) -> Path:
    out = run_dir / "out"
    if out.exists() and any(out.iterdir()):
        die(f"already has results: {out}")
    out.mkdir(exist_ok=True)
    return out


def load_box(repo: Path) -> tuple[str, dict]:
    """Host and ssh identity for the box. Credentials are never read."""
    path = repo / ".claude/box.json"
    if not path.is_file():
        die(f"missing {path}")
    box = json.loads(path.read_text())
    for key in ("host", "username"):
        if not box.get(key):
            die(f"{path} has no {key!r}")
    return box["host"], {"ssh_user": box["username"]}


class Telemetry:
    """GPU and occupancy frames for the whole run, one JSON object per line.

    MonitorSample carries clock, temperature, power, utilisation and memory
    alongside sparkrun's own occupancy view of the host.
    """

    def __init__(self, host: str, out: Path, ssh_kwargs: dict, sctx) -> None:
        self._out = out
        self._stop = threading.Event()
        self._session = api.open_live_monitor(
            [host], interval=TELEMETRY_INTERVAL, ssh_kwargs=ssh_kwargs, sctx=sctx
        )
        self._thread = threading.Thread(target=self._sample, daemon=True)
        self.frames = 0

    def __enter__(self) -> "Telemetry":
        self._thread.start()
        return self

    def __exit__(self, *_exc: object) -> None:
        self._stop.set()
        self._thread.join(timeout=10)
        self._session.close()

    def _sample(self) -> None:
        with self._out.open("w") as fh:
            while not self._stop.is_set():
                fh.write(json.dumps(asdict(self._session.frame()), default=str) + "\n")
                fh.flush()
                self.frames += 1
                self._stop.wait(TELEMETRY_INTERVAL)


def run_benchmark(recipe: Path, host: str, out: Path, sctx):
    """Run it, returning (result, benchmark_id).

    The id reaches a library caller only through the progress emitter;
    BenchmarkResult.benchmark_id comes back empty.
    """
    seen: list[str] = []

    def on_progress(event: api.ProgressEvent) -> None:
        line = event.data.get("msg") or event.data.get("line") or ""
        if "Benchmark ID:" in line:
            seen.append(line.split("Benchmark ID:", 1)[1].strip())

    options = api.BenchmarkOptions(
        recipe=str(recipe),
        hosts=(host,),
        solo=True,
        no_stop=True,
        resume=api.ResumeMode.FRESH,
        output_file=str(out / "results.yaml"),
        progress_callback=on_progress,
        # Per-request arrival and completion times, with the token count each
        # one actually generated. The results JSON reports the *requested* tg,
        # so a short generation is invisible there. llama-benchy runs from this
        # process's working directory, so the path has to be absolute — and
        # only here is the run's own out/ known.
        bench_args={"emit_progress": str(out / "progress.jsonl")},
    )
    try:
        result = api.benchmark(options, sctx=sctx)
    except (api.HostsUnreachable, api.InsufficientCapacity) as exc:
        die(f"box unavailable: {type(exc).__name__}: {exc}")
    except api.BenchmarkFailed as exc:
        die(f"benchmark failed: {exc}")
    except api.SparkrunError as exc:
        die(f"{type(exc).__name__}: {exc}")

    if not seen:
        die("sparkrun never emitted a Benchmark ID")
    return result, seen[0]


def prune_exports(result) -> None:
    """results.yaml embeds the json and csv verbatim, and only it carries the
    recipe text and the runtime fingerprint."""
    for fmt in ("json", "csv"):
        path = result.outputs.get(fmt)
        if path:
            Path(path).unlink()


def write_pointer(run_dir: Path, bench_id: str, sctx) -> Path:
    """results.yaml records the cluster but never the benchmark id, so nothing
    here can find state.yaml, consolidated.json and runs/ without this."""
    state = Path(sctx.config.cache_dir) / "benchmarks" / bench_id
    if not state.is_dir():
        die(f"no sparkrun state at {state}")
    (run_dir / "id.txt").write_text(f"{state}\n")
    return state


def capture_logs(cluster_id: str, out: Path, sctx) -> None:
    """Whole log, every worker. Hosts come from the job cache under cluster_id."""
    written = 0
    with out.open("w") as fh:
        for line in api.logs(cluster_id, scope="all", sctx=sctx):
            fh.write(line.text + "\n")
            written += 1
    if not written:
        die("sparkrun returned no engine log")


def copy_to_state(out: Path, state: Path) -> None:
    """Leave the same artifacts beside sparkrun's own, so the cache entry is
    readable without the run directory."""
    shutil.copytree(out, state / "out", dirs_exist_ok=True)


def validate(out: Path) -> None:
    for name in REQUIRED:
        path = out / name
        if not path.is_file() or path.stat().st_size == 0:
            die(f"incomplete: {name} missing or empty")


# sparkrun sweeps every key it does not recognise out of the recipe's
# `benchmark:` block and into llama-benchy's argv. A misspelling becomes an
# unknown flag and fails loudly, but a real flag does not: it changes how the
# measurement is taken while the grid still looks right. `--no-warmup` is the
# one that matters — warmup is what absorbs the Triton JIT compilation, so
# without it the compile lands on the measurements instead.
GRID_KEYS = ("pp", "tg", "depth", "concurrency", "runs")
BENCHMARK_META = {"framework", "args", "metadata", "timeout", "schedule", "category"}
# Set by this script rather than the recipe, so the recipe is not expected to
# declare them and the check below must not treat them as drift.
INJECTED = {"emit_progress"}


def served_grid(state: Path) -> dict:
    """What llama-benchy was actually handed, as sparkrun resolved it."""
    data = yaml.safe_load((state / "state.yaml").read_text()) or {}
    return data.get("base_args") or {}


def check_grid(recipe: Path, state: Path) -> dict:
    """The recipe declares the grid; state.yaml records what ran. A difference
    means the run answered a question the recipe did not ask."""
    declared = (yaml.safe_load(recipe.read_text()) or {}).get("benchmark") or {}
    declared = {k: v for k, v in declared.items() if k not in BENCHMARK_META}
    served = served_grid(state)
    if not served:
        die("state.yaml has no base_args — cannot tell what grid ran")

    for key in sorted((set(declared) | set(served)) - INJECTED):
        want, got = declared.get(key), served.get(key)
        if want != got:
            die(f"grid differs from the recipe: {key} declared {want!r}, ran {got!r}")
    return served


# NVIDIA has confirmed two power-delivery faults on GB10 that pin the GPU at
# 513 or 721 MHz with an all-clear throttle bitmask — the numbers look
# plausible and are ~3x wrong. It is only visible under load, and this box's
# `gpu_clock_mhz` reads 208 in almost every frame whatever the GPU is doing, so
# the clock cannot be the signal. Power can: a healthy run peaks near 100 W and
# a capped one cannot leave the 20-30 W band.
POWER_FLOOR_W = 60.0

# perf_analyzer calls a measurement stable when max/min across recent windows
# is within 10%. Ours is not a convergence gate — we take what the grid gives —
# but a run whose samples spread wider than this is saying so out loud.
STABLE_RATIO = 1.10


def box_state(out: Path) -> dict:
    """Peak GPU power over the run. The frames are a nested per-host shape and
    some carry no telemetry at all."""
    peak = 0.0
    for line in (out / "telemetry.jsonl").read_text().splitlines():
        try:
            frame = json.loads(line)
        except ValueError:
            continue
        for host in frame.get("hosts", []):
            tel = host.get("telemetry") or {}
            watts = tel.get("gpu_power_w")
            if watts is not None:
                peak = max(peak, float(watts))
    return {"peak_power_w": peak}


def check_box(out: Path) -> dict:
    box = box_state(out)
    if box["peak_power_w"] < POWER_FLOOR_W:
        die(
            f"GPU never drew more than {box['peak_power_w']:.1f} W "
            f"(floor {POWER_FLOOR_W:.0f} W) — the box was power-capped, "
            "so these figures measure the cap, not the recipe"
        )
    return box


def spread(out: Path) -> list[tuple[str, str, float, float, float]]:
    """Per metric: median, max/min ratio, and the values behind them. Reads the
    named cell and the context-prefill phase separately — they are different
    measurements and only one answers the recipe's question."""
    data = yaml.safe_load((out / "results.yaml").read_text()) or {}
    results = (data.get("sparkrun_benchmark") or {}).get("results") or {}
    rows = []
    for entry in (results.get("json") or {}).get("benchmarks", []):
        phase = "ctx" if entry.get("is_context_prefill_phase") else "cell"
        for metric in ("pp_throughput", "tg_throughput"):
            vals = (entry.get(metric) or {}).get("values") or []
            if len(vals) < 2:
                continue
            ordered = sorted(vals)
            median = ordered[len(ordered) // 2]
            rows.append((phase, metric[:2], median, max(vals) / min(vals), len(vals)))
    return rows


def report(out: Path, state: Path, frames: int, grid: dict, box: dict) -> None:
    print(f"\nout:       {out}")
    print(f"state:     {state}")
    print(f"engine:    {len((out / 'engine-capture.log').read_text().splitlines())} lines")
    print(f"telemetry: {frames} frames")
    print("grid:      " + "  ".join(f"{k} {grid[k]}" for k in GRID_KEYS if k in grid))
    extra = sorted(k for k in grid if k not in GRID_KEYS)
    if extra:
        print("           also " + ", ".join(f"{k}={grid[k]}" for k in extra))
    print(f"box:       peak {box['peak_power_w']:.1f} W")
    for phase, metric, median, ratio, n in spread(out):
        verdict = "stable" if ratio <= STABLE_RATIO else "UNSTABLE"
        print(f"{phase + ' ' + metric:<11}median {median:8.1f}  max/min {ratio:.2f}  n={n}  {verdict}")


def main() -> None:
    args = parse_args()
    recipe = resolve_recipe(args.run_dir)
    out = make_out(args.run_dir)

    sctx = api.default_sctx()
    host, ssh_kwargs = load_box(Path(__file__).resolve().parents[4])

    say(f"benchmarking {recipe} on {host}")
    with Telemetry(host, out / "telemetry.jsonl", ssh_kwargs, sctx) as telemetry:
        result, bench_id = run_benchmark(recipe, host, out, sctx)
    say(f"{bench_id} on {result.cluster_id}")

    prune_exports(result)
    state = write_pointer(args.run_dir, bench_id, sctx)

    # Must precede stop(): it takes the workload's logs with it.
    say("capturing engine log")
    capture_logs(result.cluster_id, out / "engine-capture.log", sctx)

    if not args.keep_alive:
        say("stopping workload")
        api.stop(cluster_id=result.cluster_id, hosts=[host], sctx=sctx)

    validate(out)
    grid = check_grid(recipe, state)
    box = check_box(out)
    copy_to_state(out, state)
    report(out, state, telemetry.frames, grid, box)


if __name__ == "__main__":
    main()
