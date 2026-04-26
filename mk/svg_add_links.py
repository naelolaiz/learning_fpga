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


def _read_text(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def _strip_xml_decl(svg: str) -> str:
    return re.sub(r"^\s*<\?xml[^?]*\?>\s*", "", svg)


def embed_preview_inline(svg: str, cell_id: str, source_path: str) -> tuple[str, int]:
    """Inline the SVG at `source_path` as a nested `<svg>` inside the
    cell's `<g>`, sized to the cell's body rect.

    Used in preference to `<image href="…">` because GitHub's
    raw.githubusercontent.com sets a `Content-Security-Policy:
    default-src 'none'` on every served file, which blocks the
    sub-resource fetch that an `<image>` would have to make. Inlining
    sidesteps the policy entirely — the submodule's diagram is part of
    the parent SVG document, no extra network access required.

    The nested element is inserted as the first child of the cell's
    `<g>` so it paints behind the cell's own label, body stroke, and
    port markers. preserveAspectRatio keeps the inlined SVG legible
    at the (small) cell-rect size.

    Composes naturally: if `source_path`'s SVG was itself produced by
    a project that inlined its own previews, those nested previews
    ride along inside this preview.
    """
    sub = _read_text(source_path)
    if sub is None:
        print(f"svg_add_links: warning: preview source missing: {source_path}",
              file=sys.stderr)
        return svg, 0
    sub = _strip_xml_decl(sub)

    sub_open = re.search(r"<svg\b([^>]*)>", sub)
    if sub_open is None:
        return svg, 0
    sub_attrs = sub_open.group(1)
    sub_w = re.search(r'\bwidth="([0-9.]+)"', sub_attrs)
    sub_h = re.search(r'\bheight="([0-9.]+)"', sub_attrs)
    if not (sub_w and sub_h):
        return svg, 0
    orig_w, orig_h = sub_w.group(1), sub_h.group(1)

    sub_inner = sub[sub_open.end():]
    sub_inner = re.sub(r"</svg\s*>\s*$", "", sub_inner)

    rect_match = re.search(
        r'<rect\b([^/>]*)\bclass="cell_' + re.escape(cell_id) + r'"([^/>]*)/>',
        svg,
    )
    if rect_match is None:
        return svg, 0
    cell_w_m = re.search(r'\bwidth="([0-9.]+)"', rect_match.group(0))
    cell_h_m = re.search(r'\bheight="([0-9.]+)"', rect_match.group(0))
    if not (cell_w_m and cell_h_m):
        return svg, 0
    cell_w, cell_h = cell_w_m.group(1), cell_h_m.group(1)

    open_match = re.search(
        r'<g\b[^>]*\bid="cell_' + re.escape(cell_id) + r'"[^>]*>',
        svg,
    )
    if open_match is None:
        return svg, 0

    nested = (
        f'<svg x="0" y="0" width="{cell_w}" height="{cell_h}" '
        f'viewBox="0 0 {orig_w} {orig_h}" '
        f'preserveAspectRatio="xMidYMid meet">'
        + sub_inner
        + '</svg>'
    )
    insert_at = open_match.end()
    return svg[:insert_at] + nested + svg[insert_at:], 1


def wrap_link(svg: str, cell_id: str, url: str) -> tuple[str, int]:
    extent = _find_cell_extent(svg, cell_id)
    if extent is None:
        return svg, 0
    svg = _make_cell_rect_clickable(svg, cell_id)
    # Re-find the extent after the rect mutation: byte offsets shifted.
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
    parser.add_argument("--preview", action="append", default=[],
                        metavar="cell_id=local_path",
                        help="inline the SVG at local_path as a nested <svg> "
                             "inside cell_<cell_id> (read at build time, no "
                             "live cross-document reference)")
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

    # Previews must run *before* link-wrapping: the wrap inserts an
    # `<a>` between the cell's `<g>` and its parent, but the inline
    # preview wants to be a child of that same `<g>`. Doing previews
    # first keeps the regex-based child insertion unaffected by the
    # later <a> wrapping.
    for arg in args.preview:
        try:
            cell_id, source = parse_mapping(arg)
        except ValueError as e:
            print(f"svg_add_links: {e}", file=sys.stderr)
            return 2
        svg, count = embed_preview_inline(svg, cell_id, source)
        if count > 0:
            print(f"svg_add_links: {args.svg_path}: preview cell_{cell_id} <- {source}")

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
