#!/usr/bin/env python3
"""Render a waveform PNG from a VCD by driving GTKWave headlessly.

Replaces the opaque `/tools/vcd2png.py` that shipped inside the hdltools
Docker image: same behaviour, but now lives in the repo, has a proper
CLI, pathlib-based I/O, logging and error handling — so it runs equally
well inside the container, on a bare runner, or on your laptop.

Originally adapted from sphinxcontrib-gtkwave
(https://github.com/ponty/sphinxcontrib-gtkwave).
"""

from __future__ import annotations

import argparse
import logging
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

from easyprocess import EasyProcess
from PIL import Image, ImageFilter
from pyvirtualdisplay.smartdisplay import DisplayTimeoutError, SmartDisplay

# ---- Constants -----------------------------------------------------------

#: Tcl injected into GTKWave. Adds every signal found in the dump,
#: then applies a zoom policy (see `--zoom` / `--zoom-range` on the
#: CLI). The `{zoom}` placeholder is substituted before the Tcl is
#: written to disk; all other braces are Tcl and must be doubled for
#: `str.format`. Raw-string so the backslash inside Tcl's `split`
#: survives untouched.
_GTKWAVE_TCL_TEMPLATE = r"""
set all_signals [list]
set nfacs [ gtkwave::getNumFacs ]
for {{set i 0}} {{$i < $nfacs}} {{incr i}} {{
    set facname [ gtkwave::getFacName $i ]
    lappend all_signals $facname
}}
gtkwave::addSignalsFromList $all_signals
{zoom}
"""

# Per-`--zoom` mode Tcl fragments.
#
# `full` — GTKWave's "Zoom Full" menu action, equivalent to pressing
# the zoom-fit button. Reliable for VCD dumps; works for most FST
# dumps too but see the note on `range:` below.
#
# `off` — leave whatever zoom GTKWave defaults to (useful for
# screenshots where the caller wants the default view).
#
# `range:FROM,TO` — call `setZoomRangeTimes` with explicit integer
# times in the dump's native time units (fs for GHDL, ps for
# iverilog, usually). Use this when `full` produces a degenerate
# zoom, e.g. on some GTKWave builds reading an FST file where
# `getMaxTime` returns a stale value and Zoom_Full lands on 0..3 fs.
_ZOOM_FRAGMENTS = {
    "full": "gtkwave::/Time/Zoom/Zoom_Full",
    "off": "# zoom disabled by --zoom off",
}

#: GTKWave runtime config: hide the SST pane, skip the splash, disable
#: the vertical grid — makes the resulting PNG cleaner to paste into docs.
_GTKWAVE_RC = """
hide_sst 1
splash_disable 1
enable_vert_grid 0
"""

#: Screenshots shorter than this (pixels of non-empty content height) are
#: rejected so we don't save a half-rendered GTKWave frame.
_MIN_WAVEFORM_HEIGHT_PX = 30

#: Default virtual display size.
_DEFAULT_SCREEN_SIZE: Tuple[int, int] = (1024, 768)

logger = logging.getLogger("vcd2png")


# ---- Configuration -------------------------------------------------------


@dataclass(frozen=True)
class ScreenshotConfig:
    """Static inputs for a single render."""

    input_vcd: Path
    output_png: Path
    screen_size: Tuple[int, int] = _DEFAULT_SCREEN_SIZE
    timeout_seconds: int = 12
    settle_seconds: int = 0
    background: str = "white"
    # Zoom policy: "full" runs Zoom_Full; "off" leaves GTKWave's
    # default view; a 2-tuple (from, to) calls setZoomRangeTimes with
    # those integer time values (in the dump's native time units).
    zoom: "str | Tuple[int, int]" = "full"


# ---- Image helpers -------------------------------------------------------


