#!/usr/bin/env python3
"""Scan a waveform SVG produced by waveview for X-band (uninitialised)
fills wide enough to actually see.

waveview paints stretches where a signal is `x` (uninitialised) in
red — `fill:rgb(85%,15%,15%)`. Every delta-cycle X transition produces
one such rectangle, including ones only a couple of pixels wide that
are invisible at the default zoom level. We filter to bands wider
than --min-width pixels (default 5) so the warning fires for X-bands
the reader can actually see in the gallery, not for one-clock
settling transients.

Exits with code 0 unconditionally. The caller decides whether to
escalate. CI runners that recognise GitHub's workflow commands will
surface lines starting with `::warning::` as annotations (yellow);
locally the line reads as plain WARNING. When at least one wide band
is found the script also drops a `<svg>.warnings` sibling file so a
later CI step can flip the job badge yellow without having to scrape
the live workflow log.

Usage:
    check_waveform_xbands.py <waveform.svg>
        [--min-width N]              # ignore X-bands narrower than
                                       N SVG units (default 5)
        [--expected]                 # mark the warning as intentional
                                      # but still surface it in CI
        [--allow signal_name ...]    # not yet enforced — placeholder
                                       so per-project allowlists are
                                       easy to slot in later

This script does not parse the underlying FST. A future iteration
could read it directly with pywellen (already in the container) to
attribute X-bands to specific signals; for now it gives a per-SVG
count so a CI summary can pick it up.
"""
import argparse
import os
import re
import sys


RED_FILL_RE = re.compile(
    r'fill:rgb\(85%,15%,15%\)[^"]*"[^"]*?d="M\s+(?P<x1>[\d.]+)\s+'
    r'[\d.]+\s+L\s+(?P<x2>[\d.]+)\s+',
    re.DOTALL,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('svg_path')
    parser.add_argument('--min-width', type=float, default=5.0,
                        metavar='N',
                        help='ignore X-bands narrower than N SVG '
                             'units. Default 5 — wide enough to see '
                             'at the gallery default zoom, narrow '
                             'enough to still flag bands a viewer '
                             'would call out.')
    parser.add_argument('--allow', action='append', default=[],
                        metavar='SIGNAL',
                        help='signal name expected to carry X bands '
                             '(placeholder for future per-signal '
                             'attribution; currently unused)')
    parser.add_argument('--expected', action='store_true',
                        help='X bands are intentional for this '
                             'testbench; still emit the warning marker '
                             'so CI shows the yellow signal.')
    args = parser.parse_args()

    try:
        with open(args.svg_path, encoding='utf-8') as f:
            svg = f.read()
    except OSError as e:
        # No waveform to scan — don't fail the build, just bail quietly.
        print(f'check_waveform_xbands: {args.svg_path}: {e}', file=sys.stderr)
        return 0

    count = 0
    for m in RED_FILL_RE.finditer(svg):
        width = float(m.group('x2')) - float(m.group('x1'))
        if width >= args.min_width:
            count += 1
    if count == 0:
        return 0

    # GitHub Actions annotation format. Recognised lines are surfaced
    # as warning annotations on the run (yellow); ignored everywhere
    # else, where the line still reads clearly.
    in_ci = os.environ.get('GITHUB_ACTIONS') == 'true'
    prefix = '::warning::' if in_ci else 'WARNING: '
    expectation = ' expected' if args.expected else ''
    suffix = (' Documented by EXPECTED_X_TBS.'
              if args.expected
              else ' Paint a real value at t=0 or document the expectation.')
    msg = (f'{args.svg_path}: {count}{expectation} X-band(s) '
           f'(uninitialised signal bits) in waveform.{suffix}')
    print(f'{prefix}{msg}', file=sys.stderr)

    # Drop a sibling marker file so a later CI step can decide whether
    # to flip the job icon to yellow (via a `continue-on-error: true`
    # step that fails when any marker exists). The annotation alone
    # only paints the side panel; it doesn't change the job badge.
    try:
        with open(args.svg_path + '.warnings', 'w', encoding='utf-8') as f:
            f.write(msg + '\n')
    except OSError as e:
        print(f'check_waveform_xbands: marker write failed: {e}',
              file=sys.stderr)

    return 0


if __name__ == '__main__':
    sys.exit(main())
