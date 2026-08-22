"""R13b probe — per-request MTP acceptance at c5, read from the response body.

Replicates llama-benchy's `tg128 @ d16384 c5` workload exactly (same corpus, same
PromptGenerator, same payload as `client.py:_build_generation_payload` with
exact_tg), then reads `metrics.speculative_decoding` off each streamed response's
final usage chunk. llama-benchy itself discards that field, which is why this
round cannot be run through `sparkrun benchmark perf`.

Requires the server to have been started with
`--per-request-spec-decode-metrics detailed`.

Run:  uvx --from llama-benchy python r13b-probe.py <base_url> <out.json>
"""

import asyncio
import json
import statistics
import sys
import time

import aiohttp

from llama_benchy.corpus import TokenizedCorpus
from llama_benchy.prompts import PromptGenerator

MODEL = "nvidia/Qwen3.6-35B-A3B-NVFP4"
BOOK_URL = "https://www.gutenberg.org/files/1661/1661-0.txt"
CONTEXT_LOAD_USER_MESSAGE = "."

DEPTH = 16384
PP = 2048
TG = 128
CONCURRENCY = 5
ROUNDS = 7


def build_payload(messages, max_tokens):
    """Verbatim from llama_benchy.client._build_generation_payload with exact_tg."""
    return {
        "model": MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": True,
        "return_token_ids": True,
        "stream_options": {"include_usage": True},
        "min_tokens": max_tokens,
        "ignore_eos": True,
    }


async def one_request(session, base_url, context_text, prompt_text, max_tokens, rid):
    messages = []
    if context_text:
        messages.append({"role": "system", "content": context_text})
    messages.append({"role": "user", "content": prompt_text or CONTEXT_LOAD_USER_MESSAGE})

    rec = {
        "rid": rid,
        "start_ts": None,
        "first_token_ts": None,
        "end_ts": None,
        "completion_tokens": None,
        "prompt_tokens": None,
        "token_timestamps": [],
        "spec": None,
        "error": None,
    }

    rec["start_ts"] = time.perf_counter()
    try:
        async with session.post(
            f"{base_url}/chat/completions", json=build_payload(messages, max_tokens)
        ) as resp:
            if resp.status != 200:
                rec["error"] = f"HTTP {resp.status}: {(await resp.text())[:400]}"
                rec["end_ts"] = time.perf_counter()
                return rec

            buffer = ""
            async for chunk in resp.content.iter_any():
                now = time.perf_counter()
                buffer += chunk.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        continue
                    try:
                        obj = json.loads(data)
                    except json.JSONDecodeError:
                        continue
                    choices = obj.get("choices") or []
                    if choices:
                        delta = choices[0].get("delta") or {}
                        content = delta.get("content") or delta.get("reasoning_content")
                        token_ids = choices[0].get("token_ids")
                        if content or token_ids:
                            if rec["first_token_ts"] is None:
                                rec["first_token_ts"] = now
                            n_tok = len(token_ids) if isinstance(token_ids, list) else 1
                            # llama_benchy.client._append_observed_token_timestamps
                            if n_tok == 1:
                                rec["token_timestamps"].append(now)
                            elif n_tok > 1:
                                ts_list = rec["token_timestamps"]
                                last = ts_list[-1] if ts_list else rec["first_token_ts"]
                                window = now - last
                                for i in range(n_tok):
                                    ts_list.append(last + window * (i + 1) / n_tok)
                    usage = obj.get("usage")
                    if usage:
                        rec["completion_tokens"] = usage.get("completion_tokens")
                        rec["prompt_tokens"] = usage.get("prompt_tokens")
                    metrics = obj.get("metrics")
                    if metrics and metrics.get("speculative_decoding"):
                        rec["spec"] = metrics["speculative_decoding"]
    except Exception as exc:  # noqa: BLE001
        rec["error"] = f"{type(exc).__name__}: {exc}"

    rec["end_ts"] = time.perf_counter()
    return rec


async def run_batch(session, base_url, pairs, prompt_mode):
    """prompt_mode 'ctx' = Phase 1 context load; 'inf' = Phase 2 inference."""
    tasks = []
    for i, (context, prompt) in enumerate(pairs):
        text = CONTEXT_LOAD_USER_MESSAGE if prompt_mode == "ctx" else prompt
        tasks.append(one_request(session, base_url, context, text, TG, i))
    return await asyncio.gather(*tasks)


