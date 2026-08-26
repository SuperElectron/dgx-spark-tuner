# Who may do what with memory

One question, answered in one read: **I am running skill X — what am I
permitted to do with the store?**

Every memory operation in this repo goes through `.claude/skills/memory/scripts/`.
No skill talks to the store any other way, and no skill carries its own copy of
a memory command. What follows is the access scope each skill holds.

## Every command runs from the repo root

There is one cwd convention and this is it. Scripts are reached as
`.claude/skills/<skill>/scripts/...`, from every skill, without exception.

This is not tidiness. A permission rule is matched against the **literal string**
of the command, with no path resolution: `../memory/scripts/recall.sh` and
`.claude/skills/memory/scripts/recall.sh` are two different commands to the
matcher and never cross-match. One convention is what makes a single rule cover
every caller.

## The matrix

| skill | recall | write | delete | record-run | embedder | migrate/regen |
|---|---|---|---|---|---|---|
| `memory` | all forms | all four markers | yes | yes | start + stop | yes |
| `experiment` | none | `[ENV]` only | no | no | **never** | no |
| `observe` | `--list` only | `[ENV]` only | no | no | **never** | no |
| `spark-hypothesis` | all forms, incl. semantic | `[OBSERVATION]` at `round:` | no | no | start + stop | no |
| `spark-autoresearch` | `--list` `--get` `--filter` | `[OBSERVATION]` at `round:`, `[LESSON]` at tier 2 | `prune-round.sh` only | yes | **stop only** | no |
| `spark-model` | none | none | no | no | no | no |
| `spark-board` | none | none | no | no | no | no |

Least privilege, derived from what each skill's workflow actually does. A blank
is not an oversight — it means no documented step in that skill touches memory.

## Per skill, in words

__`memory`__ — the owner. Every script, every form. It is the skill you invoke
when the operation itself is the task: a migration, a regeneration, a semantic
search, a considered deletion.

__`experiment`__ — runs the benchmark and reports the figures. It writes exactly
one thing: an `[ENV]` at `box:<alias>` when the box left its measurement band,
and only then. It does not recall, because it must not see the expected answer —
an agent that can read what the round hopes for can steer toward it. It never
deletes, never writes a runs row, and **never raises the embedder**.

__`observe`__ — sweeps the box at rest and writes what moved as `[ENV]` at
`box:<alias>`. Its recall is the read-back it diffs against: `--list` on the
box entity, which needs no embedder. Semantic search would buy it nothing and
cost the card.

__`spark-hypothesis`__ — the only skill with a legitimate reason to bring the
embedder up. It opens an experiment, and the recall that precedes a hypothesis
is the one case where you may not know what to ask for by name. So it gets every
recall form, semantic included — and it is bound to put the embedder back down
in the same breath. It writes `[OBSERVATION]` at `round:<exp>/h<N>` when it
concludes a round. It never deletes and never writes a runs row: it reads
`run-*/` and does not write there.

__`spark-autoresearch`__ — the round loop, and the only skill that deletes. It
recalls by `--list`, `--get` and `--filter`; it writes `[OBSERVATION]` per
RECORD at `round:<exp>/h<N>` and, at close, promotes `[LESSON]` to a tier-2
entity. It owns the runs table through `record-run.sh`. Its embedder grant is
`stop` and nothing else — it asserts the card is free at the start of every
round and has no reason ever to occupy it.

