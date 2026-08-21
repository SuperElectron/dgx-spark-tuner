#!/usr/bin/env bash
set -euo pipefail

name="${1:?usage: new-experiment.sh <model>-<cell>}"
root="$(git rev-parse --show-toplevel)"
dest="$root/research/$name"

[ -e "$dest" ] && { echo "error: $dest already exists" >&2; exit 1; }
cp -r "$root/research/_template" "$dest"

echo "created $dest"
echo "next: fill docs/ (model-card.md, arena-recipe.md), set recipe.yaml, journal round 0 (baseline)"
