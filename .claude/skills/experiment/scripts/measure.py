"""Read what a run produced and say whether it can be trusted.

run.py orchestrates; everything that inspects the artifacts afterwards lives
here. Nothing in this module talks to the box.
"""

from __future__ import annotations

import json
import re
import statistics
import sys
from pathlib import Path

import yaml

# Two GB10 power-delivery faults pin the GPU at 513 or 721 MHz with an all-clear
# throttle bitmask: plausible-looking numbers, ~3x wrong. A healthy run here
# clocks 2359-2398 MHz and peaks near 100 W.
POWER_FLOOR_W = 60.0
CLOCK_FAULT_BAND = (400, 900)

# The verdict is on interquartile spread, which uses every value. max/min is
# drawn from two samples and widens as `runs` grows, so it punishes longer runs;
# it is still printed because earlier rounds were judged on it. 5% separates a
# pinned prompt (2.7%) from a jittering one (12.2%).
STABLE_IQR = 0.05
STABLE_RATIO = 1.10


def die(msg: str) -> None:
    sys.exit(f"run: {msg}")


def _floats(text: str, pattern: str) -> list[float]:
    return [float(m) for m in re.findall(pattern, text)]


def box_state(out: Path) -> dict:
    """Peak GPU power over the run. The frames are a nested per-host shape and
    some carry no telemetry at all."""
    peak = 0.0
    clocks: list[float] = []
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
            mhz = tel.get("gpu_clock_mhz")
            if mhz is not None:
                clocks.append(float(mhz))
    busy = [c for c in clocks if c > 300]        # anything above the idle floor
    return {
        "peak_power_w": peak,
        "peak_clock_mhz": max(clocks) if clocks else 0.0,
        "busy_frames": len(busy),
        "frames": len(clocks),
    }


def check_box(out: Path) -> dict:
    box = box_state(out)
    lo, hi = CLOCK_FAULT_BAND
    # A short cell can miss every busy window at this sampling interval, so a
    # low clock only means something once the GPU has been seen busy.
    if box["busy_frames"] and lo <= box["peak_clock_mhz"] <= hi:
        die(
            f"GPU never clocked above {box['peak_clock_mhz']:.0f} MHz while busy "
            f"— that is the GB10 power-delivery fault signature (513/721 MHz "
            "pinned with an all-clear throttle bitmask), so these figures "
            "measure the fault, not the recipe"
        )
    if box["peak_power_w"] < POWER_FLOOR_W:
        die(
            f"GPU never drew more than {box['peak_power_w']:.1f} W "
            f"(floor {POWER_FLOOR_W:.0f} W) — the box was power-capped, "
            "so these figures measure the cap, not the recipe"
        )
    return box


# Hits are granted per whole block, and this model forces a 2144-token attention
# block so its pages align with the mamba pages. A shorter prompt cannot hit.
BLOCK_TOKENS = 2144


def engine_state(out: Path, wants_cache: bool) -> dict:
    """What the engine said about itself while it served.

    `Preemptions:` is only logged when the count is nonzero, so its absence is
    the assertion of zero rather than a missing field.
    """
    text = (out / "engine-capture.log").read_text()
    hits = _floats(text, r"Prefix cache hit rate: ([0-9.]+)%")
    running = _floats(text, r"Running: ([0-9]+) reqs")
    waiting = _floats(text, r"Waiting: ([0-9]+) reqs")
    kv = _floats(text, r"GPU KV cache usage: ([0-9.]+)%")
    preempt = _floats(text, r"Preemptions: ([0-9]+)")

    state = {
        "hit_samples": len(hits),
        "hit_max": max(hits) if hits else None,
        "running_max": max(running) if running else 0,
        "waiting_max": max(waiting) if waiting else 0,
        "kv_max": max(kv) if kv else 0,
        "preemptions": int(max(preempt)) if preempt else 0,
    }
    # Asking for prefix caching and never getting a hit means measuring
    # something other than what the recipe declared. Not fatal, but not silent.
    state["cache_suspect"] = bool(wants_cache and hits and state["hit_max"] == 0.0)
    return state


def cacheable(grid: dict) -> bool:
    """Whether this grid's prompt is long enough for a hit to be possible."""
    tokens = max(grid.get("pp") or [0]) + max(grid.get("depth") or [0])
    return tokens >= BLOCK_TOKENS


