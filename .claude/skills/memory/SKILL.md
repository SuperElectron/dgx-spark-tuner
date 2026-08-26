---
name: memory
description: The research memory — recall what earlier rounds measured before committing a run to a lever, write what this round measured in a form another round can judge, and promote the few findings that hold wider. Use before writing a hypothesis, at every RECORD, and at round close.
when_to_use: Before writing a hypothesis or picking the next lever; at CREATE, to see whether this run has already been done; at RECORD, to write what the run measured; at round close, to promote or prune. Any question of the form "have we measured this before".
allowed-tools: Bash(.claude/skills/memory/scripts/*) Bash(../memory/scripts/*) Bash(scripts/*) Bash(jq *) Read Grep Glob
disallowed-tools: WebFetch WebSearch
---

# memory

The memory is what stops a round re-deriving a figure it already owns, and what
stops it trusting one it should not. Both halves are load-bearing: a recall that
is never done costs runs, and a recall that is believed uncritically costs a
whole round.

Worked example of the second failure, and the reason this skill exists: two
memories said "match `max_num_seqs` to probe concurrency, raise both knobs
together". Both predated the concurrency experiment. `h1` read them, spent a
full round on `max_num_batched_tokens`, and got the sign backwards. `h2` read
the same store, checked the dates and the cells, went at `max_num_seqs`, and got
2.89x. The store held the answer both times. Only one round asked it properly.

## Standing rules

- **Recall before every hypothesis, and at CREATE.** Widest scopes first, and
  the widest scope is `recall.sh --list '' 2000` with no filter — `--filter`
  excludes any record missing the key, so it cannot see a legacy or cross-model
  memory. Narrow only after the wide pass. A round that starts without a recall
  is a round betting its runs on nothing.
- **No decision rests on a summary line.** The default output is a scan format.
  `--get <id>` the record before any lever choice, and read its date and its
  config — a memory can predate the experiment that would have refuted it. Date
  it by `created_at`, which every record carries; `metadata.date` is on
  schema-1 writes only.
- **A write carries its config or it is not comparable.** `remember.sh` refuses
  a write missing the fields its class needs. That refusal is the contract
  working, not an obstacle to route around.
- **Tier 1 is written at every RECORD, not once at close.** Memory is the
  round's notebook. It is not a prose summary written afterwards.
- **Promotion at round close is what bounds the bloat.** Volume rises through a
  round and falls at its end. Review tier 1, promote what holds wider, delete
  the rest.
- **The runs table is script-written.** `record-run.sh` owns the block between
  the RUNS markers. Never hand-edit a row.
- **The embedder shares the card with every benchmark.** `memory.sh start` only
  when a semantic search needs it, `memory.sh stop` before any run. `--list`,
  `--get` and `--filter` need no embedder, which is the usual state.
- **Memory never blocks work.** `remember.sh` and `recall.sh` exit 0 with the
  service down. Check stderr: a 2xx is not proof you can read it back.

## Scripts

```
scripts/memory.sh   start|stop                       embedder up / card freed
scripts/recall.sh   "<query>" [entity] [k]           semantic — needs start
scripts/recall.sh   --list [entity] [limit]          no embedder needed
scripts/recall.sh   --get <id>                       one full record, JSON
                    ... [--json] [--filter k=v,k=v]
scripts/remember.sh "<text>" <entity> [--meta k=v ...]
scripts/record-run.sh <HYPOTHESIS.md> --run <id> [--changed t --why t --cell t
                      --pp n --tg n --ttfr n --bench id]
scripts/forget.sh   [--yes] <id>...                  refuses without --yes
```

A scan pipes into a prune: `recall.sh --list round:decode-tg/h1 | cut -f1 |
forget.sh --yes -`.

## The four markers

`[OBSERVATION]` `[ENV]` `[LESSON]` `[IDEA]`. Nothing else is accepted, and
`[EXPERIMENT]` is retired. Each carries required metadata — see
[references/write.md](references/write.md).

## Detail

- [references/write.md](references/write.md) — the metadata contract, every
  meta key, the per-class guards, the exit codes, and how to pick an entity.
- [references/recall.md](references/recall.md) — scan vs `--get`, the filters,
  and the discipline of questioning what comes back.
- [references/tiers.md](references/tiers.md) — the three tiers, what each is
  written by and when, and how promotion at round close bounds the volume.
