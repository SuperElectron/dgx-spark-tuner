#!/usr/bin/env bash
# Create an experiment directory, its EXPERIMENT.md, and its first round.
#
#   new-experiment.sh <experiment-dir>
#
# Templates come from beside this script. The baseline,
# <experiment-dir>/recipe.yaml, is settled with the user — not written here.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:?usage: new-experiment.sh <experiment-dir>}"
dir="${dir%/}"

mkdir -p "$(dirname "$dir")"
mkdir "$dir"
sed "s|<experiment-id>|$(basename "$dir")|" "$here/EXPERIMENT.md" > "$dir/EXPERIMENT.md"

mkdir "$dir/h1"
sed "s|h<N>|h1|" "$here/HYPOTHESIS.md" > "$dir/h1/HYPOTHESIS.md"

echo "created $dir with h1"
echo "next: with the user, write the objective, strategy and held in $dir/EXPERIMENT.md,"
echo "      agree $dir/recipe.yaml, then write the hypothesis in $dir/h1/HYPOTHESIS.md"
