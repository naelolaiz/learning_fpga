# Synchronous FIFO

Learn how read/write pointers preserve order while a producer and consumer
run at different rates. Prerequisites: [shift register](../shift_register/)
and [synchronous logic](../../basics/logic_styles/).

## Interface and timing

| Name | Meaning |
| --- | --- |
| `DATA_WIDTH`, `DEPTH` | Word width (default 8) and capacity (default 16); depth must be a power of two, at least 2 |
| `clk`, `rst` | One rising-edge clock; synchronous active-high reset |
| `wr_en`, `wr_data` | Request to append one word |
| `rd_en`, `rd_data` | Request to remove one word; registered read output |
| `empty`, `full` | Current pointer-based status |

An accepted read updates `rd_data` just after its rising edge. The output
holds its previous value when no read is accepted; it does not expose
the first word automatically. Reset clears the pointers, making the
queue empty; it does not clear `rd_data` or erase storage.

Both requests are checked against flags **before** the edge:

| State before edge | Both enables high |
| --- | --- |
| Neither empty nor full | Read and write accepted; occupancy unchanged |
| Empty | Write accepted, read ignored; occupancy becomes 1 |
| Full | Read accepted, write ignored; occupancy becomes `DEPTH-1` |

A write to a full FIFO or read from an empty FIFO is ignored. This is a
single-clock FIFO; it is not a bridge between unrelated clock domains.

## Run and read the waveforms

From the repo root, using the [installed tools or container](../../README.md#start-here):

```bash
make -C building_blocks/fifo_sync all
```

`build/tb_fifo_sync.png` shows reset, eight writes (0–7), `full`, then
ordered reads and `empty`. `build/tb_fifo_sync_overlapping.png` starts
half full and exercises 20 cycles with both enables high. Its assertions
check that neither status flag rises and that the reads preserve order,
then verify the FIFO drains. Verilog artifacts have `_v` suffixes.
The overlap test covers an intermediate occupancy; it does not exercise
the full/empty simultaneous-request cases in the table above.

## Try it

**Guided change:** change `DEPTH` to 16 in both basic testbenches. Predict
that `full` rises after 16 accepted writes and verify the drained sequence
is 0–15. Run `make -C building_blocks/fifo_sync test`.

**Challenge:** add directed tests for both enables high while empty and
while full. Assert the resulting flags and drain all accepted words
against a software queue. In the full case, prove that the new word
was rejected rather than silently replacing an existing entry.
