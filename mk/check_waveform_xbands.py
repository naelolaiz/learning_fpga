#!/usr/bin/env python3
"""Scan a waveform SVG produced by waveview for X-band (uninitialised)
fills.

waveview paints stretches where a signal is `x` (uninitialised) in
red — `fill:rgb(85%,15%,15%)`. Counting those fills is a coarse-but-
robust proxy for "this signal had uninitialised bits at some point
during the sim".

Exits with code 0 unconditionally. The caller decides whether to
escalate; the script's job is just to emit a noticeable warning
line. CI runners that recognise GitHub's workflow commands will
surface lines starting with `::warning::` as annotations (yellow,
not red — the run still passes). When stdout is a TTY (local dev),
the warning is printed plain.

Usage:
    check_waveform_xbands.py <waveform.svg>
        [--allow signal_name ...]    # not yet enforced — placeholder
                                       so per-project allowlists are
                                       easy to slot in later

This script does not parse the underlying FST. A future iteration
could read the FST directly with pywellen (already in the container)
to attribute X-bands to specific signals; for now it gives a single
count so a CI summary can pick it up.
"""
import argparse
import os
import sys


RED_FILL = 'fill:rgb(85%,15%,15%)'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('svg_path')
    parser.add_argument('--allow', action='append', default=[],
                        metavar='SIGNAL',
                        help='signal name expected to carry X bands '
                             '(placeholder for future per-signal '
                             'attribution; currently unused)')
    args = parser.parse_args()

    try:
        with open(args.svg_path, encoding='utf-8') as f:
            svg = f.read()
    except OSError as e:
        # No waveform to scan — don't fail the build, just bail quietly.
        print(f'check_waveform_xbands: {args.svg_path}: {e}', file=sys.stderr)
        return 0

    count = svg.count(RED_FILL)
    if count == 0:
        return 0

    # GitHub Actions annotation format. Recognised lines are surfaced
    # as warning annotations on the run (yellow); ignored everywhere
    # else, where the line still reads clearly.
    in_ci = os.environ.get('GITHUB_ACTIONS') == 'true'
    prefix = '::warning::' if in_ci else 'WARNING: '
    print(f'{prefix}{args.svg_path}: {count} X-band(s) (uninitialised '
          f'signal bits) in waveform — paint a real value at t=0 '
          f'or document the expectation.',
          file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
