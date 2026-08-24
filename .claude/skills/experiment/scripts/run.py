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
from sparkrun.core.benchmark_profiles import BenchmarkSpec
from sparkrun.core.recipe import Recipe

from measure import check_box, report

TELEMETRY_INTERVAL = 0.25
PROGRESS_INTERVAL = 0.2
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


class ProgressRoll:
    """Keep every cell's per-request events, not just the last one's.

    llama-benchy opens `--emit-progress` with mode "w", and a schedule runs one
    subprocess per cell, so each cell truncates the file its predecessor wrote.
    This watches for that truncation and rolls what was there into a file named
    for the cell that produced it.

    Sampling has a limit: a cell that is truncated and refilled past the old
    length between two polls would be read as a continuation. Cells run for
    tens of seconds at least, so the poll is far inside that.
    """

    def __init__(self, source: Path, dest: Path, labels: list[str]) -> None:
        self._source = source
        self._dest = dest
        self._labels = labels
        self._offset = 0
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._watch, daemon=True)
        self.cells = 0

    def __enter__(self) -> "ProgressRoll":
        self._dest.mkdir(parents=True, exist_ok=True)
        self._thread.start()
        return self

    def __exit__(self, *_exc: object) -> None:
        self._stop.set()
        self._thread.join(timeout=10)
        self._drain()

    def _watch(self) -> None:
        while not self._stop.is_set():
            self._drain()
            self._stop.wait(PROGRESS_INTERVAL)

    def _drain(self) -> None:
        if not self._source.is_file():
            return
        size = self._source.stat().st_size
        if size < self._offset:
            self.cells += 1
            self._offset = 0
        if size == self._offset:
            return
        with self._source.open("rb") as fh:
            fh.seek(self._offset)
            chunk = fh.read()
        self._offset = size
        label = self._labels[self.cells] if self.cells < len(self._labels) else "unknown"
        with (self._dest / f"{self.cells:02d}-{label}.jsonl").open("ab") as fh:
            fh.write(chunk)


def cell_labels(spec: BenchmarkSpec) -> list[str]:
    """Execution order, so each rolled file is named for its cell. Mirrors
    llama-benchy's own task list: the schedule when there is one, otherwise a
    depth-major product of depth x concurrency."""
    if spec.schedule:
        return [f"d{e.get('depth', 0)}c{e.get('concurrency', 1)}" for e in spec.schedule]
    depths = spec.args.get("depth") or [0]
    concs = spec.args.get("concurrency") or [1]
    return [f"d{d}c{c}" for d in depths for c in concs]


def run_benchmark(recipe: Path, host: str, out: Path, sctx, seen: list[str]):
    """Run it, returning (result, benchmark_id).

    The id reaches a library caller only through the progress emitter;
    BenchmarkResult.benchmark_id comes back empty. `seen` is the caller's, so
    the id is still in hand if this raises — a failed run needs it to find its
    own engine log.

    Errors propagate. The caller archives what the failure left behind before
    reporting it.
    """

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
        bench_args={
            "emit_progress": str(out / "progress.jsonl"),
            "save_total_throughput_timeseries": True,
            "save_all_throughput_timeseries": True,
            "exit_on_first_fail": True,
        },
    )
    result = api.benchmark(options, sctx=sctx)
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


def capture_logs(cluster_id: str, out: Path, sctx) -> int:
    """Whole log, every worker. Hosts come from the job cache under cluster_id.

    Returns the line count rather than dying on zero: on the failure path an
    empty log is itself worth reporting, and the caller there has a more useful
    error to raise than this one."""
    written = 0
    with out.open("w") as fh:
        for line in api.logs(cluster_id, scope="all", sctx=sctx):
            fh.write(line.text + "\n")
            written += 1
    return written


def rescue_logs(seen: list[str], out: Path, sctx) -> None:
    """Archive the engine log after a failed run.

    A run that dies during engine start produces no results, so the engine log
    *is* the result — and it lives inside the workload, which the next run
    replaces. sparkrun writes state.yaml as soon as it has an id, and that file
    carries the cluster_id `api.logs` needs, so the id survives the failure even
    though the BenchmarkResult does not.

    Never raises: it runs while an error is already on its way up, and the
    original failure is the one worth reporting."""
    dest = out / "engine-capture.log"
    if dest.is_file():
        return
    if not seen:
        say("no benchmark id was emitted; engine log cannot be recovered")
        return
    state = Path(sctx.config.cache_dir) / "benchmarks" / seen[0]
    doc = state / "state.yaml"
    if not doc.is_file():
        say(f"no state.yaml under {state}; engine log cannot be recovered")
        return
    cluster = (yaml.safe_load(doc.read_text()) or {}).get("cluster_id")
    if not cluster:
        say(f"{doc} carries no cluster_id; engine log cannot be recovered")
        return
    try:
        lines = capture_logs(cluster, dest, sctx)
    except Exception as exc:  # noqa: BLE001 - never mask the original failure
        say(f"could not recover engine log: {type(exc).__name__}: {exc}")
        return
    say(f"engine log recovered: {lines} lines -> {dest}")


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
# Set by this script rather than the recipe, so the recipe is not expected to
# declare them and the check below must not treat them as drift.
INJECTED = {
    "emit_progress",
    # The sliding window that computes these already runs; the flags only keep
    # the series instead of discarding it, so they cost no wall clock. With
    # return_token_ids on, an accepted speculative step lands several token
    # timestamps in one chunk — the series is MTP acceptance, made readable.
    "save_total_throughput_timeseries",
    "save_all_throughput_timeseries",
    # An unattended schedule should fail loudly rather than write a plausible
    # half-table.
    "exit_on_first_fail",
}


