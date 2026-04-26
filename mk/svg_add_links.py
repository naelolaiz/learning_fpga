#!/usr/bin/env python3
"""
Decorate a netlistsvg-rendered SVG with hyperlinks and / or relabels
for individual cells.

Usage:
    svg_add_links.py <svg_path> \\
        [--link    cell_id=url ...] \\
        [--relabel cell_id=text ...]

For each --link: wraps the corresponding `<g ... id="cell_<cell_id>">`
group with `<a xlink:href="url">…</a>` so a viewer can click through
to that URL (typically the wrapped sub-module's own diagram).

For each --relabel: rewrites the visible text on the cell from
yosys's auto-generated name (e.g. `$paramod\\<sub>\\<param>=<val>`
on the Verilog side, or `<sub>_B<arch>_<width>` on the VHDL side
via ghdl-yosys-plugin) back to a clean human-readable name.
yosys's `rename` updates the module table but not cell-type
references, so post-processing the SVG is the practical fix.

The SVG is rewritten in place. Mappings whose cell_id doesn't appear
print a warning but don't fail the build.

Edits the SVG as text rather than going through a real XML parser
because netlistsvg's output uses an `s:` namespace and a few other
quirks that round-trip awkwardly through ElementTree, and a regex
match on the cell_<name> id is unambiguous: every cell yosys emits
gets a unique cell_<name> id.
"""

import argparse
import re
import sys


_G_OPEN  = re.compile(r"<g\b[^>]*?(/?)>", re.DOTALL)
_G_CLOSE = re.compile(r"</g\s*>")


def _find_cell_extent(svg: str, cell_id: str) -> tuple[int, int] | None:
    """Return the (start, end) byte range of the `<g ... id="cell_<id>"
    ...>...</g>` element in svg, or None if not present.

    Walks the string with a tag-depth counter rather than a non-greedy
    regex, so cells that contain nested `<g>` elements (e.g. one per
    port label) get their *matching* outer `</g>` rather than the
    first inner one.
    """
    open_anchor = re.compile(
        r'<g\b[^>]*\bid="cell_' + re.escape(cell_id) + r'"[^>]*?(/?)>',
        re.DOTALL,
    )
    m = open_anchor.search(svg)
    if not m:
        return None
    if m.group(1) == "/":
        return (m.start(), m.end())  # self-closing, no body

    depth = 1
    pos = m.end()
    while depth > 0:
        next_open = _G_OPEN.search(svg, pos)
        next_close = _G_CLOSE.search(svg, pos)
        if next_close is None:
            return None  # malformed — bail rather than guess
        if next_open is not None and next_open.start() < next_close.start():
            if next_open.group(1) != "/":
                depth += 1
            pos = next_open.end()
        else:
            depth -= 1
            pos = next_close.end()
    return (m.start(), pos)


def _make_cell_rect_clickable(svg: str, cell_id: str) -> str:
    """Add `pointer-events="all"` to the cell's body rect.

    netlistsvg's stylesheet sets `svg { fill: none }`, so the rect
    that draws the box has no fill and therefore captures pointer
    events only on its 1-pixel stroke — making the click target
    practically a hairline border. `pointer-events="all"` makes the
    rect capture clicks across its full bounding box regardless of
    fill, so the whole box is the clickable area for the wrapping
    `<a>`.
    """
    pattern = re.compile(
        r'(<rect\b[^>]*\bclass="cell_' + re.escape(cell_id) + r'")(\s*/?>)'
    )

    def add_pe(m: re.Match) -> str:
        if "pointer-events" in m.group(0):
            return m.group(0)
        return f'{m.group(1)} pointer-events="all"{m.group(2)}'

    svg, _ = pattern.subn(add_pe, svg)
    return svg


