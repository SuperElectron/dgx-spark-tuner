# Writing the comparison up

The reader is deciding what to publish. Copy
[`assets/results-example.md`](../assets/results-example.md) — a real filled
report — and replace the numbers. It is the template; the section order is
what makes two reads a month apart comparable.

## Where it goes

```bash
mkdir -p .cache/results
OUT=".cache/results/$(date +%Y-%m-%d-%H%M).md"
```

Hyphens, no spaces. One file per read, **never overwrite an earlier one** —
the board moves continuously, so the series is the record of whether we are
gaining ground. Put the read time in the first line too, so a file separated
from its name still dates itself.

## Rules that earn their keep

- **Prefix every column `our-` or `their-`.** A bare "board rank" header was
  asked about twice; ownership is not guessable.
- **Lead with `our-rank-peers`**, not the all-models rank. The board's top is
  small models, so the all-models rank flatters nobody running a large one.
- **Bold positive deltas.** When two rows of twenty-eight are wins, they must
  be findable at a glance.
- **Link `their-best`** to `https://spark-arena.com/benchmark/<benchmarkId>`.
- **Generate rows from the cached JSON.** Twenty-eight rows of transcription
  is twenty-eight chances to publish a wrong number.
- **Call a win inside our own scatter a tie.** It is one.

## Sections beyond the grid

- **Wins** — counted honestly.
- **Best placings** — where we rank well even if no round targeted it. Often
  the most useful thing in the document.
- **Who we are up against** — collapse leaders by `benchmarkId`. One
  submission leading most cells is the most actionable fact available: its
  recipe beats another round.
- **Shape** — read by row and column. A uniformly weak column or a collapsed
  corner is a mechanism; scattered deltas are noise.

## What must not appear

- Our `pp` or `ttfr` presented as board-comparable.
- A figure from a run that was not on arena's unmodified grid.
- A margin computed against a stored scrape.
- A "no competitor" claim. Absence in *our* data is not absence on the board.
