// Verilog mirror of vga_driver/VgaController.vhd, ported one-for-one
// from the original "Basic VGA Controller for the RZ EasyFPGA A2.2"
// by Francisco Miamoto. 640x480 @ 60 Hz timing assumes a 25 MHz clock
// driven into `clk`.
//
// Same port shape as the VHDL entity (clk, rgb_in[2:0], rgb_out[2:0],
// hsync, vsync, hpos, vpos), with the timing constants pulled inline
// as localparams instead of imported from a VgaUtils package — keeps
// this file self-contained for the Verilog flow. Module name matches
// the VHDL entity (PascalCase) so the gallery's stem-based pairing
// logic puts the two netlist diagrams on the same row.

module VgaController(
    input              clk,
    input      [2:0]   rgb_in,
    output     [2:0]   rgb_out,
    output             hsync,
    output             vsync,
    output     [10:0]  hpos,
    output     [10:0]  vpos
);
    // 640x480 @ 60 Hz timings, mirroring VgaUtils.vhd.
    localparam HSYNC_END   = 95;
    localparam HDATA_BEGIN = 143;
    localparam HDATA_END   = 783;
    localparam HLINE_END   = 799;
    localparam VSYNC_END   = 1;
    localparam VDATA_BEGIN = 34;
    localparam VDATA_END   = 514;
    localparam VLINE_END   = 524;

    reg [10:0] hcount = 11'd0;
    reg [10:0] vcount = 11'd0;

    wire should_reset_hcount = (hcount == HLINE_END);
    wire should_reset_vcount = (vcount == VLINE_END);
    wire should_output_data  = (hcount >= HDATA_BEGIN) && (hcount < HDATA_END)
                            && (vcount >= VDATA_BEGIN) && (vcount < VDATA_END);

    // VHDL drives rgb_out concurrently from rgb_in / should_output_data;
    // mirror with a continuous `assign` (not a clocked register) so the
    // synthesised diagram matches.
    assign hsync   = (hcount > HSYNC_END);
    assign vsync   = (vcount > VSYNC_END);
    assign rgb_out = should_output_data ? rgb_in : 3'b000;
    assign hpos    = hcount;
    assign vpos    = vcount;

    // Two separate always blocks, one per counter, matching the VHDL's
    // two distinct processes. vcount only advances on the same clock
    // edge that resets hcount (end of a scanline).
    always @(posedge clk) begin
        if (should_reset_hcount)
            hcount <= 11'd0;
        else
            hcount <= hcount + 11'd1;
    end

    always @(posedge clk) begin
        if (should_reset_hcount) begin
            if (should_reset_vcount)
                vcount <= 11'd0;
            else
                vcount <= vcount + 11'd1;
        end
    end
endmodule // VgaController
