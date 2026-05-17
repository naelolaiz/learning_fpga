#!/usr/bin/env python3
"""Validate netlistsvg output for gallery-facing labels.

The label/link edits happen in netlistsvg itself. This helper is only
a guardrail: after rendering, make sure the SVG is parseable XML, no
visible cell nodelabel still exposes a raw yosys `$...` type, and all
hierarchical submodule cells are wrapped in SVG/fragment links.
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


def _attr_by_local_name(elem: ET.Element, name: str) -> str:
    for key, value in elem.attrib.items():
        if _local_name(key) == name:
            return value
    return ""


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


def _nodelabel(elem: ET.Element) -> str:
    cell_id = elem.get("id", "")
    cell_class = cell_id.replace("cell_", "cell_", 1)
    for child in elem:
        if _local_name(child.tag) != "text":
            continue
        classes = child.get("class", "").split()
        if "nodelabel" in classes and (not cell_class or cell_class in classes):
            return _text_content(child)
    return ""


def _unlinked_submodules(root: ET.Element) -> list[tuple[str, str]]:
    missing: list[tuple[str, str]] = []
    parent_map = {child: parent for parent in root.iter() for child in parent}

    for elem in root.iter():
        cell_type = _attr_by_local_name(elem, "type")
        cell_id = elem.get("id", "")
        if (
            cell_type.startswith("sub_")
            and cell_id.startswith("cell_")
            and _local_name(parent_map.get(elem, ET.Element("")).tag) != "a"
        ):
            missing.append((cell_id.removeprefix("cell_"), _nodelabel(elem)))

    return missing


def _href(elem: ET.Element) -> str:
    for key, value in elem.attrib.items():
        if _local_name(key) == "href":
            return value
    return ""


def _non_svg_submodule_links(root: ET.Element) -> list[tuple[str, str, str]]:
    bad: list[tuple[str, str, str]] = []
    parent_map = {child: parent for parent in root.iter() for child in parent}

    for elem in root.iter():
        cell_type = _attr_by_local_name(elem, "type")
        cell_id = elem.get("id", "")
        if not (cell_type.startswith("sub_") and cell_id.startswith("cell_")):
            continue
        parent = parent_map.get(elem)
        if parent is None or _local_name(parent.tag) != "a":
            continue
        href = _href(parent)
        if href.startswith("#") or ".svg" in href.lower():
            continue
        bad.append((cell_id.removeprefix("cell_"), _nodelabel(elem), href))

    return bad


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

    ok = True

    leaks = _raw_dollar_nodelabels(root)
    if leaks:
        ok = False
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

    unlinked = _unlinked_submodules(root)
    if unlinked:
        ok = False
        print(
            f"check_netlistsvg_labels: {path}: {len(unlinked)} "
            "hierarchical submodule cell(s) are not linked:",
            file=sys.stderr,
        )
        for cell_id, label in unlinked:
            suffix = f" ({label})" if label else ""
            print(f"    cell_{cell_id}{suffix}", file=sys.stderr)
        print(
            "  Fix automatic netlistsvg decoration or add an explicit "
            "SVG_LINKS/V_SVG_LINKS entry.",
            file=sys.stderr,
        )

    bad_links = _non_svg_submodule_links(root)
    if bad_links:
        ok = False
        print(
            f"check_netlistsvg_labels: {path}: {len(bad_links)} "
            "hierarchical submodule link(s) do not target an SVG or "
            "same-file SVG fragment:",
            file=sys.stderr,
        )
        for cell_id, label, href in bad_links:
            suffix = f" ({label})" if label else ""
            print(f"    cell_{cell_id}{suffix}: {href}", file=sys.stderr)
        print(
            "  Fix automatic netlistsvg decoration/internal views or add "
            "an explicit SVG_LINKS/V_SVG_LINKS entry to an SVG target.",
            file=sys.stderr,
        )

    return ok


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
