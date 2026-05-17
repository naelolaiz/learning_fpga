#!/usr/bin/env python3
"""Validate netlistsvg output for gallery-facing labels.

The label/link edits happen in netlistsvg itself. This helper is only
a guardrail: after rendering, make sure the SVG is parseable XML and
that no visible cell nodelabel still exposes a raw yosys `$...` type.
"""
import argparse
from collections import Counter
from pathlib import Path
import sys
from xml.etree import ElementTree as ET


def _local_name(tag: str) -> str:
    """Return the XML local name for either namespaced or plain tags."""
    return tag.rsplit("}", 1)[-1]


def _text_content(elem: ET.Element) -> str:
    return "".join(elem.itertext()).strip()


def _raw_dollar_nodelabels(root: ET.Element) -> Counter:
    leaks = Counter()
    for elem in root.iter():
        if _local_name(elem.tag) != "text":
            continue
        classes = elem.get("class", "").split()
        if "nodelabel" not in classes:
            continue
        label = _text_content(elem)
        if label.startswith("$"):
            leaks[label] += 1
    return leaks


def validate(path: Path) -> bool:
    try:
        svg = path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"check_netlistsvg_labels: {path}: {e}", file=sys.stderr)
        return False

    try:
        root = ET.fromstring(svg)
    except ET.ParseError as e:
        print(
            f"check_netlistsvg_labels: {path}: invalid XML at "
            f"line {e.position[0]}, col {e.position[1]}: {e}",
            file=sys.stderr,
        )
        return False

    leaks = _raw_dollar_nodelabels(root)
    if not leaks:
        return True

    print(
        f"check_netlistsvg_labels: {path}: {sum(leaks.values())} "
        "nodelabel(s) still expose raw yosys cell types:",
        file=sys.stderr,
    )
    for label, count in leaks.most_common():
        print(f"    {count:4d}  {label!r}", file=sys.stderr)
    print(
        "  Fix the netlistsvg label beautifier or add an explicit "
        "SVG_RELABEL/V_SVG_RELABEL entry.",
        file=sys.stderr,
    )
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("svg_path", nargs="+", type=Path)
    args = parser.parse_args()

    ok = True
    for path in args.svg_path:
        ok = validate(path) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
