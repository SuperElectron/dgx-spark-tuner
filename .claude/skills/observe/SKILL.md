---
name: observe
description: Run a general observation pass over whatever artifacts are at hand — benchmark runs, telemetry, logs, eval outputs, model behavior, costs — hunting for improvement opportunities at every layer and recording them as memories. Use after significant runs, at synthesis points, when something looks odd, or on request ("what did we learn", "observation pass", "where could we improve").
---

# Observation pass

Verdicts answer "did the mutation work". This pass answers everything else:
what did the evidence show that nobody asked about, and where could things be
improved if we were willing to change anything — settings, weights, kernels,
process. It is a lens, not a checklist: apply it to whatever artifacts exist.

## How to run one

1. Gather what's at hand: run exports, telemetry logs, serve/container logs,
   eval outputs, journal entries, cost numbers, even error messages from
   failed rounds. Failed runs are often the richest.
2. Walk the layers below. For each, ask the three questions:
   - **Surprise**: what in the evidence is anomalous, unexplained, or
     contradicts an assumption we've been operating on?
   - **Headroom**: if we could change anything at this layer (not just what
     the current experiment allows), what would plausibly improve the
     metric, quality, cost, or reliability? What would it take?
   - **Blindness**: what is this layer NOT telling us because we never
     measured it? Name the missing instrument.
3. Scope each observation before recording: is it true only for this
   experiment, this checkpoint, the model family, the serving stack, or the
   box? Tag the widest entity it truly generalizes to (`experiment:` /
   `model:` / `family:` / `stack:` / `box:` — see the mem0 skill). A
   vLLM scheduler quirk is `stack:vllm`, not `experiment:...` — that's what
   lets the next model's loop find it. And recall at those wider scopes
   BEFORE the pass, so you extend knowledge instead of duplicating it.
4. Record. Every observation becomes a memory (single line, evidence-linked):
   - `[ENV]` — a fact about the environment as it is
   - `[LESSON]` — a generalization future work should inherit
   - `[IDEA]` — a candidate intervention outside current scope (system
     change, fine-tune, prune, quant recalibration, upstream patch, new
     instrument), with expected payoff and what decision/work it needs
   Plus a journal "Observations" section when working inside an experiment.
   An observation without evidence is a guess — link the run/log/number.

## The layers

- **Hardware**: clocks, power policy, thermals, memory bandwidth/pressure,
  storage. (Example catch: SM cap 2405/3003 MHz = ~10% decode left on the
  table.)
- **System**: kernel, drivers, page cache, container runtime, scheduling.
- **Serving stack**: runtime bugs/quirks, version deltas, kernel/backend
  choices, launch behavior. (Example: Ray OOM-kills on unified memory.)
- **Model**: architecture quirks, quant structure (what's quantized, what
  isn't), spec-decode acceptance, quality anomalies, load behavior. This is
  where train/fine-tune/prune/recalibrate ideas live — what would we change
  about the WEIGHTS if we could?
- **Workload & measurement**: does the benchmark measure what we think?
  Variance structure, prompt draws, warmup effects, comparability with
  others' numbers.
- **Process & cost**: where did harness tokens/wall-clock go; which rounds
  were avoidable with better recall; what should be automated.

## Discipline

- Empty passes are suspicious — telemetry always says something. If a layer
  yields nothing, say why (no instrument? genuinely quiet?).
- Don't act on out-of-scope ideas — record them as [IDEA] with the decision
  they need; system/box changes are always Mat's call.
- Prefer few sharp observations over many vague ones; dedupe against
  existing memories (recall first).
- This pass can run as a background agent after big runs — spawn one with
  the artifact paths and this skill.