def _compute_content_bbox(image: Image.Image) -> Optional[Tuple[int, int, int, int]]:
    """Return the bounding box of visible content, or None if empty."""
    binary = image.point(lambda x: 255 * bool(x))
    dilated = binary.filter(ImageFilter.MaxFilter(3))
    inverted = dilated.point(lambda x: 255 * (not x))

    outer = inverted.getbbox()
    if outer is None:
        return None

    cropped = image.crop(outer)
    inner = cropped.getbbox()
    if inner is None:
        return None

    return (
        outer[0] + inner[0],
        outer[1] + inner[1],
        outer[0] + inner[2],
        outer[1] + inner[3],
    )


def _looks_rendered(image: Image.Image) -> bool:
    """True once the captured frame contains enough waveform to be useful."""
    bbox = _compute_content_bbox(image)
    if bbox is None:
        return False
    _, top, _, bottom = bbox
    rendered = (bottom - top) > _MIN_WAVEFORM_HEIGHT_PX
    logger.debug("bbox=%s rendered=%s", bbox, rendered)
    return rendered


# ---- GTKWave driver ------------------------------------------------------


def _resolve_zoom_tcl(zoom: "str | Tuple[int, int]") -> str:
    """Return the Tcl fragment implementing the requested zoom policy."""
    if isinstance(zoom, tuple):
        lo, hi = zoom
        return f"gtkwave::setZoomRangeTimes {int(lo)} {int(hi)}"
    try:
        return _ZOOM_FRAGMENTS[zoom]
    except KeyError as exc:
        raise ValueError(
            f"unknown zoom mode {zoom!r}; expected 'full', 'off', or a (from, to) tuple"
        ) from exc


def _write_gtkwave_control_files(work_dir: Path, cfg: ScreenshotConfig) -> Tuple[Path, Path]:
    """Drop the Tcl + rc files GTKWave needs into a work dir."""
    tcl_path = work_dir / "gtkwave.tcl"
    rc_path = work_dir / "gtkwave.rc"
    tcl = _GTKWAVE_TCL_TEMPLATE.format(zoom=_resolve_zoom_tcl(cfg.zoom))
    tcl_path.write_text(tcl)
    rc_path.write_text(_GTKWAVE_RC)
    return tcl_path, rc_path


def _capture_screenshot(cfg: ScreenshotConfig, tcl_path: Path, rc_path: Path) -> None:
    """Run GTKWave headlessly; save a trimmed PNG to cfg.output_png."""
    command = [
        "gtkwave",
        "--nomenu",
        "--script", str(tcl_path),
        str(cfg.input_vcd),
        str(rc_path),
    ]
    logger.debug("gtkwave command: %s", " ".join(command))

    with SmartDisplay(
        visible=False,
        size=cfg.screen_size,
        bgcolor=cfg.background,
        backend="xvfb",
    ) as display:
        with EasyProcess(command) as proc:
            if cfg.settle_seconds:
                proc.sleep(cfg.settle_seconds)
            try:
                frame = display.waitgrab(
                    timeout=cfg.timeout_seconds,
                    cb_imgcheck=_looks_rendered,
                )
            except DisplayTimeoutError as exc:
                raise DisplayTimeoutError(
                    f"{exc} (gtkwave stderr: {proc.stderr})"
                ) from exc

    bbox = _compute_content_bbox(frame)
    if bbox is None:
        raise RuntimeError(
            f"GTKWave rendered an empty frame for {cfg.input_vcd}; "
            "the VCD may be empty or the signals list mismatched."
        )

    # Widen to the left edge so signal names are always visible.
    _, top, right, bottom = bbox
    trimmed = frame.crop((0, top, right, bottom))

    cfg.output_png.parent.mkdir(parents=True, exist_ok=True)
    trimmed.save(cfg.output_png)
    logger.info("Saved %s (%dx%d)", cfg.output_png, trimmed.width, trimmed.height)


