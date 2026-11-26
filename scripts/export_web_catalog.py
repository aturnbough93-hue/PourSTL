#!/usr/bin/env python3
"""Export the native seed recipes to the browser app's bundled catalog."""

import argparse
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
STRING = r'"(?:\\.|[^"\\])*"'
RECIPE = re.compile(
    rf"^        SeedRecipe\(\s+name: ({STRING}), glass: ({STRING}), method: ({STRING}),\s+"
    rf"instructions: ({STRING}),\s+garnish: ({STRING}|nil),\s+tags: (\[[^\n]*\]),\s+"
    r"lines: \[\n(.*?)^            \]\s+^        \),",
    re.MULTILINE | re.DOTALL,
)
LINE = re.compile(
    rf"\s*SeedLine\(({STRING}), ([\d.]+), ({STRING})"
    rf"(?:, optional: (true|false))?(?:, note: ({STRING}))?\),?\s*"
)
IMAGES = {
    "negroni": "negroni", "daiquiri": "daiquiri",
    "old-fashioned": "old-fashioned", "boulevardier": "boulevardier",
}


def slug(text):
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", folded.lower().replace("'", "")).strip("-")


def export():
    source = (ROOT / "PourSTL/Services/SeedData.swift").read_text()
    recipes = []
    for recipe in RECIPE.finditer(source):
        name, glass, method, instructions, garnish, tags, lines = recipe.groups()
        name = json.loads(name)
        recipe_id = slug(name)
        ingredients = []
        for line in lines.strip().splitlines():
            ingredient = LINE.fullmatch(line)
            if not ingredient:
                raise ValueError(f"Unsupported seed ingredient in {name}: {line}")
            label, amount, unit, optional, note = ingredient.groups()
            ingredients.append(dict(
                name=json.loads(label), amount=json.loads(amount), unit=json.loads(unit),
                optional=optional == "true", note=json.loads(note) if note else "",
            ))
        photo = IMAGES.get(recipe_id)
        recipes.append(dict(
            id=recipe_id, name=name, glass=json.loads(glass), method=json.loads(method),
            instructions=json.loads(instructions), garnish=None if garnish == "nil" else json.loads(garnish),
            tags=json.loads(tags), ingredients=ingredients, image=f"assets/{photo}.webp" if photo else None,
        ))
    if len(recipes) != len(re.findall(r"^        SeedRecipe\(", source, re.MULTILINE)) or not recipes:
        raise ValueError("Unsupported native seed recipe format")
    if len({recipe["id"] for recipe in recipes}) != len(recipes):
        raise ValueError("Duplicate recipe IDs")
    return (
        "// Generated from the native recipe library by scripts/export_web_catalog.py.\n"
        "const pourRecipeCatalog = " + json.dumps(recipes, ensure_ascii=False, indent=2) + ";\n"
        "if (typeof module === 'object' && module.exports) module.exports = pourRecipeCatalog;\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / "website/recipe-catalog.js"
    data = export()
    if args.check:
        if not path.exists() or path.read_text() != data:
            parser.exit(1, "Run python3 scripts/export_web_catalog.py to sync the browser catalog.\n")
    else:
        path.write_text(data)


if __name__ == "__main__":
    main()
