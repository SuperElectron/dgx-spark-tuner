#!/usr/bin/env bash
# Create a hypothesis directory and its EXPERIMENT.md.
#
#   new-hypothesis.sh <hypothesis-dir>
#
# EXPERIMENT.md comes from the template beside this script. The baseline,
# <hypothesis-dir>/recipe.yaml, is settled with the user — not written here.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:?usage: new-hypothesis.sh <hypothesis-dir>}"
dir="${dir%/}"

mkdir -p "$(dirname "$dir")"
mkdir "$dir"
sed "s|<hypothesis-id>|$(basename "$dir")|" "$here/EXPERIMENT.md" > "$dir/EXPERIMENT.md"

echo "created $dir"
echo "next: with the user, write the claim and the decision rule in $dir/EXPERIMENT.md, then agree $dir/recipe.yaml"