def progress_files(out: Path) -> list[tuple[str, Path]]:
    """One file per cell, labelled by the cell that wrote it. run.py rolls them
    out of the single path llama-benchy overwrites; a run predating that has
    only the one file, holding whichever cell finished last."""
    rolled = sorted((out / "progress").glob("*.jsonl"))
    if rolled:
        return [(p.stem.split("-", 1)[-1], p) for p in rolled]
    single = out / "progress.jsonl"
    return [("", single)] if single.is_file() else []


def requests(path: Path) -> dict:
    """Per-request shape, which the aggregate figures average away. If
    max_num_seqs is throttling, ttft clusters in waves of that width."""
    if not path.is_file():
        return {}
    ttft: list[float] = []
    rate: list[float] = []
    for line in path.read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "request_first_token" and event.get("ttft_s"):
            ttft.append(float(event["ttft_s"]))
        if event.get("type") == "request_end":
            secs = float(event.get("decode_seconds") or 0)
            tokens = int(event.get("total_tokens") or 0)
            if secs > 0 and tokens:
                rate.append(tokens / secs)
    if not rate:
        return {}
    return {
        "n": len(rate),
        "rate": (min(rate), statistics.median(rate), max(rate)),
        "ttft": (min(ttft), statistics.median(ttft), max(ttft)) if ttft else None,
    }


# A model held past its stopping point by ignore_eos tends to loop, and looping
# text drafts easily — so a degenerate request decodes FASTER and inflates the
# figure. Whole-output uniqueness cannot see it: unique words saturate while the
# total grows, so long clean prose scores as high as short looping text. A
# sliding window is length-invariant.
REPEAT_WINDOW = 100
REPEAT_LIMIT = 0.45


def _repeat_windows(text: str) -> list[float]:
    words = text.split()
    out = []
    for i in range(0, max(len(words) - REPEAT_WINDOW, 0) + 1, REPEAT_WINDOW):
        w = words[i : i + REPEAT_WINDOW]
        if len(w) >= REPEAT_WINDOW // 2:
            out.append(1 - len(set(w)) / len(w))
    return out


def degeneration(path: Path) -> dict:
    """Per request, the worst sliding-window repeat ratio in its output."""
    if not path.is_file():
        return {}
    texts: dict[int, str] = {}
    for line in path.read_text().splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("type") == "tokens":
            texts[e["request_id"]] = texts.get(e["request_id"], "") + (e.get("snippet") or "")
    worst = {r: max(_repeat_windows(t), default=0.0) for r, t in texts.items() if t}
    if not worst:
        return {}
    bad = sorted(r for r, v in worst.items() if v > REPEAT_LIMIT)
    return {"n": len(worst), "worst": max(worst.values()), "bad": bad}


def _iqr_ratio(values: list[float], median: float) -> float:
    """None below four values, where quartiles do not exist. Returning 0.0 would
    read as a perfectly tight measurement and pass any spread at all."""
    if len(values) < 4 or not median:
        return None
    q1, _, q3 = statistics.quantiles(values, n=4, method="inclusive")
    return (q3 - q1) / median


# These are batch-level. Their per-request twins differ by roughly the
# concurrency, so printing only the aggregate invites a comparison off by it.
AGGREGATE = ("pp_throughput", "tg_throughput")
PER_REQUEST = ("pp_req_throughput", "tg_req_throughput")


def spread(out: Path) -> list[dict]:
    """Per cell, per metric: the values in raw execution order, their median,
    and both spread statistics. Cells are labelled by what they measured —
    a multi-cell grid prints one row per cell, not several identical ones."""
    data = yaml.safe_load((out / "results.yaml").read_text()) or {}
    results = (data.get("sparkrun_benchmark") or {}).get("results") or {}
    rows = []
    for entry in (results.get("json") or {}).get("benchmarks", []):
        conc = entry.get("concurrency") or 1
        label = f"d{entry.get('context_size')} c{conc}"
        phase = "ctx" if entry.get("is_context_prefill_phase") else "cell"
        names = AGGREGATE + (PER_REQUEST if conc > 1 else ())
        for metric in names:
            vals = (entry.get(metric) or {}).get("values") or []
            if len(vals) < 2:
                continue
            median = statistics.median(vals)
            rows.append(
                {
                    "label": label,
                    "phase": phase,
                    "metric": metric.replace("_throughput", "").replace("_req", "/req"),
                    "values": vals,
                    "median": median,
                    "ratio": max(vals) / min(vals),
                    "iqr": _iqr_ratio(vals, median),
                    "n": len(vals),
                }
            )
        rows.append(_prefill(entry, label))
    return [r for r in rows if r]


