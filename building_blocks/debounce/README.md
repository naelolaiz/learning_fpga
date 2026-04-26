Switch / button debouncer.

Holds the output stable until the input has been the new value for
`DEBOUNCE_LIMIT` consecutive clock cycles. Default 250 000 ticks
(10 ms at 25 MHz, 5 ms at 50 MHz). Source originally from
[nandland.com](https://nandland.com/project-4-debounce-a-switch/);
the `DEBOUNCE_LIMIT` parameter / generic was added so testbenches
can compress the wait window without changing the design.

Two testbenches:

- `tb_debounce_bounce` — input bounces 0/1/0/1, then settles high.
  The bounces are individually shorter than the limit (must not
  leak); the sustained-high stretch is longer (must propagate).
- `tb_debounce_glitch` — single short pulse below the limit; output
  must stay low.
