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
from xml.sax.saxutils import escape as _xml_escape


_G_OPEN  = re.compile(r"<g\b[^>]*?(/?)>", re.DOTALL)
_G_CLOSE = re.compile(r"</g\s*>")


# Yosys primitive cell types that netlistsvg's default skin has no
# specialised symbol for, so they fall through to a literal `<text>`
# of the type name. Map each to a short human-readable label so the
# rendered diagram doesn't carry yosys's `$type` jargon to the
# reader. This list is conservative — only types we've actually
# observed leaking through to the rendered SVG. Add to it as new
# leaks appear.
PRIMITIVE_LABELS = {
    # Memory
    "$mem_v2":     "RAM",
    # Arithmetic
    "$mul":        "*",
    "$div":        "/",
    "$mod":        "%",
    "$divfloor":   "/⌊",      # floor div (signed semantics)
    "$modfloor":   "%⌊",      # floor mod (signed semantics)
    "$pos":        "+",
    "$neg":        "−",       # − (minus)
    # Reductions
    "$reduce_or":  "≥1",      # true if any input bit is 1
    "$reduce_and": "all",
    "$reduce_bool":"≠0",      # true if input is non-zero
    "$reduce_xor": "XOR-r",
    "$reduce_xnor":"XNOR-r",
    # Shifts
    "$shl":        "<<",
    "$shr":        ">>",
    "$sshr":       ">>>",     # arithmetic right shift
    "$shift":      "shift",
    "$shiftx":     "shift",
    "$shrx":       "shift",
    # Comparisons that fall through (most have netlistsvg symbols, $ne does not)
    "$ne":         "≠",
    "$eqx":        "===",     # X-aware ==
    "$nex":        "!==",     # X-aware !=
    # Logic
    "$logic_not":  "!",
    "$logic_and":  "&&",
    "$logic_or":   "||",
    # Misc
    "$ternary":    "?:",
    "$pmux":       "pmux",
    "$bmux":       "bmux",
    "$demux":      "demux",
    "$tribuf":     "tri",
    # Latches (shape provided by glossary's local skin; falls through
    # to text in projects using the default skin)
    "$dlatch":     "latch",
    "$adlatch":    "latch",
    "$dlatchsr":   "latch/SR",
    "$sr":         "SR",
    # Flip-flop variants. yosys's default-skin alias only covers
    # `$dff`; everything below falls through to `<text>` and needs a
    # friendly label. The label format is "DFF/<modifiers>" so the
    # qualifier reads off the cell at a glance:
    #   AR  = async reset    SR = sync reset    E = clock enable
    "$adff":       "DFF/AR",
    "$sdff":       "DFF/SR",
    "$dffe":       "DFF/E",
    "$adffe":      "DFF/AR+E",
    "$sdffe":      "DFF/SR+E",
    "$dffsr":      "DFF/SR2",     # set + reset
    "$dffsre":     "DFF/SR2+E",
}


def beautify_primitives(svg: str) -> str:
    """Rewrite `<text class="nodelabel ...">$type</text>` for any
    yosys primitive cell type in PRIMITIVE_LABELS to a friendly
    label. Only replaces complete-string nodelabels, so nested or
    composite text isn't affected. Idempotent — running twice does
    nothing the second time.

    Labels are XML-escaped before substitution: `<<` / `>>` / `&&`
    are tempting friendly forms, but emitted raw they break the
    SVG's XML parser (`<text>...<<</text>` looks like a malformed
    tag). `_xml_escape` converts to `&lt;&lt;` / `&gt;&gt;` /
    `&amp;&amp;`, which the rendered text node displays exactly as
    written.
    """
    nodelabel = re.compile(
        r'(<text[^>]*\bclass="nodelabel[^"]*"[^>]*>)'
        r'(\$[A-Za-z_0-9]+)'
        r'(</text>)'
    )

    def repl(m: re.Match) -> str:
        type_name = m.group(2)
        pretty = PRIMITIVE_LABELS.get(type_name)
        if pretty is None:
            return m.group(0)
        return m.group(1) + _xml_escape(pretty) + m.group(3)

    return nodelabel.sub(repl, svg)