def declared_bench(recipe: Path) -> BenchmarkSpec:
    """The recipe's `benchmark:` block, resolved the way sparkrun resolves it.

    Asking sparkrun rather than reading the YAML ourselves is what keeps the
    two in step: it is the side that decides whether a key nested under `args:`
    and a key at the top level mean the same thing, and they do.
    """
    spec = BenchmarkSpec.from_recipe(Recipe.from_dict(yaml.safe_load(recipe.read_text()) or {}))
    if spec is None:
        die("recipe declares no benchmark block")
    return spec


def check_grid(spec: BenchmarkSpec, state: Path) -> dict:
    """The recipe declares the grid; state.yaml records what ran. A difference
    means the run answered a question the recipe did not ask."""
    doc = yaml.safe_load((state / "state.yaml").read_text()) or {}
    served = doc.get("base_args") or {}
    if not served:
        die("state.yaml has no base_args — cannot tell what grid ran")

    for key in sorted((set(spec.args) | set(served)) - INJECTED):
        want, got = spec.args.get(key), served.get(key)
        if want != got:
            die(f"grid differs from the recipe: {key} declared {want!r}, ran {got!r}")

    # Order is not decoration: it sets what is warm and what is hot when each
    # cell runs, and no figure in the results reveals which order produced it.
    # A per-cell override rides in the schedule too, so an unchecked schedule
    # leaves the grid check reading only half the declaration.
    if (spec.schedule or None) != (doc.get("schedule") or None):
        die("schedule differs from the recipe")
    return served


# llama-benchy draws each prompt from a random offset into a corpus and seeds
# nothing, so every request measures different text — and MTP acceptance is
# content-dependent, which is why decode scatters while prefill does not. It
# has no seed flag. But `prompts.py` picks its offset with
# `randint(0, len(corpus) - (pp + depth))`, so a corpus exactly one token
# longer than the prompt needs collapses that to `randint(0, 1)`, which is
# always 0. Same text every time.
#
# `book_url` is only ever an md5 cache key (`corpus.py`): if the cache file
# exists llama-benchy reads it and never fetches. So the fixed corpus is
# installed, not hosted. It is a slice of llama-benchy's own default text, so
# the prose is what it always was — only the offset stops moving.
FIXED_CORPUS_URL = "spark-tuner://fixed-corpus"
BENCHY_CACHE = Path.home() / ".cache" / "llama-benchy"


def _cell_size(value, default: int) -> int:
    """A schedule entry carries scalars where the grid carries lists."""
    if value is None:
        return default
    return max(value) if isinstance(value, list) else int(value)


def corpus_cells(spec: BenchmarkSpec) -> dict[str, tuple[int, int]]:
    """Which cell each pinned corpus has to serve: {book_url: (pp, depth)}.

    A corpus is sized to one prompt length, so one `book_url` pins one cell.
    A schedule gives each cell its own url and every cell is pinned; a bare
    grid has one url for the whole cartesian product, so only the deepest
    would be, and that is refused rather than half-delivered."""
    base = (_cell_size(spec.args.get("pp"), 0), _cell_size(spec.args.get("depth"), 0))
    base_url = spec.args.get("book_url")

    want: dict[str, set[tuple[int, int]]] = {}
    for entry in spec.schedule or [{}]:
        url = entry.get("book_url", base_url)
        if not str(url or "").startswith(FIXED_CORPUS_URL):
            continue
        cell = (
            _cell_size(entry.get("pp"), base[0]),
            _cell_size(entry.get("depth"), base[1]),
        )
        want.setdefault(url, set()).add(cell)

    if not want:
        return {}
    if not spec.schedule:
        cells = len(spec.args.get("pp") or [0]) * len(spec.args.get("depth") or [0])
        if cells > 1:
            die(
                f"the fixed corpus pins one cell; this grid has {cells}. Give each "
                "schedule entry its own book_url, or split it into one run per cell."
            )
    for url, cells in want.items():
        if len(cells) > 1:
            die(f"{url} is asked to pin {len(cells)} cells: {sorted(cells)}. One url, one cell.")
    return {url: next(iter(cells)) for url, cells in want.items()}


