// tb_rom_lut_realmath.v - Verilog mirror of tb_rom_lut_realmath.vhd.
//
// Tutorial-grade equivalence proof between two ways of computing
// the sin-nibble table:
//
//   * THE TESTBENCH computes the gold reference inline using $sin /
//     real arithmetic - concise, mathematically transparent, but NOT
//     synthesisable (real-math is simulation-only).
//
//   * THE DUT (rom_lut_func) computes the same table at elaboration
//     using a precomputed 32-entry Q15 fixed-point sine table +
//     integer cross-product. Fully synthesisable; the production form.
//
// The testbench drives every (angle, nibble) and asserts the DUT
// output is bit-identical to the real-math reference. If the
// integer-math approximation ever drifts (e.g. the seed table is
// regenerated at a different precision), this testbench fires.
//
// The lesson: real-math is fine for *deriving* gold references in
// testbenches; production code stays integer.

`timescale 1ns/1ps

module tb_rom_lut_realmath;

    localparam time CLK_PERIOD = 4;
    // $acos(-1.0) is the portable IEEE-754 way to get pi in Verilog
    // simulators (no math.h, no $pi).
    localparam real MATH_PI         = 3.14159265358979323846;
    localparam real MATH_PI_OVER_2  = MATH_PI / 2.0;

    reg              sClock = 1'b0;
    reg  [6:0]       sAngleIdx  = 7'd0;
    reg  [3:0]       sNibbleIdx = 4'd0;
    wire [9:0]       sOutC;
    reg              sTestRunning = 1'b1;

    rom_lut_func dut (
        .clock              (sClock),
        .read_angle_idx     (sAngleIdx),
        .nibble_product_idx (sNibbleIdx),
        .data_out           (sOutC)
    );

    always #(CLK_PERIOD/2.0) if (sTestRunning) sClock = ~sClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_rom_lut_realmath);
        $dumpvars(1, dut);
    end

    // Real-math gold reference. The VHDL twin uses SIN from
    // IEEE.MATH_REAL the same way.
    //     ref(row, col) = round( sin(row * pi/64) * col * 31 )
    function automatic integer real_math_ref(input integer row,
                                             input integer col);
        real magnitude;
        real v;
    begin
        magnitude = 31.0;
        v = $sin(MATH_PI_OVER_2 * row / 32.0) * col * magnitude;
        // $rtoi truncates; add 0.5 / subtract 0.5 to match VHDL's
        // round-half-away-from-zero behaviour.
        real_math_ref = (v >= 0.0) ? $rtoi(v + 0.5) : -$rtoi(-v + 0.5);
    end
    endfunction

    // Init at declaration so the waveform doesn't render these red
    // before the initial block writes them.
    integer a          = 0;
    integer n          = 0;
    integer angle_mod  = 0;
    integer expected   = 0;
    integer mismatches = 0;

    initial begin : driver
        @(negedge sClock);

        // Sweep every (angle, nibble) pair across all four quadrants and
        // assert the DUT's output equals the testbench's real-math ref.
        // Quadrant unfolding mirrors the DUT's internal logic:
        //   quadrant 0 (angle 0..31)   :  ref = +sin
        //   quadrant 1 (angle 32..63)  :  ref = +sin(31 - (a mod 32))
        //   quadrant 2 (angle 64..95)  :  ref = -sin
        //   quadrant 3 (angle 96..127) :  ref = -sin(31 - (a mod 32))
        for (a = 0; a < 128; a = a + 1) begin
            for (n = 0; n < 16; n = n + 1) begin
                sAngleIdx  = a[6:0];
                sNibbleIdx = n[3:0];
                @(negedge sClock);

                angle_mod = a % 32;
                case (a / 32)
                    0: expected =  real_math_ref(angle_mod,      n);
                    1: expected =  real_math_ref(31 - angle_mod, n);
                    2: expected = -real_math_ref(angle_mod,      n);
                    3: expected = -real_math_ref(31 - angle_mod, n);
                    default: expected = 0;
                endcase

                if ($signed(sOutC) !== expected) begin
                    $display("real-math mismatch at (a=%0d, n=%0d): expected %0d, got %0d",
                             a, n, expected, $signed(sOutC));
                    mismatches = mismatches + 1;
                end
            end
        end

        if (mismatches != 0)
            $fatal(1, "tb_rom_lut_realmath: %0d mismatches", mismatches);

        $display("tb_rom_lut_realmath: rom_lut_func matches the real-math reference on every address");
        sTestRunning = 1'b0;
        $finish;
    end

endmodule