Deletion is through `prune-round.sh`, never `forget.sh` directly. See
[the wrapper](#the-wrapper-is-the-real-guard) below.

__`spark-model`__ — sets a model up once. Docs, a baseline recipe, a results
table. It runs nothing and no step of it touches the store.

__`spark-board`__ — reads a live HTTP endpoint at `spark-arena.com` and writes
`.cache/results/`. It touches neither the store nor the box. Its `curl` grant is
pinned to the arena host precisely so it cannot reach the store's own
`http://127.0.0.1:8888/memories` — which is a write and delete path — by a route
nobody intended.

## The embedder is a benchmark's roommate

`memory.sh start` raises a vLLM instance on the same GB10 that every benchmark
is timed on. A figure measured while it is up is a figure measured against a
shared card, and nothing in the results says so.

That single fact sets the whole column:

- a skill that **runs benchmarks** must never raise it — `experiment`, and
  `spark-autoresearch`, whose loop dispatches them
- a skill that **needs semantic search before any run exists** may raise it, and
  must lower it again — `spark-hypothesis`, at START only
- a skill that dispatches runs gets **`stop`**, so it can assert the card is
  free without ever being able to occupy it
- `--list`, `--get` and `--filter` need no embedder at all, which is why they
  are the default and the usual state

## What actually enforces this

Be precise about this, because the frontmatter reads stronger than it is.

__`allowed-tools` does not restrict anything.__ It is a **pre-approval** list: it
suppresses the permission prompt for the commands it names. Every other tool
stays reachable through the normal permission flow. A skill whose `allowed-tools`
omits `forget.sh` can still call `forget.sh` — it just gets asked first.

__`disallowed-tools` does remove a tool from the pool__ while the skill is
active. It is the only hard block available in frontmatter, and it is used here
for the operations where a prompt is not good enough: the embedder on the two
skills that run benchmarks, and `forget.sh` on `spark-autoresearch`. It is still
literal-string matching, so it blocks the spelling it names and not a creative
one.

__Both clear on the next user message.__ Neither survives the turn.

__Marker-class limits are a documented contract, not frontmatter.__ Nothing in
`allowed-tools` can express "`[ENV]` only" — the marker is an argument, and
argument pinning is defeated by a variable, a redirect or an extra space. What
does enforce itself is inside `remember.sh`: it rejects any text not opening
with one of the four markers (exit 3), and refuses a write missing the fields
that marker's class requires (exit 3). So the store cannot hold a malformed or
unstamped memory regardless of who wrote it. Which marker a given skill *ought*
to write is this document's job.

__Bash permission rules are not a security boundary__, and the docs say so. The
mechanism for a genuinely constrained destructive operation is a purpose-built
wrapper.

## The wrapper is the real guard

Deletion is the one irreversible operation here — the server keeps no undo — so
it is the one that gets a wrapper instead of a rule.

`prune-round.sh` takes the round entity and, before deleting anything:

- reads the round's memories back and **prints them**, ids and text
- **refuses** unless the promotion already exists — it looks for a memory at the
  wider entity whose `basis=` names this round, and stops if there is none
- **refuses** any entity that is not `round:<exp>/h<N>`, so a typo cannot aim it
  at a durable entity
- **prints and stops** unless `--confirm-destructive` is passed
- is a no-op on a round already pruned

This replaces `recall.sh --list <round> | cut -f1 | forget.sh --yes -`. That
pipeline looked safe because `forget.sh` refuses without `--yes` and prints what
it would delete — but the pipeline passes `--yes`, so the guard never fired and
the ids never reached the agent. The review step existed on paper only.

`spark-autoresearch` has `forget.sh` in `disallowed-tools` and `prune-round.sh`
in `allowed-tools`. `prune-round.sh` calls `forget.sh` internally, which is
unaffected: permission rules apply to the command the agent runs, not to what a
script spawns. The block forces the route, it does not break it.

## Order at round close

Promote, confirm the read-back, **then** prune. Never the other way, and never
without the middle step.

```bash
.claude/skills/memory/scripts/remember.sh "[LESSON] <what holds wider>" flag:<lever> \
  --meta date=<YYYY-MM-DD> --meta basis="<experiment>/h<N>: <cells and figures>"

.claude/skills/memory/scripts/recall.sh --list flag:<lever> 50

.claude/skills/memory/scripts/prune-round.sh round:<experiment>/h<N> \
  --promoted-to flag:<lever> --confirm-destructive
```

`basis=` is not decoration. It is the string `prune-round.sh` searches for to
prove the promotion happened, so a promotion written without it will not let the
prune proceed.

## Detail

- [write.md](write.md) — the metadata contract, every meta key, the per-class
  guards and the exit codes.
- [recall.md](recall.md) — scan vs `--get`, the filters, and questioning what
  comes back.
- [tiers.md](tiers.md) — the three tiers, and why promotion bounds the volume.