def install_corpora(spec: BenchmarkSpec, model: str) -> str:
    """Write one corpus per pinned cell into llama-benchy's cache. Regenerated
    every run: a corpus sized for a different grid silently starts jittering."""
    from hashlib import md5

    from tokenizers import Tokenizer

    wanted = corpus_cells(spec)
    if not wanted:
        return "no fixed corpus: the recipe does not ask for one"

    dests = {f"{md5(url.encode()).hexdigest()}.txt" for url in wanted}
    source = sorted(p for p in BENCHY_CACHE.glob("*.txt") if p.name not in dests)
    if not source:
        die(f"no llama-benchy corpus cached under {BENCHY_CACHE} to slice from")
    tok = Tokenizer.from_pretrained(model)
    ids = tok.encode(source[0].read_text(encoding="utf-8"), add_special_tokens=False).ids

    sizes = [
        _write_corpus(tok, ids, url, pp, depth) for url, (pp, depth) in sorted(wanted.items())
    ]
    return f"fixed corpus: {len(sizes)} cell(s), {min(sizes)}-{max(sizes)} tokens"


def _write_corpus(tok, ids: list[int], url: str, pp: int, depth: int) -> int:
    from hashlib import md5

    need = pp + depth
    if need <= 0:
        die(f"{url} pins a cell with no pp/depth, so the corpus cannot be sized")
    if len(ids) < need + 1:
        die(f"corpus has {len(ids)} tokens, needs {need + 1} for {url}")
    # Slice from a per-cell offset rather than always from token zero. Sliced
    # from zero, a shallow cell's prompt is a leading substring of a deeper
    # one's, so in a depth sweep the rungs donate prefix-cache blocks to each
    # other and the deeper rungs read faster than they should. The offset is
    # derived from the cell, so a rung still gets the same text every time it
    # runs — deterministic within a cell, disjoint across cells.
    room = len(ids) - need - 1
    off = 0
    if room > 0:
        off = int(md5(f"{pp}:{depth}".encode()).hexdigest(), 16) % room // 1024 * 1024

    text = tok.decode(ids[off : off + need + 1], skip_special_tokens=False)
    got = len(tok.encode(text, add_special_tokens=False).ids)
    if got != need + 1:
        die(f"corpus slice round-tripped to {got} tokens, not {need + 1} (offset {off})")

    (BENCHY_CACHE / f"{md5(url.encode()).hexdigest()}.txt").write_text(text, encoding="utf-8")
    return got


def main() -> None:
    args = parse_args()
    recipe = resolve_recipe(args.run_dir)
    out = make_out(args.run_dir)

    sctx = api.default_sctx()
    host, ssh_kwargs = load_box(Path(__file__).resolve().parents[4])

    doc = yaml.safe_load(recipe.read_text()) or {}
    model = doc.get("model") or ""
    if not model:
        die("recipe declares no model")

    # Only a recipe that asks for the fixed corpus gets one: a recipe measuring
    # a grid on llama-benchy's own moving offset is a deliberate choice, not a
    # mistake to be caught.
    spec = declared_bench(recipe)
    say(install_corpora(spec, model))

    seen: list[str] = []
    say(f"benchmarking {recipe} on {host}")
    try:
        with (
            Telemetry(host, out / "telemetry.jsonl", ssh_kwargs, sctx) as telemetry,
            ProgressRoll(out / "progress.jsonl", out / "progress", cell_labels(spec)),
        ):
            result, bench_id = run_benchmark(recipe, host, out, sctx, seen)
    except (api.HostsUnreachable, api.InsufficientCapacity) as exc:
        die(f"box unavailable: {type(exc).__name__}: {exc}")
    except api.SparkrunError as exc:
        rescue_logs(seen, out, sctx)
        die(f"{type(exc).__name__}: {exc}")
    say(f"{bench_id} on {result.cluster_id}")

    prune_exports(result)
    state = write_pointer(args.run_dir, bench_id, sctx)

    # Must precede stop(): it takes the workload's logs with it.
    say("capturing engine log")
    if not capture_logs(result.cluster_id, out / "engine-capture.log", sctx):
        die("sparkrun returned no engine log")

    if not args.keep_alive:
        say("stopping workload")
        api.stop(cluster_id=result.cluster_id, hosts=[host], sctx=sctx)

    validate(out)
    grid = check_grid(spec, state)
    box = check_box(out)
    copy_to_state(out, state)
    report(out, state, telemetry.frames, grid, box, GRID_KEYS)


if __name__ == "__main__":
    main()
