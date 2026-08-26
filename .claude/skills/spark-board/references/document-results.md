# Writing the comparison up

The reader is deciding what to publish. Make ownership of every number
obvious, make the honest rank the prominent one, and make each competitor
clickable.

## Where it goes

```
.cache/results/<YYYY-MM-DD-HHMM>.md
```

No spaces in the filename — hyphens only. One file per read; **never
overwrite an earlier one**. The board moves continuously, so each file is a
dated snapshot of where we stood against it, and the series is the record of
whether we are gaining or losing ground.

```bash
mkdir -p .cache/results
OUT=".cache/results/$(date +%Y-%m-%d-%H%M).md"
```

State the read time and that it came from a live pull in the first line of
the document, so a file separated from its filename is still self-dating.

## Column naming

Prefix every column **our-** or **their-**. Without it a reader cannot tell
whose rank a rank column holds — this was asked twice about an earlier draft
and the answer was not guessable from the header.

| column | meaning |
|---|---|
| `depth` | context already in the prompt. `d0` = none |
| `conc` | simultaneous requests |
| `our-<run>` | one column per board-comparable run |
| `our-best` | best of those runs |
| `our-run` | which run produced it |
| `our-rank-all` | our placing against every model in that cell |
| `our-rank-peers` | our placing among the peer set — **the honest one** |
| `their-best` | peer leader's score, linked to its benchmark page |
| `their-rank-all` | that peer's placing against every model |
| `delta` | our-best vs their-best |

Open with a legend table defining all of them, plus what `depth`, `conc` and
each run actually are, so the document stands alone without the campaign's
history.

## Formatting that earns its keep

- **Bold positive deltas.** When two rows of twenty-eight are wins, they must
  be findable at a glance.
- **Link `their-best`** to `https://spark-arena.com/benchmark/<benchmarkId>`
  so a competitor's run is one click away.
- **Generate rows from the cached JSON**, never by hand. Twenty-eight rows of
  transcription is twenty-eight chances to publish a wrong number.
- Record the read date and that it came from a live pull.

## Sections worth having

Beyond the grid:

- **Wins** — count them honestly, and say when a win sits inside our own
  scatter and is therefore a tie.
- **Best placings** — where we actually rank well, even if no round targeted
  it. This is often the most useful thing in the document.
- **Who we are up against** — collapse the leaders by `benchmarkId`. If one
  submission leads most cells, that is the single most actionable fact
  available: its recipe is worth more than another round.
- **Shape** — read the grid by row and column, not cell by cell. A column
  that is uniformly weak, or a corner that collapses, is a mechanism; a
  scatter of individual deltas is noise.

## What must not appear

- Any `pp` or `ttfr` of ours presented as board-comparable.
- Any figure from a run that was not on arena's unmodified grid.
- A margin computed against a stored scrape.
- A "no competitor" claim. Absence of an entry in *our* data is not absence
  on the board; check the cell before ever writing it.
