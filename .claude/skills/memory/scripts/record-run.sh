#!/usr/bin/env bash
# Write one runs-table row into a HYPOTHESIS.md, between its markers:
#
#     <!-- RUNS:BEGIN -->
#     <!-- RUNS:END -->
#
#   record-run.sh <HYPOTHESIS.md> --run run-0001 [--changed t] [--why t]
#                 [--cell "d16384 c10"] [--pp n] [--tg n] [--ttfr n] [--bench id]
#
# Nothing outside the markers is touched. Inside them the script owns the
# table: it re-emits the header and rule, keeps the existing rows in order, and
# REPLACES the row whose run column matches — so recording the same run twice
# never duplicates it.
set -uo pipefail

file="" run="" changed="" why="" cell="" pp="" tg="" ttfr="" bench=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run)     run="${2:-}"; shift 2 ;;
    --changed) changed="${2:-}"; shift 2 ;;
    --why)     why="${2:-}"; shift 2 ;;
    --cell)    cell="${2:-}"; shift 2 ;;
    --pp)      pp="${2:-}"; shift 2 ;;
    --tg)      tg="${2:-}"; shift 2 ;;
    --ttfr)    ttfr="${2:-}"; shift 2 ;;
    --bench)   bench="${2:-}"; shift 2 ;;
    -*)        echo "record-run: unknown flag $1" >&2; exit 2 ;;
    *)         if [ -z "$file" ]; then file="$1"; shift
               else echo "record-run: unexpected argument $1" >&2; exit 2; fi ;;
  esac
done

[ -n "$file" ] && [ -n "$run" ] || {
  echo 'usage: record-run.sh <HYPOTHESIS.md> --run <id> [--changed t --why t --cell t --pp n --tg n --ttfr n --bench id]' >&2
  exit 2; }
[ -f "$file" ] || { echo "record-run: no such file: $file" >&2; exit 2; }
grep -q '<!-- RUNS:BEGIN -->' "$file" && grep -q '<!-- RUNS:END -->' "$file" || {
  echo "record-run: $file has no RUNS:BEGIN/RUNS:END markers" >&2; exit 2; }

cell_esc() { printf '%s' "${1:-}" | tr '\n' ' ' | sed 's/|/\\|/g'; }
row="| $(cell_esc "$run") | $(cell_esc "$changed") | $(cell_esc "$why") | $(cell_esc "$cell") | $(cell_esc "$pp") | $(cell_esc "$tg") | $(cell_esc "$ttfr") | $(cell_esc "$bench") |"

tmp="$(mktemp)"
awk -v run="$run" -v row="$row" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
/<!-- RUNS:BEGIN -->/ { print; inb = 1; n = 0; next }
/<!-- RUNS:END -->/ {
  print "| run | changed | why | cell | pp | tg | ttfr | bench |"
  print "|---|---|---|---|---|---|---|---|"
  for (i = 1; i <= n; i++) print rows[i]
  if (!done) print row
  inb = 0; print; next
}
{
  if (inb) {
    if (substr($0, 1, 1) != "|") next            # the block holds the table only
    split($0, f, "|"); key = trim(f[2])
    if (key == "run" || key ~ /^:?-+:?$/) next   # header and rule are re-emitted
    if (key == run) { rows[++n] = row; done = 1; next }
    rows[++n] = $0
    next
  }
  print
}
' "$file" >"$tmp" || { rm -f "$tmp"; echo "record-run: rewrite failed" >&2; exit 1; }

cat "$tmp" >"$file"
rm -f "$tmp"
echo "record-run: $run recorded in $file" >&2