def span_stats(recs):
    """Compute the span decomposition for one batch of c concurrent requests.

    span ratio == c * tg_req / tg, with tg the batch aggregate (total decode
    tokens over the whole batch span) and tg_req the mean per-request rate --
    the same identity RESULTS.md quotes.
    """
    good = [r for r in recs if r["error"] is None and r["completion_tokens"]]
    if len(good) != len(recs):
        return None

    if any(len(r["token_timestamps"]) < 2 for r in good):
        return None

    # llama_benchy.results: decode tokens = those strictly after the first
    # timestamp; batch span = max(last token) - min(first token), which excludes
    # prefill entirely. Getting this wrong makes tg look ~5x low at d16384.
    def decode_tokens(ts):
        return sum(1 for t in ts if t > ts[0])

    min_first = min(r["token_timestamps"][0] for r in good)
    max_last = max(r["token_timestamps"][-1] for r in good)
    observed_decode = sum(decode_tokens(r["token_timestamps"]) for r in good)
    tg_duration = max_last - min_first
    tg = observed_decode / tg_duration if tg_duration > 0 else 0.0

    per_req = []
    for r in good:
        ts = r["token_timestamps"]
        dur = ts[-1] - ts[0]
        n = decode_tokens(ts)
        if dur > 0 and n > 0:
            per_req.append(n / dur)
    tg_req = statistics.fmean(per_req)

    out = {
        "n": len(good),
        "tg": tg,
        "tg_req": tg_req,
        "span_ratio_observed": len(good) * tg_req / tg if tg else None,
        "tg_duration_s": tg_duration,
        "e2e_span_s": max(r["end_ts"] for r in good) - min(r["start_ts"] for r in good),
        "ttfr_ms": (max(r["first_token_ts"] for r in good)
                    - min(r["start_ts"] for r in good)) * 1000,
        "first_token_spread_ms": (
            max(r["token_timestamps"][0] for r in good) - min_first
        ) * 1000,
        "last_token_spread_ms": (
            max_last - min(r["token_timestamps"][-1] for r in good)
        ) * 1000,
        "per_req_decode_s": [r["token_timestamps"][-1] - r["token_timestamps"][0] for r in good],
        "completion_tokens": [r["completion_tokens"] for r in good],
        "prompt_tokens": [r["prompt_tokens"] for r in good],
    }

    # the acceptance-dispersion prediction: max(S) * mean(1/S)
    specs = [r["spec"] for r in good if r["spec"]]
    out["spec_present"] = len(specs)
    if len(specs) == len(good):
        steps = [s["num_spec_steps"] for s in specs]
        acc_len = [
            (s["num_accepted_draft_tokens"] + s["num_spec_steps"]) / s["num_spec_steps"]
            for s in specs
        ]
        draft_rate = [
            s["num_accepted_draft_tokens"] / s["num_draft_tokens"] if s["num_draft_tokens"] else 0.0
            for s in specs
        ]
        out["num_spec_steps"] = steps
        out["acceptance_len"] = acc_len
        out["draft_accept_rate"] = draft_rate
        out["acceptance_max_over_min"] = max(acc_len) / min(acc_len)
        out["span_ratio_predicted"] = max(steps) * statistics.fmean([1.0 / s for s in steps])
        out["steps_max_over_min"] = max(steps) / min(steps)
    return out


async def main():
    base_url = sys.argv[1].rstrip("/")
    out_path = sys.argv[2]

    print(f"corpus: {BOOK_URL}")
    corpus = TokenizedCorpus(BOOK_URL, None, MODEL)
    gen = PromptGenerator(corpus)
    print(f"corpus tokens: {len(corpus)}")

    connector = aiohttp.TCPConnector(limit=CONCURRENCY + 5, force_close=False, keepalive_timeout=600)
    timeout = aiohttp.ClientTimeout(total=900)
    results = {"config": {
        "depth": DEPTH, "pp": PP, "tg": TG, "concurrency": CONCURRENCY,
        "rounds": ROUNDS, "model": MODEL, "book_url": BOOK_URL,
    }, "rounds": []}

    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        for run in range(ROUNDS):
            pairs = gen.generate_batch(CONCURRENCY, PP, DEPTH, no_cache=False)
            print(f"\n=== run {run + 1}/{ROUNDS} ===")

            ctx_recs = await run_batch(session, base_url, pairs, "ctx")
            ctx = span_stats(ctx_recs)
            inf_recs = await run_batch(session, base_url, pairs, "inf")
            inf = span_stats(inf_recs)

            for label, st, recs in (("ctx", ctx, ctx_recs), ("inf", inf, inf_recs)):
                if st is None:
                    errs = [r["error"] for r in recs if r["error"]]
                    print(f"  {label}: FAILED {errs[:2]}")
                    continue
                print(
                    f"  {label}: tg={st['tg']:.2f} tg_req={st['tg_req']:.2f} "
                    f"span_obs={st['span_ratio_observed']:.3f} "
                    f"span_pred={st.get('span_ratio_predicted', float('nan')):.3f} "
                    f"ttfr={st['ttfr_ms']:.0f}ms "
                    f"ft_spread={st['first_token_spread_ms']:.0f}ms "
                    f"lt_spread={st['last_token_spread_ms']:.0f}ms\n"
                    f"        steps={st.get('num_spec_steps')} "
                    f"acc={[round(a, 3) for a in st.get('acceptance_len', [])]} "
                    f"tok={st['completion_tokens']}"
                )

            results["rounds"].append({
                "run": run,
                "ctx": ctx, "inf": inf,
                "ctx_raw": [{k: v for k, v in r.items()} for r in ctx_recs],
                "inf_raw": [{k: v for k, v in r.items()} for r in inf_recs],
            })
            with open(out_path, "w") as fh:
                json.dump(results, fh, indent=2)

    print(f"\nwrote {out_path}")


if __name__ == "__main__":
    asyncio.run(main())
