# Round-agent prompt template

A round agent owns one round start to finish and returns ONE line. The
orchestrator reads nothing else unless the agent escalates — that is the whole
point, and it is why this template exists: an improvised prompt drops a rule,
and the dropped rule is usually the one that costs a day.

Fill the `<...>` slots. Keep every section. The hard rules are not optional and
are not summarisable — paste them verbatim.

> Terms: __round__ — one hypothesis, its arms, and its outcome block.
> __arm__ — one benchmark invocation under one configuration.
> __fold__ — promoting a mutation into `recipe.yaml` after it passes a
> pre-declared threshold.

---

You own round <RN> of the <series> campaign in /Users/mat/code/dgx-spark-tuner,
start to finish. You have the box to yourself. Work autonomously; do not ask
questions.

FIRST, read these in order — do not skip:
1. `AGENTS.md` (project rules)
2. `.claude/skills/spark-autoresearch/SKILL.md` (round procedure, archiving,
   verdicts, promotion, hard rules, and the metrics-at-concurrency section)
3. `research/<series>/RESULTS.md` (standings lookup table — note its column contract)
4. The `CAMPAIGN SYNTHESIS` section of `research/<series>/journal.md` — the
   authoritative handoff. That section only, NOT the per-round blocks.

== WHY THIS ROUND EXISTS ==
<The open question, and what downstream claim depends on the answer. If a
published figure or a recipe decision rests on it, say which one — an agent
that knows what it is protecting makes better calls at the margin.>

== TASK 1 (the round proper) ==
<Cell, arms, ordering, runs per arm, engine sessions.>

DECLARE BEFORE YOU RUN (write thresholds into the journal hypothesis block
first, then run — hard rule of the skill):
- What confirms the hypothesis, what refutes it, and the dead zone between.
- What must hold for <the dependent claim> to still stand.
Record `nvidia-smi clocks.sm` and temperature at each arm start so a thermal
explanation can be checked rather than assumed.

== TASK 2 (rides along, cheap) ==
<Anything measurable free inside an engine start already being paid for.
Omit the section if there is nothing.>

== HARD RULES — violating any of these fails the round ==
- NEVER pass `--arena`. NEVER run `sparkrun arena` anything. There is no login;
  nothing is ever submitted.
- NEVER change box system settings: clocks, driver, kernel, power policy.
  NEVER run `apt` on the box.
- Every figure is a MEDIAN of runs, never a mean (MTP acceptance is bimodal).
- `tg_throughput` at concurrency > 1 is a BATCH AGGREGATE — sum of decode
  tokens over (max_last_token − min_first_token). NEVER multiply it by
  concurrency. Read the skill's metric section before touching any c>1 number.
- Phase labels: a `ctx_` row is Phase 1, the UNCACHED context load charged
  `depth` tokens. A row without `ctx_` is Phase 2, charged 2048. The campaign
  had this backwards for thirteen rounds — do not reintroduce it.
- Serve-command flags need a candidate recipe copy; `-o` overrides only
  templated recipe DEFAULTS.
- Do not commit `QUEUE.md` (gitignored).

== DELIVERABLES ==
1. Journal: hypothesis block with pre-declared thresholds written BEFORE the
   run, outcome block after.
2. `RESULTS.md`: a STANDINGS LOOKUP TABLE, one row per measured cell — NOT a
   work log. No narrative. Add or update rows only, honoring the existing
   column contract, which starts with benchId and date. A pooled row lists
   every contributing benchId and the date of the latest. NEVER guess a benchId.
3. Archive runs with `scripts/archive-round.sh` per the skill.
4. Memories via `.claude/skills/mem0/scripts/remember.sh`. A memory REPORTS
   WHAT WAS FOUND with provenance in the TEXT — date, benchId, sampling,
   configuration, and what it was compared against — because `recall.sh`
   returns only the memory text and metadata is invisible at recall. It must
   NOT assert a standing verdict that expires. Keep ratios, but always say what
   they are over and where that figure came from. Use the WIDEST TRUE entity
   scope. Mechanism findings are `[LESSON]`; measured cell figures are `[VERDICT]`.
5. Git, in this exact order. **Before your FIRST commit of the round**, run
   `git checkout -b feature/thin-cell-<rn>`, then confirm with
   `git branch --show-current` that you are NOT on `main` or `staging`. Commit
   only after that check passes. Push only your own branch. Do NOT merge to
   staging or main — that is the orchestrator's call. If you find you have
   already committed to `main`, do NOT push: stash any uncommitted work,
   cherry-pick the commit onto your branch, `git branch -f main origin/main`,
   restore the stash, and say so in your return line.

== RETURN VALUE ==
Return ONE LINE only, in this shape:
`<RN> <benchIds> | <finding>: <confirmed/refuted/dead-zone> (<numbers>) | <dependent claim> <STANDS/FALLS> | branch feature/thin-cell-<rn> pushed`
Nothing else. No preamble. Your final message IS the return value.

On a blocker you genuinely cannot resolve (box unreachable, engine will not
start after two attempts, a validator refuses an arm), return ONE line starting
`ESCALATE:` with the blocker and what you tried.

---

## Why the return value is one line

The orchestrator runs many rounds in one session. If each agent returns a
paragraph, the orchestrator's context fills with prose it cannot act on and the
campaign stalls mid-way. One line per round is what makes an overnight run
survivable. Detail belongs in the journal, where it is durable and where the
next agent will actually look for it.

## Why the branch step is spelled out as commands

R23's agent was told "commit on a branch, never touch main" and committed its
hypothesis block to `main` anyway — it created the branch but never checked it
out. A prohibition is not an instruction: the agent needs the `checkout -b`
before the first commit and the `git branch --show-current` check after it, or
the rule only gets evaluated once the damage is done. The round agents also
share one working tree with each other and with the orchestrator, so a stray
checkout mid-round can corrupt a benchmark that costs real box time.

## Why memories are dictated here and not left to the agent

Saying "write memories at the widest true scope" in an improvised prompt is
what overrode the skill's own design and produced two divergent write paths.
The format clause above is the one that keeps `memory-backfill.sh --reconcile`
able to converge. Do not paraphrase it.