def _embed_preview_image(svg: str, cell_id: str, url: str) -> str:
    """Embed `url` as an `<image>` at the bottom of the cell's `<g>`
    z-stack, sized to the cell's body rect.

    Browsers render referenced SVGs inside `<image>` tags, so for a
    wrapper that links to a sibling project's SVG this yields an
    inline thumbnail of the wrapped module's own diagram — a
    "look inside" preview without enlarging the cell or disturbing
    netlistsvg's layout. preserveAspectRatio keeps the embedded SVG
    legible at the (small) cell size.

    Inserted as the first child of the cell's `<g>` so it sits at
    the back of the painter's-algorithm stack — the cell's own
    label, body stroke, and port markers stay drawn on top of it.
    `pointer-events="none"` keeps the click target the wrapping
    `<a>`, not the image itself.
    """
    rect_match = re.search(
        r'<rect\b([^/>]*)\bclass="cell_' + re.escape(cell_id) + r'"([^/>]*)/>',
        svg,
    )
    if rect_match is None:
        return svg
    width_m = re.search(r'\bwidth="([0-9.]+)"', rect_match.group(0))
    height_m = re.search(r'\bheight="([0-9.]+)"', rect_match.group(0))
    if not (width_m and height_m):
        return svg
    width = width_m.group(1)
    height = height_m.group(1)

    # Insert position: right after the cell's <g ...> opening tag, so
    # the image is the first painted element in the cell.
    open_match = re.search(
        r'<g\b[^>]*\bid="cell_' + re.escape(cell_id) + r'"[^>]*>',
        svg,
    )
    if open_match is None:
        return svg

    href = url.replace('"', "&quot;")
    image = (
        f'<image xlink:href="{href}" x="0" y="0" '
        f'width="{width}" height="{height}" '
        f'preserveAspectRatio="xMidYMid meet" '
        f'opacity="0.85" pointer-events="none"/>'
    )
    insert_at = open_match.end()
    return svg[:insert_at] + image + svg[insert_at:]


def wrap_link(svg: str, cell_id: str, url: str) -> tuple[str, int]:
    extent = _find_cell_extent(svg, cell_id)
    if extent is None:
        return svg, 0
    svg = _embed_preview_image(svg, cell_id, url)
    svg = _make_cell_rect_clickable(svg, cell_id)
    # Re-find the extent after the inserts: byte offsets have shifted.
    start, end = _find_cell_extent(svg, cell_id)
    href = url.replace('"', "&quot;")
    wrapped = f'<a xlink:href="{href}">{svg[start:end]}</a>'
    return svg[:start] + wrapped + svg[end:], 1


def relabel(svg: str, cell_id: str, text: str) -> tuple[str, int]:
    # netlistsvg emits the cell's display name as the contents of a
    # <text class="nodelabel cell_<id>">…</text>. Match that exactly
    # so we don't disturb port labels (`inputPortLabel cell_<id>` etc).
    pattern = re.compile(
        r'(<text[^>]*\bclass="nodelabel cell_' + re.escape(cell_id) + r'"[^>]*>)'
        r'[^<]*'
        r'(</text>)',
        re.DOTALL,
    )
    replacement = r'\1' + text + r'\2'
    return pattern.subn(replacement, svg)


def parse_mapping(arg: str) -> tuple[str, str]:
    if "=" not in arg:
        raise ValueError(f"bad mapping {arg!r}, expected cell_id=value")
    cell_id, value = arg.split("=", 1)
    return cell_id, value


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("svg_path")
    parser.add_argument("--link", action="append", default=[],
                        metavar="cell_id=url",
                        help="wrap cell_<cell_id> with <a xlink:href=...>")
    parser.add_argument("--relabel", action="append", default=[],
                        metavar="cell_id=text",
                        help="rewrite cell_<cell_id>'s visible label")
    args = parser.parse_args()

    with open(args.svg_path, encoding="utf-8") as f:
        svg = f.read()

    rc = 0
    # Relabel first — wrapping the cell with an <a> doesn't disturb
    # the inner <text>, but rewriting after wrap would still work
    # either way.
    for arg in args.relabel:
        try:
            cell_id, text = parse_mapping(arg)
        except ValueError as e:
            print(f"svg_add_links: {e}", file=sys.stderr)
            return 2
        svg, count = relabel(svg, cell_id, text)
        if count == 0:
            print(f"svg_add_links: warning: no nodelabel for cell_{cell_id} in {args.svg_path}",
                  file=sys.stderr)
        else:
            print(f"svg_add_links: {args.svg_path}: relabel cell_{cell_id} -> {text}")

    for arg in args.link:
        try:
            cell_id, url = parse_mapping(arg)
        except ValueError as e:
            print(f"svg_add_links: {e}", file=sys.stderr)
            return 2
        svg, count = wrap_link(svg, cell_id, url)
        if count == 0:
            print(f"svg_add_links: warning: no cell_{cell_id} in {args.svg_path}",
                  file=sys.stderr)
        else:
            print(f"svg_add_links: {args.svg_path}: link cell_{cell_id} -> {url}")

    with open(args.svg_path, "w", encoding="utf-8") as f:
        f.write(svg)
    return rc


if __name__ == "__main__":
    sys.exit(main())
