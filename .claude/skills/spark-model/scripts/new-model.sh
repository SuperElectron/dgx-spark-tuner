#!/usr/bin/env bash
# Create a model directory from the template beside this script.
#
#   new-model.sh <model>
#
# Lays down the skeleton only. The docs and the baseline recipe are settled
# with the user; this script does not write them.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="${1:?usage: new-model.sh <model>}"
dest="$(git rev-parse --show-toplevel)/research/$name"

mkdir "$dest"
cp -R "$here/_template/." "$dest/"
sed -i '' "s|<model>|$name|" "$dest/RESULTS.md"

echo "created $dest"
echo "next: with the user, write docs/model-card.md, docs/arena-recipe.md, and recipe.yaml"
