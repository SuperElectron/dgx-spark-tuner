#!/usr/bin/env python3
"""Run one benchmark experiment and archive everything needed to reproduce it.

    uv run --project .claude/skills/experiment \
        .claude/skills/experiment/scripts/run_experiment.py \
        --series research/<series> --hyp <hypothesisId> --label <text> [options]

Fails hard: any missing artifact means the run is not reproducible.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import asdict, is_dataclass
from pathlib import Path

import sparkrun.api as api
from sparkrun.orchestration.job_metadata import load_job_metadata

TELEMETRY_INTERVAL = 2.0


def die(msg: str) -> None:
    sys.exit(f"run-experiment: {msg}")


def say(msg: str) -> None:
    print(f"==> {msg}", file=sys.stderr, flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="run-experiment")
    p.add_argument("--series", required=True, type=Path, help="research/<series>")
    p.add_argument("--hyp", required=True, help="hypothesis id, e.g. R26-kernel-tuning")
    p.add_argument("--label", required=True, help="archive suffix, e.g. shipped, kvauto")
    p.add_argument("--recipe", type=Path, help="default: <series>/recipe.yaml")
    p.add_argument("-o", dest="overrides", action="append", default=[], metavar="K=V")
    p.add_argument("-b", dest="bench_args", action="append", default=[], metavar="K=V")
    p.add_argument("--runs", type=int)
    p.add_argument("--keep-alive", action="store_true")
    return p.parse_args()


def kv(pairs: list[str], where: str) -> dict[str, object]:
    out: dict[str, object] = {}
    for pair in pairs:
        if "=" not in pair:
            die(f"{where} must be key=value, got {pair!r}")
        k, v = pair.split("=", 1)
        if "," in v:
            out[k] = [_scalar(x) for x in v.split(",")]
        else:
            out[k] = _scalar(v)
    return out


def _scalar(v: str) -> object:
    v = v.strip()
    if v.lower() in ("true", "false"):
        return v.lower() == "true"
    try:
        return int(v)
    except ValueError:
        return v


class Telemetry:
    """Samples sparkrun's own monitor for the whole run, one JSON frame per line.

    MonitorSample carries gpu clock, temperature, power, utilisation and memory
    plus host CPU and RAM — a superset of what nvidia-smi gives, and it arrives
    already paired with sparkrun's occupancy view of the host.
    """

    def __init__(self, host: str, out: Path) -> None:
        self._out = out
        self._stop = threading.Event()
        self._session = api.open_live_monitor([host], interval=int(TELEMETRY_INTERVAL))
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self.samples = 0

    def __enter__(self) -> "Telemetry":
        self._thread.start()
        return self

    def __exit__(self, *exc: object) -> None:
        self._stop.set()
        self._thread.join(timeout=10)
        self._session.close()

    def _loop(self) -> None:
        with self._out.open("w") as fh:
            while not self._stop.is_set():
                frame = self._session.frame()
                fh.write(json.dumps(_plain(frame), default=str) + "\n")
                fh.flush()
                self.samples += 1
                self._stop.wait(TELEMETRY_INTERVAL)


def _plain(obj: object) -> object:
    if is_dataclass(obj) and not isinstance(obj, type):
        return asdict(obj)
    return obj


def main() -> None:
    args = parse_args()

    series: Path = args.series
    if not series.is_dir():
        die(f"not a directory: {series}")

    repo = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    )

    branch = subprocess.run(
        ["git", "-C", str(repo), "branch", "--show-current"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if branch in ("", "main", "staging"):
        die(f"on branch {branch!r} — branch off staging first")

    box = json.loads((repo / ".claude/box.json").read_text())
    host = box["host"]

    recipe = args.recipe or series / "recipe.yaml"
    if not recipe.is_file():
        die(f"no recipe at {recipe}")

    hyp_dir = series / "experiments" / args.hyp
    hyp_dir.mkdir(parents=True, exist_ok=True)

    bench_args = kv(args.bench_args, "-b")
    if args.runs is not None:
        bench_args["runs"] = args.runs

    output_file = series / "round-tmp.yaml"
    telemetry_path = series / ".telemetry.jsonl"

    say(f"benchmarking {recipe} on {host}")
    with Telemetry(host, telemetry_path) as telemetry:
        try:
            result = api.benchmark(
                api.BenchmarkOptions(
                    recipe=str(recipe),
                    hosts=(host,),
                    solo=True,
                    bench_args=bench_args,
                    overrides=kv(args.overrides, "-o"),
                    no_stop=True,
                    output_file=str(output_file),
                    resume=api.ResumeMode.NEVER,
                )
            )
        except api.SparkrunError as exc:
            die(f"benchmark failed: {type(exc).__name__}: {exc}")

    if not result.success:
        die(f"benchmark reported failure (id {result.benchmark_id})")

    bench_id = result.benchmark_id
    cluster_id = result.cluster_id
    say(f"{bench_id} on cluster {cluster_id}")

    archive = hyp_dir / f"{bench_id}-{args.label}"
    if archive.exists():
        die(f"archive exists: {archive} — use a different --label")
    archive.mkdir(parents=True)

    # Job metadata is keyed by cluster id and deleted by stop(), so this has to
    # happen before the workload goes down. It is the only record of the -o
    # overrides the run actually used.
    say("capturing effective recipe")
    meta = load_job_metadata(cluster_id)
    if not meta:
        die(f"no job metadata for {cluster_id} — the effective recipe is unrecoverable")
    (archive / "effective-recipe.json").write_text(
        json.dumps(meta, indent=2, default=str) + "\n"
    )

    say("capturing engine log")
    lines = [str(getattr(line, "text", line)) for line in api.logs(cluster_id, tail=100_000)]
    if not lines:
        die("sparkrun logs returned nothing")
    (archive / "engine-capture.log").write_text("\n".join(lines) + "\n")

    if not args.keep_alive:
        say("stopping workload")
        api.stop(cluster_id=cluster_id, hosts=[host])

    state_dir = Path(result.state_dir)
    if not state_dir.is_dir():
        die(f"no sparkrun state at {state_dir}")
    shutil.copytree(state_dir, archive, dirs_exist_ok=True)

    for suffix in (".yaml", ".json", ".csv"):
        produced = output_file.with_suffix(suffix)
        if produced.is_file():
            produced.replace(archive / produced.name)

    telemetry_path.replace(archive / "telemetry.jsonl")

    if recipe.resolve() != (series / "recipe.yaml").resolve():
        shutil.copy2(recipe, archive / recipe.name)

    (archive / "run-metadata.json").write_text(
        json.dumps(
            {
                "benchmark_id": bench_id,
                "cluster_id": cluster_id,
                "hosts": list(result.host_list or []),
                "container_image": result.container_image,
                "container_image_sha": result.container_image_sha,
                "container_image_sha_pinned": result.container_image_sha_pinned,
                "container_image_longterm_ref": result.container_image_longterm_ref,
                "bench_args": bench_args,
                "overrides": kv(args.overrides, "-o"),
                "recipe": str(recipe),
                "label": args.label,
                "captured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            },
            indent=2,
        )
        + "\n"
    )

    required = [
        "state.yaml",
        "round-tmp.json",
        "effective-recipe.json",
        "engine-capture.log",
        "telemetry.jsonl",
        "run-metadata.json",
    ]
    for name in required:
        path = archive / name
        if not path.is_file() or path.stat().st_size == 0:
            die(f"archive incomplete: {name} is missing or empty")

    engine_log = (archive / "engine-capture.log").read_text()
    if "Running:" not in engine_log:
        die("engine-capture.log has no 'Running:' lines — wrong stream captured")

    state = (archive / "state.yaml").read_text()
    crashes = next(
        (ln.split(":", 1)[1].strip() for ln in state.splitlines() if ln.startswith("crash_count:")),
        "unknown",
    )

    print()
    print(f"archive:     {archive}")
    print(f"benchmark:   {bench_id}")
    print(f"crash_count: {crashes}")
    print(f"engine log:  {len(engine_log.splitlines())} lines")
    print(f"telemetry:   {telemetry.samples} frames")


if __name__ == "__main__":
    main()
