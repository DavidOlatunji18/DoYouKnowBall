#!/usr/bin/env python3
"""Validate every seed question file under seed/.

Checks: required fields with the right types, no empty strings, exactly 4 distinct
options, correctIndex 0-3, difficulty 1-3, length limits matching the database, and
no duplicate question text anywhere. Exits non-zero if anything fails.

Usage: python3 seed/validate.py
"""
import json
import sys
from collections import Counter
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parent
FIELDS = {"sport": str, "category": str, "text": str, "options": list, "correctIndex": int, "difficulty": int}
MAX_LEN = {"sport": 50, "category": 100, "text": 500, "option": 200}


def check_item(item, where):
    if not isinstance(item, dict):
        return [f"{where}: expected an object"]
    errors = []
    missing = FIELDS.keys() - item.keys()
    extra = item.keys() - FIELDS.keys()
    if missing:
        errors.append(f"{where}: missing {sorted(missing)}")
    if extra:
        errors.append(f"{where}: unexpected {sorted(extra)}")
    for field, kind in FIELDS.items():
        value = item.get(field)
        # bool is a subclass of int, so reject it explicitly.
        if field in item and (not isinstance(value, kind) or isinstance(value, bool)):
            errors.append(f"{where}: '{field}' must be a {kind.__name__}")
    if errors:
        return errors

    for field in ("sport", "category", "text"):
        if not item[field].strip():
            errors.append(f"{where}: '{field}' is empty")
        elif len(item[field]) > MAX_LEN[field]:
            errors.append(f"{where}: '{field}' is longer than {MAX_LEN[field]} characters")

    options = item["options"]
    if len(options) != 4:
        errors.append(f"{where}: needs exactly 4 options, has {len(options)}")
    if any(not isinstance(o, str) or not o.strip() for o in options):
        errors.append(f"{where}: options must be non-empty strings")
    else:
        if len({o.strip().casefold() for o in options}) != len(options):
            errors.append(f"{where}: options are not distinct")
        if any(len(o) > MAX_LEN["option"] for o in options):
            errors.append(f"{where}: an option is longer than {MAX_LEN['option']} characters")

    if not 0 <= item["correctIndex"] <= 3:
        errors.append(f"{where}: correctIndex must be 0-3")
    if not 1 <= item["difficulty"] <= 3:
        errors.append(f"{where}: difficulty must be 1-3")
    return errors


def main():
    files = sorted(p for p in SEED_DIR.rglob("*.json") if not p.name.endswith(".schema.json"))
    if not files:
        print("No seed files found.")
        return 1

    errors = []
    seen_text = {}
    total = 0
    for path in files:
        rel = path.relative_to(SEED_DIR)
        try:
            items = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{rel}: invalid JSON ({e})")
            continue
        if not isinstance(items, list):
            errors.append(f"{rel}: top level must be an array")
            continue

        for i, item in enumerate(items):
            where = f"{rel}[{i}]"
            item_errors = check_item(item, where)
            errors.extend(item_errors)
            if item_errors:
                continue
            key = item["text"].strip().casefold()
            if key in seen_text:
                errors.append(f"{where}: duplicate question text (also {seen_text[key]})")
            else:
                seen_text[key] = where

        valid = [i for i in items if isinstance(i, dict) and not check_item(i, "")]
        groups = Counter((i["sport"], i["category"]) for i in valid)
        difficulty = Counter(i["difficulty"] for i in valid)
        print(f"{rel}: {len(items)} questions {dict(groups)} difficulty {dict(sorted(difficulty.items()))}")
        total += len(items)

    if errors:
        print(f"\n{len(errors)} problem(s):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"\nOK: {total} questions in {len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
