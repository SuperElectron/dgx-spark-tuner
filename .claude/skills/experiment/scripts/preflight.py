#!/usr/bin/env python
"""Check a recipe can actually run, before anything reaches the box.

Everything here is static — Recipe.load plus the resolved BenchmarkSpec. No
SSH, no docker, no engine. It exists because a recipe that cannot resolve its
image fails ~14 minutes into a dispatched round with a docker error that reads
like a credentials problem, and the same answer was available on the laptop in
milliseconds.

    preflight.py <recipe.yaml> [...]

Exit 0 if every recipe passes, 1 otherwise. Each finding names the field.
"""

import re
import sys
from pathlib import Path

from sparkrun.core.recipe import Recipe
from sparkrun.core.benchmark_profiles import BenchmarkSpec


def check_image(recipe):
    """The image must resolve to something docker can actually pull.

    A bare container name is an alias, and aliases are only meaningful to a
    builder. `vllm-node` is the eugr runtime's own default and resolves only
    when the eugr builder is selected — which sparkrun does implicitly for
    recipe_version '1', or when the container is spelled out in full. At
    version '2' with neither, the alias goes to docker verbatim and the pull
    is denied.
    """
    container = recipe.container.strip()
    if recipe.builder or "/" in container:
        return []
    return [
        f"container {container!r} is an alias and no builder was selected "
        f"(recipe_version={recipe.recipe_version!r}, builder={recipe.builder!r}). "
        f"docker would be asked to pull {container!r} literally. "
        f"Fix: recipe_version: '1', or builder: eugr, or write the full ghcr path."
    ]


def check_grid(recipe):
    """Every benchmark dimension must be present and non-empty.

    `benchmark perf` silently defaults depth to 0 when the dimension is
    missing, which measures a different thing than intended and says nothing
    about it.
    """
    try:
        spec = BenchmarkSpec.from_recipe(recipe)
    except Exception as exc:
        return [f"benchmark block does not resolve: {exc}"]

    args = spec.args or {}
    findings = []
    for dim in ("pp", "tg", "depth", "concurrency"):
        if dim not in args:
            findings.append(f"benchmark.{dim} missing — it would silently default")
        elif not args[dim]:
            findings.append(f"benchmark.{dim} is empty")
    if not args.get("runs"):
        findings.append("benchmark.runs is 0 or missing")
    return findings


def check_command(recipe):
    """The served command must render — an unfilled placeholder is a dead run."""
    if not recipe.command:
        return ["no command template"]
    # Single-brace placeholders only. A `{{...}}` pair is an escaped literal —
    # speculative-config JSON is written that way and is not a placeholder.
    placeholders = re.findall(r"(?<!\{)\{([a-zA-Z_][a-zA-Z0-9_]*)\}(?!\})", recipe.command)
    return [
        f"command references {{{name}}} with no value in defaults"
        for name in sorted(set(placeholders))
        if name not in recipe.defaults
    ]


def preflight(path):
    try:
        recipe = Recipe.load(path)
    except Exception as exc:
        return [f"will not load: {exc}"]
    return check_image(recipe) + check_grid(recipe) + check_command(recipe)


def main(argv):
    if not argv:
        print(__doc__.strip())
        return 1

    failed = False
    for arg in argv:
        path = Path(arg)
        findings = preflight(path)
        if findings:
            failed = True
            print(f"FAIL {path}")
            for f in findings:
                print(f"     {f}")
        else:
            print(f"ok   {path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
