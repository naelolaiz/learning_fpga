// Verilog mirror of top_logic_styles_board.vhd. See that file for the
// LED mapping and "what to do on the board to see each lesson".

`default_nettype none

module top_logic_styles_board (
    input  wire       clk,
    input  wire       button1,   // PIN_88, KEY1: data `a`
    input  wire       button2,   // PIN_89, KEY2: data `b` AND latch enable
    input  wire       button3,   // PIN_90, KEY3: synchronous reset for the registered LED
    output wire [3:0] leds
);

    wire a   = ~button1;
    wire b   = ~button2;
    wire rst = ~button3;

    // 50 MHz / 2^25 ≈ 1.49 Hz slow clock for the registered output.
    reg [24:0] slow_count = 25'd0;
    wire       slow_clk   = slow_count[24];

    always @(posedge clk) begin
        slow_count <= slow_count + 25'd1;
    end

    wire w_comb_op, w_comb_proc_good, w_comb_proc_latch;
    wire w_seq_no_init, w_seq_decl_init, w_seq_sync_reset;
    wire w_latch_intentional;

    logic_styles logic_styles_inst (
        .a                   (a),
        .b                   (b),
        .clk                 (slow_clk),
        .rst                 (rst),
        .en                  (b),
        .comb_op_and         (w_comb_op),
        .comb_proc_good_and  (w_comb_proc_good),
        .comb_proc_latch_and (w_comb_proc_latch),
        .seq_no_init_a       (w_seq_no_init),
        .seq_decl_init_a     (w_seq_decl_init),
        .seq_sync_reset_a    (w_seq_sync_reset),
        .latch_intentional_a (w_latch_intentional)
    );

    assign leds[0] = w_comb_op;
    assign leds[1] = w_comb_proc_latch;
    assign leds[2] = w_seq_sync_reset;
    assign leds[3] = w_latch_intentional;

endmodule

`default_nettype wire
