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
    records: list[dict[str, str]] = []

    for cmake_file in sorted(repo.rglob("CMakeLists.txt")):
        if any(part.startswith("build") for part in cmake_file.relative_to(repo).parts):
            continue
        text = cmake_file.read_text(encoding="utf-8")
        relative = cmake_file.relative_to(repo).as_posix()
        for match in PATTERN.finditer(text):
            parts = cmake_file.relative_to(repo).parts
            category = parts[1] if len(parts) > 2 and parts[0] == "plugins" else parts[0]
            records.append(
                {
                    "target": match.group(1),
                    "category": category,
                    "cmake_file": relative,
                    "initial_profile": "review",
                }
            )

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