def assert_no_dollar_nodelabels(svg: str, path: str) -> None:
    """Fail the build if any visible nodelabel still starts with `$`.

    A leftover `<text class="nodelabel ...">$xxx</text>` means the
    yosys cell type didn't get a friendly label from
    PRIMITIVE_LABELS. Add the missing entry to the table rather than
    shipping the raw `$type` to the gallery.

    Catching this at post-render means the next time a yosys version
    bump introduces a new primitive cell type, the build fails on
    the first SVG that surfaces it instead of silently degrading the
    rendered diagrams.
    """
    leaks = re.findall(
        r'<text[^>]*\bclass="nodelabel[^"]*"[^>]*>(\$[A-Za-z_0-9]+)</text>',
        svg,
    )
    if not leaks:
        return
    from collections import Counter
    summary = Counter(leaks).most_common()
    msg = (
        f"svg_add_links: {path}: {len(leaks)} nodelabel(s) still carry a "
        f"raw $-prefixed cell type:"
    )
    for t, n in summary:
        msg += f"\n    {n:4d}  {t!r}"
    msg += (
        "\n  Add an entry for each to PRIMITIVE_LABELS in "
        "mk/svg_add_links.py."
    )
    print(msg, file=sys.stderr)
    sys.exit(1)


def assert_well_formed_xml(svg: str, path: str) -> None:
    """Parse the (possibly post-processed) SVG with the stdlib XML
    parser and raise SystemExit on the first malformed-tag error.

    Catching it at the python layer beats discovering it later when
    the file is served from the gallery and a browser refuses to
    render it. The cost is negligible — the parser handles even the
    largest project diagrams in a few milliseconds.
    """
    from xml.etree import ElementTree as ET
    try:
        ET.fromstring(svg)
    except ET.ParseError as e:
        # Show the offending region so the cause is obvious — most
        # XML errors are a few characters' worth of context.
        line, col = e.position
        lines = svg.splitlines()
        bad = lines[line - 1] if 1 <= line <= len(lines) else ""
        marker = " " * max(col - 1, 0) + "^"
        msg = (
            f"svg_add_links: {path}: produced invalid XML at "
            f"line {line}, col {col}: {e}\n"
            f"    {bad}\n"
            f"    {marker}"
        )
        print(msg, file=sys.stderr)
        sys.exit(1)


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
    parser.add_argument("--beautify-primitives", action="store_true",
                        help="rewrite yosys primitive cell-type labels "
                             "($mem_v2, $reduce_or, $shl, ...) in nodelabel "
                             "<text> elements to short human-readable forms")
    args = parser.parse_args()

    with open(args.svg_path, encoding="utf-8") as f:
        svg = f.read()

    rc = 0

    # Beautify yosys primitive labels first — it's a global, idempotent
    # text substitution that doesn't depend on cell IDs, so no risk of
    # interfering with the per-cell relabel/link/preview steps that
    # follow.
    if args.beautify_primitives:
        before = svg
        svg = beautify_primitives(svg)
        if svg != before:
            print(f"svg_add_links: {args.svg_path}: beautified yosys primitives")

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

    # Always validate the post-processed result. Catches mistakes in
    # the beautifier table (unescaped < / > / &), in --relabel
    # arguments, and in the netlistsvg upstream that we'd otherwise
    # discover only when a browser refuses to render the file.
    assert_well_formed_xml(svg, args.svg_path)

    # Also fail the build if any visible nodelabel still starts with
    # `$` — that means PRIMITIVE_LABELS is missing an entry.
    assert_no_dollar_nodelabels(svg, args.svg_path)

    return rc


if __name__ == "__main__":
    sys.exit(main())
