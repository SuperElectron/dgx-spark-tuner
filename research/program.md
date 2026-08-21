# program.md — the autoresearch loop

You (Claude) are the researcher. You run this loop from the laptop; the box
only measures. The goal: maximize the experiment's headline metric (tok/s
under its fixed probe) by tuning vLLM engine flags, one change at a time.

## Ground rules

- The box is reached ONLY through `./deploy/connect.sh ssh 'spark-tuner/bench.sh ...'`.
  Never start engines by hand mid-loop; every experiment must land in the ledger.
- `config.env` (model, probe definition) is the measurement protocol. Never
  change it within a series. A different model or cell = a new experiment dir.
- `results.tsv` is append-only history. Never edit past rows.
- One flag change per round, applied to the current `best.env`. Interaction
  experiments (two flags) only after both single-flag directions are measured.
- Crashes are data. Read the traceback, journal the lesson, mark the dead
  sub-space, move on. Never retry a crashed config unchanged.
- Never `apt` anything on the box. Never touch the driver, CUDA, or memory
  the scripts don't already manage.

## One round

1. Read `config.env`, `best.env`, the tail of `results.tsv`, and `journal.md`.
2. Consult `research/docs/` (parameters, box lore, image stack) and the
   experiment's `docs/` (model card, arena recipe).
3. Write to `journal.md` BEFORE running: the mutation, the hypothesis, the
   expected effect, citing prior rounds or docs.
4. Run:
   `./deploy/connect.sh ssh "spark-tuner/bench.sh $(cat best.env | xargs) <MUTATED_FLAG>=<value>"`
   (all of best.env plus exactly one changed/added flag)
5. Append the stdout row to `results.tsv` verbatim, then pull the full run
   logs into the experiment: `./deploy/connect.sh logs research/<name>/logs/`
   (each run lands as `logs/<ts>/` — engine.log, bench.log, start.log,
   flags.txt — with `<ts>` matching the row's ts column).
6. Decide:
   - tok/s better than best → run the SAME config once more (thermal noise is
     real). Both runs better → update `best.env`, journal the confirmation.
   - worse or equal → best.env untouched, journal the refutation.
   - CRASH / BENCH_FAIL → journal the traceback lesson.
7. Every ~5 rounds, write a synthesis in `journal.md`: confirmed effects, dead
   ends, the current best row, and the next 2–3 hypotheses ranked.

## Curve mode (single-parameter response curves)

When a flag proves sensitive (a mutation moved tok/s beyond noise), switch to
curve mode for it: pick 4–6 values spanning its legal range, run each through
bench.sh with everything else held at best.env, one round per value. Journal
the curve (where it saturates, where it cliffs) and set best.env to the knee.
This replaces blind single-step mutations for that flag — the pattern from
vLLM's `bench sweep`, without its machinery.

## Session protocol

- Session start: read the last synthesis in `journal.md` — that is your
  inherited state. Trust the ledger over your memory.
- Session end (or on request): write a synthesis + one-paragraph handoff.
- Never stop the loop yourself; the human stops it. If the box is unreachable
  or two consecutive rounds fail for non-config reasons, stop and report
  instead of burning rounds.

## Measurement discipline

- The probe is fixed; bench.sh guarantees identical start/measure/teardown.
- GPU temp is recorded per row — if a "regression" coincides with +10°C,
  suspect thermals and re-run before concluding.
- Image digest is pinned. If it ever changes, that is a new epoch: re-run
  best.env first, then continue; never compare across epochs.