def render(cfg: ScreenshotConfig) -> None:
    """Validate inputs and drive GTKWave once."""
    if not cfg.input_vcd.is_file():
        raise FileNotFoundError(f"VCD not found: {cfg.input_vcd}")

    with tempfile.TemporaryDirectory(prefix="gtkwave_") as tmp:
        tcl_path, rc_path = _write_gtkwave_control_files(Path(tmp), cfg)
        _capture_screenshot(cfg, tcl_path, rc_path)


# ---- CLI -----------------------------------------------------------------


def _parse_args(argv: Optional[list[str]] = None) -> ScreenshotConfig:
    parser = argparse.ArgumentParser(
        description=(
            "Render a waveform PNG from a VCD file by driving GTKWave "
            "inside a virtual X server."
        ),
    )
    # Positional is accepted for backward compatibility with the old
    # /tools/vcd2png.py CLI (`vcd2png.py foo.vcd`). The long options
    # are the supported interface going forward.
    parser.add_argument(
        "vcd_positional", nargs="?", type=Path, default=None,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--input", "-i", type=Path,
        help="Input .vcd file.",
    )
    parser.add_argument(
        "--output", "-o", type=Path,
        help="Output .png file. Defaults to gtkwave_<basename>.png next to the VCD.",
    )
    parser.add_argument(
        "--timeout", type=int, default=12,
        help="Seconds to wait for GTKWave to render (default: 12).",
    )
    parser.add_argument(
        "--settle", type=int, default=0,
        help="Extra seconds to sleep after launch (default: 0).",
    )
    parser.add_argument(
        "--screen-size", type=str, default="1024x768",
        help="Virtual display size, WIDTHxHEIGHT (default: 1024x768).",
    )
    parser.add_argument(
        "--background", type=str, default="white",
        help="Virtual display background colour (default: white).",
    )
    parser.add_argument(
        "--zoom", choices=("full", "off"), default="full",
        help=(
            "Zoom policy after adding signals. 'full' (default) clicks "
            "GTKWave's Zoom Full; 'off' leaves the default view. "
            "Superseded by --zoom-range if both are given."
        ),
    )
    parser.add_argument(
        "--zoom-range", type=int, nargs=2, metavar=("FROM", "TO"), default=None,
        help=(
            "Explicit zoom range in the dump's native time units "
            "(fs for GHDL, ps for iverilog). Calls "
            "gtkwave::setZoomRangeTimes directly; use this when --zoom "
            "full produces a degenerate view, e.g. some GTKWave builds "
            "reading FST where getMaxTime returns a stale value."
        ),
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="Enable debug logging.",
    )

    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(name)s %(levelname)s %(message)s",
    )

    # Resolve input: --input wins over positional.
    input_vcd: Optional[Path] = args.input or args.vcd_positional
    if input_vcd is None:
        parser.error("missing VCD input (use --input or pass it positionally)")

    # Resolve output: default mimics the legacy tool's naming so that
    # existing CI snippets keep working.
    if args.output is not None:
        output_png = args.output
    else:
        output_png = input_vcd.with_name(f"gtkwave_{input_vcd.stem}.png")

    try:
        width, height = (int(dim) for dim in args.screen_size.lower().split("x"))
    except ValueError:
        parser.error(
            f"--screen-size must be WIDTHxHEIGHT, got {args.screen_size!r}"
        )

    zoom: "str | Tuple[int, int]"
    if args.zoom_range is not None:
        lo, hi = args.zoom_range
        if hi <= lo:
            parser.error("--zoom-range TO must be greater than FROM")
        zoom = (lo, hi)
    else:
        zoom = args.zoom

    return ScreenshotConfig(
        input_vcd=input_vcd,
        output_png=output_png,
        screen_size=(width, height),
        timeout_seconds=args.timeout,
        settle_seconds=args.settle,
        background=args.background,
        zoom=zoom,
    )


def main(argv: Optional[list[str]] = None) -> int:
    cfg = _parse_args(argv)
    try:
        render(cfg)
    except (FileNotFoundError, DisplayTimeoutError, RuntimeError) as exc:
        logger.error("%s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