def _prefill(entry: dict, label: str) -> dict | None:
    """`pp_throughput` credits only the user prompt but is timed over the whole
    prefill, so at depth it reads ~8x lower than the rate actually achieved.
    It is a sound proxy at fixed (pp, depth) and a misleading rate anywhere
    else, so the real rate is printed beside it.

    Only the inference phase is affected. The context-load phase serves just
    the context and is credited the same tokens it sent, so its figure is
    already a rate and needs nothing beside it."""
    if entry.get("is_context_prefill_phase"):
        return None
    est = (entry.get("est_ppt") or {}).get("mean")
    tokens = (entry.get("context_size") or 0) + (entry.get("prompt_size") or 0)
    if not est or not tokens:
        return None
    return {
        "label": label,
        "phase": "cell",
        "metric": "prefill*",
        "values": [],
        "median": tokens / (est / 1000.0),
        "ratio": 1.0,
        "iqr": 0.0,
        "n": 0,
    }


def report(out: Path, state: Path, frames: int, grid: dict, box: dict, keys) -> None:
    print(f"\nout:       {out}")
    print(f"state:     {state}")
    print(f"engine:    {len((out / 'engine-capture.log').read_text().splitlines())} lines")
    print(f"telemetry: {frames} frames")
    print("grid:      " + "  ".join(f"{k} {grid[k]}" for k in keys if k in grid))
    extra = sorted(k for k in grid if k not in keys)
    if extra:
        print("           also " + ", ".join(f"{k}={grid[k]}" for k in extra))
    clock = (
        f"peak clock {box['peak_clock_mhz']:.0f} MHz"
        if box["busy_frames"]
        else "clock idle in every frame (run too short to sample)"
    )
    print(f"box:       peak {box['peak_power_w']:.1f} W, {clock}")

    wants = bool(grid.get("prefix_caching") or grid.get("enable_prefix_caching"))
    eng = engine_state(out, wants and cacheable(grid))
    print(
        f"engine:    running max {eng['running_max']:.0f}  waiting max {eng['waiting_max']:.0f}  "
        f"kv max {eng['kv_max']:.1f}%  preemptions {eng['preemptions']}"
    )
    if eng["hit_samples"]:
        note = "  SUSPECT: recipe asks for prefix caching" if eng["cache_suspect"] else ""
        if not cacheable(grid):
            note = f"  (expected: prompt is under one {BLOCK_TOKENS}-token block)"
        print(f"cache:     hit rate max {eng['hit_max']:.1f}% over {eng['hit_samples']} samples{note}")

    for label, path in progress_files(out):
        head = f"{label} " if label else ""
        deg = degeneration(path)
        if deg:
            flag = (
                f"  {len(deg['bad'])}/{deg['n']} LOOPING (requests {deg['bad']}) — "
                "these decode faster and inflate tg"
                if deg["bad"]
                else ""
            )
            print(f"{head}text:      worst repeat {deg['worst']:.2f} over {deg['n']} requests{flag}")
        req = requests(path)
        if req:
            lo, mid, hi = req["rate"]
            print(f"{head}per-req:   decode {lo:.1f} / {mid:.1f} / {hi:.1f} tok/s over {req['n']} requests")
            if req["ttft"]:
                lo, mid, hi = req["ttft"]
                print(f"{head}           ttft   {lo:.2f} / {mid:.2f} / {hi:.2f} s  (min/median/max)")

    for row in spread(out):
        if row["metric"] == "prefill*":
            print(f"{row['label']} {row['phase']:<4} prefill*  {row['median']:8.1f} t/s  (true rate)")
            continue
        if row["iqr"] is None:
            spread_txt, verdict = "iqr   n/a", f"n={row['n']}, too few for quartiles"
        else:
            spread_txt = f"iqr {row['iqr'] * 100:4.1f}%"
            verdict = "stable" if row["iqr"] <= STABLE_IQR else "UNSTABLE"
        print(
            f"{row['label']} {row['phase']:<4} {row['metric']:<8} "
            f"median {row['median']:8.1f}  {spread_txt}  "
            f"max/min {row['ratio']:.2f}  n={row['n']}  {verdict}"
        )
        # Raw execution order, never sorted — the ordering is evidence.
        print("            " + " ".join(f"{v:.1f}" for v in row["values"]))
