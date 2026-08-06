#!/usr/bin/env python3
"""Generate a deterministic inventory of Krita MODULE plugin targets."""

from __future__ import annotations

import json
import pathlib
import re
import sys


PATTERN = re.compile(
    r"(?:kis_add_library|add_library)\s*\(\s*([A-Za-z0-9_]+)\s+MODULE\b",
    re.MULTILINE,
)


def main() -> int:
    repo = pathlib.Path(__file__).resolve().parents[3]
    output = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else repo / "packaging/ios/manifests/plugins.json"
    records_by_target: dict[str, dict[str, str]] = {}

    for cmake_file in sorted(repo.rglob("CMakeLists.txt")):
        if any(part.startswith("build") for part in cmake_file.relative_to(repo).parts):
            continue
        text = cmake_file.read_text(encoding="utf-8")
        relative = cmake_file.relative_to(repo).as_posix()
        for match in PATTERN.finditer(text):
            parts = cmake_file.relative_to(repo).parts
            category = parts[1] if len(parts) > 2 and parts[0] == "plugins" else parts[0]
            record = {
                "target": match.group(1),
                "category": category,
                "cmake_file": relative,
                "initial_profile": "review",
            }
            existing = records_by_target.get(record["target"])
            if existing and existing["cmake_file"] != record["cmake_file"]:
                raise RuntimeError(
                    f"MODULE target {record['target']} is declared in both "
                    f"{existing['cmake_file']} and {record['cmake_file']}"
                )
            records_by_target.setdefault(record["target"], record)

    records = list(records_by_target.values())
    records.sort(key=lambda item: (item["category"], item["target"]))
    document = {
        "schema": 1,
        "generated_by": "packaging/ios/scripts/inventory-plugins.py",
        "count": len(records),
        "plugins": records,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(records)} MODULE targets to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
