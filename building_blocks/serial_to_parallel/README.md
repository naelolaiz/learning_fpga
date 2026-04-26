Continuous serial-in / parallel-out shifter with a snapshot register.

Shifts `inData` into the LSB of an internal shift register on every
rising clock edge (MSB is discarded). When `inPrint` is held high
at a rising edge, the current parallel state is latched into
`outData`; between pulses `outData` stays at its last latched value.

Implemented as a thin wrapper around the
[`shift_register`](../shift_register/) entity plus one snapshot
register, rather than a bespoke shift loop. The shift_register
source is referenced via a relative path in the
[Makefile](Makefile)'s `SRC_FILES` (and `V_SRC_FILES`) — both GHDL
and iverilog accept that as a normal source-list entry, no
build-system import needed.

Two testbenches:

- `tb_serial_to_parallel_basic` — shift in 0xB4 MSB-first, pulse
  inPrint, verify outData latches the expected pattern.
- `tb_serial_to_parallel_print_gating` — verify the snapshot
  register actually gates: outData stays at its initial value while
  inPrint=0, latches on the first pulse, then stays at that
  snapshot through a second wave of shifting (with inPrint=0)
  before re-latching on the second pulse.
