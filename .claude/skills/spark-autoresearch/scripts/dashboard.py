#!/usr/bin/env python3
"""Render all archived benchmark runs to a local HTML page and open it.

Usage: dashboard.py [--no-open]
Reads research/*/experiments/*/ exports + RESULTS.md rows. Data only.
"""
import glob
import json
import os
import statistics
import subprocess
import sys
import webbrowser

root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()


def load_series():
    out = {}
    for res in sorted(glob.glob(f"{root}/research/*/RESULTS.md")):
        series = os.path.basename(os.path.dirname(res))
        rows = []
        for line in open(res):
            if not line.startswith("| bench_"):
                continue
            c = [x.strip() for x in line.strip().strip("|").split("|")]
            rows.append({"bench": c[0], "date": c[1], "mutation": c[2], "note": c[-1]})
        for r in rows:
            d = f"{root}/research/{series}/experiments/{r['bench']}"
            r["phases"] = []
            for f in sorted(glob.glob(d + "/*.json")):
                if "consolidated" in f:
                    continue
                try:
                    for b in json.load(open(f))["benchmarks"]:
                        r["phases"].append({
                            "ctx": b.get("context_size", 0),
                            "prefill": bool(b.get("is_context_prefill_phase")),
                            "tg": [round(v, 2) for v in b["tg_throughput"]["values"]],
                            "pp": round(b["pp_throughput"]["mean"], 1) if "pp_throughput" in b else None,
                            "ttfr": round(b["ttfr"]["mean"], 1) if "ttfr" in b else None,
                        })
                    break
                except Exception:
                    continue
        if rows:
            out[series] = rows
    return out


def main_tg(r):
    decode = [p for p in r["phases"] if not p["prefill"]]
    return (decode or r["phases"] or [{}])[-1].get("tg", [])


PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>spark-tuner runs</title>
<style>
body{background:#141711;color:#E8EAE1;font:14px/1.5 ui-monospace,monospace;margin:0;padding:1.5rem}
h1{font-size:1.1rem}h2{font-size:.95rem;margin:2rem 0 .4rem;color:#8FD119}
table{border-collapse:collapse;width:100%%;font-size:.8rem}
th{color:#9AA18E;text-align:left;padding:.3rem .6rem;border-bottom:1px solid #2C3226;font-weight:600}
td{padding:.3rem .6rem;border-bottom:1px solid #20241C;font-variant-numeric:tabular-nums;vertical-align:top}
td.n{text-align:right}svg{background:#1C2018;border:1px solid #2C3226;border-radius:4px;margin:.3rem 0}
.muted{color:#9AA18E}
</style></head><body>
<h1>spark-tuner runs <span class="muted">— generated %(ts)s from research/*/experiments/</span></h1>
%(sections)s
<script>
function chart(id, meds, ranges, labels){
  const svg=document.getElementById(id); if(meds.length<1) return;
  const W=Math.max(500, meds.length*44+120), H=240, ml=44, mr=16, mt=14, mb=58;
  svg.setAttribute('width',W); svg.setAttribute('height',H);
  const all=ranges.flat().concat(meds);
  const lo=Math.floor(Math.min(...all)/5)*5-2, hi=Math.ceil(Math.max(...all)/5)*5+2;
  const x=i=>ml+(W-ml-mr)*(meds.length>1? i/(meds.length-1):0.5);
  const y=v=>mt+(H-mt-mb)*(1-(v-lo)/(hi-lo));
  let g='';
  for(let v=Math.ceil(lo/10)*10; v<=hi; v+=10)
    g+=`<line x1="${ml}" x2="${W-mr}" y1="${y(v)}" y2="${y(v)}" stroke="#2C3226"/>`+
       `<text x="${ml-6}" y="${y(v)+4}" text-anchor="end" font-size="10" fill="#9AA18E">${v}</text>`;
  meds.forEach((m,i)=>{
    const [a,b]=ranges[i];
    g+=`<line x1="${x(i)}" x2="${x(i)}" y1="${y(a)}" y2="${y(b)}" stroke="#6BA82A" stroke-width="2" opacity=".5"/>`;
    g+=`<circle cx="${x(i)}" cy="${y(m)}" r="4.5" fill="#8FD119"><title>${labels[i]}: ${m}</title></circle>`;
    g+=`<text x="${x(i)}" y="${H-mb+12}" text-anchor="end" font-size="8" fill="#9AA18E" transform="rotate(-45 ${x(i)} ${H-mb+12})">${labels[i]}</text>`;
  });
  svg.innerHTML=g;
}
</script>
%(calls)s
</body></html>"""


def render(data):
    sections, calls = [], []
    for si, (series, rows) in enumerate(data.items()):
        meds, ranges, labels, trs = [], [], [], []
        for r in rows:
            tg = main_tg(r)
            med = round(statistics.median(tg), 2) if tg else None
            if tg:
                meds.append(med)
                ranges.append([min(tg), max(tg)])
                labels.append(r["bench"].replace("bench_", "")[:10])
            decode = [p for p in r["phases"] if not p["prefill"]]
            p = (decode or [{}])[-1]
            trs.append(
                f"<tr><td>{r['bench']}</td><td>{r['date']}</td><td>{r['mutation']}</td>"
                f"<td class=n>{' / '.join(map(str, tg)) or '—'}</td><td class=n>{med or '—'}</td>"
                f"<td class=n>{p.get('pp') or '—'}</td><td class=n>{p.get('ttfr') or '—'}</td>"
                f"<td>{r['note']}</td></tr>"
            )
        sections.append(
            f"<h2>{series}</h2><svg id=c{si}></svg>"
            f"<table><tr><th>bench</th><th>date</th><th>mutation</th><th>tg runs</th>"
            f"<th>tg med</th><th>pp</th><th>ttfr ms</th><th>note</th></tr>{''.join(trs)}</table>"
        )
        calls.append(f"<script>chart('c{si}',{json.dumps(meds)},{json.dumps(ranges)},{json.dumps(labels)})</script>")
    import datetime
    return PAGE % {"ts": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), "sections": "".join(sections), "calls": "".join(calls)}


if __name__ == "__main__":
    data = load_series()
    out = f"{root}/.cache/runs-dashboard.html"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w").write(render(data))
    print(out)
    if "--no-open" not in sys.argv:
        webbrowser.open("file://" + out)
