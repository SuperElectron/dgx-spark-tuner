r"""R13b analysis — decompose the c5 span ratio into stagger and acceptance terms.

Identity, exact for equal per-request decode-token counts (guaranteed here by
`ignore_eos` + `min_tokens`, gate 3):

    span ratio = c * tg_req / tg = T / HM(d_i)

with T = max(last_token) - min(first_token) the batch decode span, d_i the
request's own decode duration, and HM the harmonic mean. Writing
f_i = first_token_i - min(first_token) for the first-token stagger,
T = max_i(f_i + d_i), so the ratio factors cleanly:

    span ratio = [max(f+d) / max(d)]  x  [max(d) / HM(d)]
                  \___ stagger ___/       \__ dispersion __/

The right factor is what MTP acceptance dispersion can buy: d_i is proportional
to that request's verify-step count S_i, so max(d)/HM(d) is the same statistic as
the zero-free-parameter prediction max(S) x mean(1/S).
"""

import json
import statistics
import sys


def hm(xs):
    return len(xs) / sum(1.0 / x for x in xs)


def analyse(rounds, phase):
    rows = []
    for r in rounds:
        st = r[phase]
        if st is None:
            continue
        raw = [x for x in r[f"{phase}_raw"] if not x["error"]]
        ts = [x["token_timestamps"] for x in raw]
        min_first = min(t[0] for t in ts)
        f = [t[0] - min_first for t in ts]
        d = [t[-1] - t[0] for t in ts]
        T = max(fi + di for fi, di in zip(f, d))
        steps = st["num_spec_steps"]

        rows.append({
            "tg": st["tg"],
            "tg_req": st["tg_req"],
            "span_obs": st["span_ratio_observed"],
            "span_identity": T / hm(d),
            "stagger_factor": max(fi + di for fi, di in zip(f, d)) / max(d),
            "dispersion_factor": max(d) / hm(d),
            "span_pred_steps": st["span_ratio_predicted"],
            "f_spread_ms": max(f) * 1000,
            "d_mean_s": statistics.fmean(d),
            "ttfr_ms": st["ttfr_ms"],
            "acc": st["acceptance_len"],
            "steps": steps,
            "acc_maxmin": st["acceptance_max_over_min"],
        })
    return rows


def med(rows, key):
    return statistics.median([r[key] for r in rows])


def show(label, rows, ref=None):
    print(f"\n===== {label}  (n={len(rows)} runs) =====")
    for k in ("tg", "tg_req", "span_obs", "span_identity", "stagger_factor",
              "dispersion_factor", "span_pred_steps", "f_spread_ms", "d_mean_s",
              "ttfr_ms", "acc_maxmin"):
        vals = [r[k] for r in rows]
        m = statistics.median(vals)
        sd = statistics.stdev(vals) if len(vals) > 1 else 0.0
        print(f"  {k:20s} median {m:9.3f}  sd {sd:8.3f}  "
              f"[{', '.join(f'{v:.3f}' for v in sorted(vals))}]")

    all_acc = [a for r in rows for a in r["acc"]]
    all_steps = [s for r in rows for s in r["steps"]]
    print(f"  per-request acceptance: n={len(all_acc)} "
          f"median {statistics.median(all_acc):.3f} "
          f"min {min(all_acc):.3f} max {max(all_acc):.3f} "
          f"sd {statistics.stdev(all_acc):.3f}")
    print(f"  per-request steps:      median {statistics.median(all_steps):.1f} "
          f"min {min(all_steps)} max {max(all_steps)}")

    span = med(rows, "span_obs")
    disp = med(rows, "dispersion_factor")
    stag = med(rows, "stagger_factor")
    print(f"\n  DECOMPOSITION of the excess span ({span:.3f} - 1 = {span - 1:.3f}):")
    print(f"    dispersion (MTP acceptance) : x{disp:.3f}  -> {(disp - 1) / (span - 1) * 100:5.1f}% of excess")
    print(f"    stagger (first-token spread): x{stag:.3f}  -> {(stag - 1) / (span - 1) * 100:5.1f}% of excess")
    print(f"    product {disp * stag:.3f} vs observed {span:.3f}")
    if ref:
        print(f"\n  vs R13 ({ref['label']}):")
        for k, v in ref["vals"].items():
            mine = med(rows, k)
            print(f"    {k:16s} R13 {v:8.3f}   probe {mine:8.3f}   {(mine / v - 1) * 100:+6.2f}%")


def main():
    data = json.load(open(sys.argv[1]))
    rounds = data["rounds"]
    show("PHASE 2  (tg128 @ d16384 c5 — R13's cell)", analyse(rounds, "inf"),
         ref={"label": "tg 164.27 / tg_req 50.50 / span 1.537",
              "vals": {"tg": 164.27, "tg_req": 50.50, "span_obs": 1.537}})
    show("PHASE 1  (ctx_tg128 @ d16384 c5)", analyse(rounds, "ctx"),
         ref={"label": "tg 160.67 / tg_req 48.73 / span 1.52",
              "vals": {"tg": 160.67, "tg_req": 48.73, "span_obs": 1.52}})


if __name__ == "__main__":
    main()
