#!/usr/bin/env bash
# Create the next run directory, seeded with a recipe.
#
#   new-run.sh <hypothesis-dir>                 seeds from recipe.yaml
#   new-run.sh <hypothesis-dir> recipe-new.yaml seeds from the proposed config
#
# Default is the baseline, never the previous run: a run inherits nothing it
# was not given deliberately. What this run changes is the caller's decision,
# from the claim and from every result so far.
set -euo pipefail

dir="${1:?usage: new-run.sh <hypothesis-dir> [source-recipe]}"
dir="${dir%/}"
source="${2:-recipe.yaml}"

last="$(find "$dir" -maxdepth 1 -type d -name 'run-*' | sort | tail -1)"
if [ -n "$last" ]; then
  next="$(printf 'run-%04d' $(( 10#${last##*run-} + 1 )))"
else
  next="run-0001"
fi

mkdir "$dir/$next"
cp "$dir/$source" "$dir/$next/recipe.yaml"

echo "created $dir/$next (from $source)"
echo "next: edit $dir/$next/recipe.yaml for this run, then dispatch it"
