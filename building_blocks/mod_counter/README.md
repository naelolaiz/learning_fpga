# mod_counter

Up/down modulo-N counter with carry-out. 4-bit output makes it a
drop-in single BCD digit at `MAX_NUMBER = 9`; other moduli ≤ 15 use
the same width (e.g. `MAX_NUMBER = 11` for a 12-hour cascade,
`MAX_NUMBER = 5` for a tens-of-seconds digit).

Originally lived as the `Digit` entity in `7segmentsDigit.vhd`
inside the clock project. The logic was always pure mod-N counter
— only the file name suggested 7-segment specificity.

## Interface

| Port | Direction | Meaning |
|---|---|---|
| `clock` | in | Counted edge |
| `reset` | in | Synchronously clears `currentNumber` to 0 |
| `direction` | in | 1 = forward (count up to MAX_NUMBER, wrap), 0 = backward |
| `currentNumber` | out (4-bit) | Current state, 0 .. MAX_NUMBER |
| `carryBit` | out | High for one cycle whenever the counter wraps |

| Generic | Default | Meaning |
|---|---|---|
| `MAX_NUMBER` | `9` | Modulus minus 1 — state walks 0..MAX_NUMBER |

## Tested behaviour

[`test/tb_mod_counter.vhd`](test/tb_mod_counter.vhd) (and the
Verilog mirror) walk one forward cycle (asserting the value at each
step and that `carryBit` fires exactly on the MAX→0 wrap), then one
backward cycle.

## Used by

Twelve instances in [`display/7segments/clock/`](../../display/7segments/clock/)
form the BCD digit cascade for both the running clock and the alarm
clock (units of seconds at MAX=9, tens at MAX=5, hours-tens at
MAX=2, etc.).
