# R13b provenance — what produced the data in this directory

R13b measured **per-request MTP acceptance**, which llama-benchy does not
expose. It therefore ran no sparkrun grid and has no benchId, and the data here
came from two purpose-built scripts rather than from the usual harness.

Both scripts now live in the series `scripts/` directory:

- `research/qwen36-35b-nvfp4-cells/scripts/r13b-probe.py` — drove the engine
  directly and wrote `probe-results.json`.
- `research/qwen36-35b-nvfp4-cells/scripts/r13b-analyse.py` — read
  `probe-results.json` and produced `analysis.txt`.

The recipe the round served under is here twice, byte-identical: as
`recipe-used.yaml`, written by the probe run itself, and as
`recipe-r13b-perreq.yaml`, moved in from the series root. The second keeps the
name the journal and QUEUE.md refer to; neither is a rename of the other.

⚠ `recipe-r13b-perreq.yaml` is an **instrument, not a candidate** — it must
never be folded into `recipe.yaml`. The flag's overhead was never measured.
