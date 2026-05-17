#!/usr/bin/env python3
"""Add same-file SVG views for rendered netlistsvg submodules.

netlistsvg renders expanded hierarchy inline when hierarchy rendering is
enabled. This helper turns those already-rendered submodule regions into
addressable SVG fragments:

* add <view id="view_..."> elements whose viewBox frames each submodule;
* rewrite source-code placeholder links to those local fragments;
* wrap any unlinked submodule group with a local fragment link.

Existing links to other SVG files are left alone, so projects can still
drill into a separately generated diagram when that is intentional.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys
from xml.etree import ElementTree as ET


SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
S_NS = "https://github.com/nturley/netlistsvg"

ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)
ET.register_namespace("s", S_NS)

TRANSLATE_RE = re.compile(
    r"translate\(\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))"
    r"(?:[\s,]+([+-]?(?:\d+(?:\.\d*)?|\.\d+)))?\s*\)"
)
ID_SAFE_RE = re.compile(r"[^A-Za-z0-9_.-]+")
VIEW_PREFIX = "view_"
VIEW_MARKER = "data-netlistsvg-internal-view"
DEFAULT_MARGIN = 80.0


@dataclass
class SubmoduleView:
    elem: ET.Element
    parent: ET.Element
    link_parent: ET.Element | None
    view_id: str
    view_box: tuple[float, float, float, float]


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _qname(root: ET.Element, local: str) -> str:
    if root.tag.startswith("{"):
        namespace = root.tag[1:].split("}", 1)[0]
        return f"{{{namespace}}}{local}"
    return local


def _attr_by_local_name(elem: ET.Element, name: str) -> str:
    for key, value in elem.attrib.items():
        if _local_name(key) == name:
            return value
    return ""


def _float_attr(elem: ET.Element, name: str, default: float = 0.0) -> float:
    value = elem.get(name) or _attr_by_local_name(elem, name)
    if not value:
        return default
    m = re.match(r"\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))", value)
    return float(m.group(1)) if m else default


def _translate(elem: ET.Element) -> tuple[float, float]:
    transform = elem.get("transform", "")
    m = TRANSLATE_RE.search(transform)
    if not m:
        return 0.0, 0.0
    return float(m.group(1)), float(m.group(2) or 0.0)


def _format_num(value: float) -> str:
    if abs(value - round(value)) < 0.001:
        return str(int(round(value)))
    return f"{value:.3f}".rstrip("0").rstrip(".")


def _sanitize_id(parts: list[str]) -> str:
    raw = "__".join(parts)
    return VIEW_PREFIX + ID_SAFE_RE.sub("_", raw).strip("_")


def _is_submodule_group(elem: ET.Element) -> bool:
    return (
        _local_name(elem.tag) == "g"
        and _attr_by_local_name(elem, "type").startswith("sub_")
        and elem.get("id", "").startswith("cell_")
    )


def _body_rect(elem: ET.Element) -> ET.Element | None:
    fallback = None
    for child in elem:
        if _local_name(child.tag) != "rect":
            continue
        if fallback is None:
            fallback = child
        if _attr_by_local_name(child, "generic") == "body":
            return child
    return fallback


def _submodule_view_box(
    elem: ET.Element,
    abs_x: float,
    abs_y: float,
    margin: float,
) -> tuple[float, float, float, float]:
    body = _body_rect(elem)
    if body is None:
        width = _float_attr(elem, "width", 1.0)
        height = _float_attr(elem, "height", 1.0)
        x = y = 0.0
    else:
        x = _float_attr(body, "x", 0.0)
        y = _float_attr(body, "y", 0.0)
        width = _float_attr(body, "width", 1.0)
        height = _float_attr(body, "height", 1.0)

    # The nodelabel and port labels sit just outside the body rectangle.
    x -= margin
    y -= margin
    width += margin * 2
    height += margin * 2
    return abs_x + x, abs_y + y, max(width, 1.0), max(height, 1.0)


def _link_href(elem: ET.Element | None) -> str:
    if elem is None:
        return ""
    return elem.get(f"{{{XLINK_NS}}}href") or elem.get("href") or ""


def _set_link_href(elem: ET.Element, href: str) -> None:
    elem.set(f"{{{XLINK_NS}}}href", href)
    elem.set("href", href)


def _is_svg_link(href: str) -> bool:
    return ".svg" in href.lower()


def _should_rewrite_link(href: str) -> bool:
    if not href:
        return True
    if href.startswith("#"):
        return True
    if _is_svg_link(href):
        return False
    return True


def _collect_submodules(root: ET.Element, margin: float) -> list[SubmoduleView]:
    parent_map = {child: parent for parent in root.iter() for child in parent}
    seen_ids: set[str] = set()
    views: list[SubmoduleView] = []

    def unique_view_id(parts: list[str]) -> str:
        base = _sanitize_id(parts)
        view_id = base
        idx = 2
        while view_id in seen_ids:
            view_id = f"{base}_{idx}"
            idx += 1
        seen_ids.add(view_id)
        return view_id

    def walk(
        elem: ET.Element,
        abs_x: float,
        abs_y: float,
        path: list[str],
    ) -> None:
        tx, ty = _translate(elem)
        here_x = abs_x + tx
        here_y = abs_y + ty
        next_path = path

        if _is_submodule_group(elem):
            cell_id = elem.get("id", "cell")
            next_path = path + [cell_id]
            parent = parent_map[elem]
            link_parent = parent if _local_name(parent.tag) == "a" else None
            views.append(
                SubmoduleView(
                    elem=elem,
                    parent=parent,
                    link_parent=link_parent,
                    view_id=unique_view_id(next_path),
                    view_box=_submodule_view_box(elem, here_x, here_y, margin),
                )
            )

        for child in list(elem):
            walk(child, here_x, here_y, next_path)

    walk(root, 0.0, 0.0, [])
    return views


def _remove_generated_views(root: ET.Element) -> None:
    for child in list(root):
        if _local_name(child.tag) == "view" and child.get(VIEW_MARKER) == "true":
            root.remove(child)


def _insert_views(root: ET.Element, views: list[SubmoduleView]) -> None:
    root_width = _float_attr(root, "width", 1.0)
    root_height = _float_attr(root, "height", 1.0)
    generated = [
        ET.Element(
            _qname(root, "view"),
            {
                "id": "view_top",
                "viewBox": f"0 0 {_format_num(root_width)} {_format_num(root_height)}",
                VIEW_MARKER: "true",
            },
        )
    ]
    for view in views:
        x, y, width, height = view.view_box
        generated.append(
            ET.Element(
                _qname(root, "view"),
                {
                    "id": view.view_id,
                    "viewBox": " ".join(_format_num(v) for v in (x, y, width, height)),
                    VIEW_MARKER: "true",
                },
            )
        )

    insert_at = 0
    for idx, child in enumerate(list(root)):
        if _local_name(child.tag) == "style":
            insert_at = idx + 1
            break
    for offset, view in enumerate(generated):
        root.insert(insert_at + offset, view)


def _wrap_submodule(root: ET.Element, view: SubmoduleView) -> ET.Element:
    link = ET.Element(_qname(root, "a"))
    _set_link_href(link, f"#{view.view_id}")
    children = list(view.parent)
    index = children.index(view.elem)
    view.parent.remove(view.elem)
    link.append(view.elem)
    view.parent.insert(index, link)
    return link


def _rewrite_links(root: ET.Element, views: list[SubmoduleView]) -> int:
    changed = 0
    for view in views:
        href = f"#{view.view_id}"
        link = view.link_parent
        if link is None:
            _wrap_submodule(root, view)
            changed += 1
            continue
        old_href = _link_href(link)
        if _should_rewrite_link(old_href):
            _set_link_href(link, href)
            changed += 1
    return changed


def add_internal_views(path: Path, margin: float = DEFAULT_MARGIN) -> int:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    tree = ET.parse(path, parser=parser)
    root = tree.getroot()

    _remove_generated_views(root)
    views = _collect_submodules(root, margin)
    if not views:
        return 0

    _insert_views(root, views)
    changed = _rewrite_links(root, views)
    tree.write(path, encoding="unicode", xml_declaration=False)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("svg_path", nargs="+", type=Path)
    parser.add_argument("--margin", type=float, default=DEFAULT_MARGIN)
    args = parser.parse_args()

    ok = True
    for path in args.svg_path:
        try:
            changed = add_internal_views(path, args.margin)
        except (OSError, ET.ParseError) as exc:
            print(f"netlistsvg_internal_views: {path}: {exc}", file=sys.stderr)
            ok = False
            continue
        if changed:
            print(
                f"netlistsvg_internal_views: {path}: "
                f"rewrote {changed} submodule link(s) to internal SVG views"
            )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
