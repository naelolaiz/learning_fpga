// i2c_slave_model.v - Verilog mirror of i2c_slave_model.vhd.
//
// Behavioural I2C slave for testbenches (not synthesisable). It has no
// clock of its own: like a real slave it reacts to the bus wires.
//
//   SDA edge while SCL is high   START (falling) or STOP (rising)
//   SCL rising edge              sample SDA
//   SCL falling edge             change what it drives on SDA
//
// Modelled on a small serial memory: it answers only to ADDR; on a
// write the first data byte sets a pointer and each further byte is
// stored there; on a read it returns the byte at the pointer for as
// long as the master acknowledges. With `stretch` high it holds SCL
// low for STRETCH_TIME (ns) before every acknowledge bit.
//
// `starts`, `stops`, `rx_count` and `rx_data` are taps for the
// testbench.

`timescale 1ns/1ps

module i2c_slave_model #(
    parameter [6:0]   ADDR         = 7'b1010000,
    parameter integer STRETCH_TIME = 0
) (
    input  wire       scl,              // bus level, after the wired-AND
    input  wire       sda,
    input  wire       stretch,
    output reg        scl_oe   = 1'b0,  // 1 pulls SCL low
    output reg        sda_oe   = 1'b0,  // 1 pulls SDA low
    output integer    starts   = 0,     // START conditions, repeated ones included
    output integer    stops    = 0,     // STOP conditions that ended a transfer
    output integer    rx_count = 0,     // data bytes received
    output reg  [7:0] rx_data  = 8'h00
);

    reg [7:0] mem [0:255];
    integer   i = 0;
    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
    end

    reg [7:0] ptr        = 8'd0;
    reg       active     = 1'b0;    // between START and STOP
    reg       got_addr   = 1'b0;    // address byte already seen
    reg       addressed  = 1'b0;    // ...and it was ours
    reg       reading    = 1'b0;    // master reads, we transmit
    reg       first_data = 1'b0;    // next written byte is the pointer
    reg       send_next  = 1'b0;    // master acknowledged: send another byte
    integer   bitn       = 0;       // SCL rising edges in this byte
    reg [7:0] sh         = 8'h00;
    reg [7:0] txb        = 8'h00;

    reg       scl_prev   = 1'b1;
    reg       sda_prev   = 1'b1;

    always @(scl or sda) begin
        if (sda !== sda_prev && scl === 1'b1 && scl_prev === 1'b1) begin
            // SDA moved while SCL stayed high: a START or a STOP.
            if (sda === 1'b0) begin
                starts    = starts + 1;
                active    = 1'b1;
                got_addr  = 1'b0;
                addressed = 1'b0;
                reading   = 1'b0;
                bitn      = 0;
                sda_oe   <= 1'b0;
            end else if (sda === 1'b1 && active) begin
                stops     = stops + 1;
                active    = 1'b0;
                addressed = 1'b0;
                reading   = 1'b0;
                sda_oe   <= 1'b0;
            end

        end else if (scl === 1'b1 && scl_prev === 1'b0) begin
            if (active) begin
                if (bitn < 8) begin
                    sh   = {sh[6:0], sda};
                    bitn = bitn + 1;
                end else begin
                    // Acknowledge bit. While we transmit it is the
                    // master's answer; after the address byte it is
                    // our own ACK, which reads low and so starts the
                    // first byte.
                    send_next = (sda === 1'b0);
                    bitn      = 9;
                end
            end

        end else if (scl === 1'b0 && scl_prev === 1'b1) begin
            if (active) begin
                if (bitn == 8) begin
                    // Eight bits in: the acknowledge slot begins.
                    if (!got_addr) begin
                        got_addr   = 1'b1;
                        addressed  = (sh[7:1] == ADDR);
                        reading    = addressed && sh[0];
                        first_data = 1'b1;
                        sda_oe    <= addressed;
                    end else if (addressed && !reading) begin
                        // rx_data first: testbenches wake on rx_count.
                        rx_data  = sh;
                        rx_count = rx_count + 1;
                        if (first_data) begin
                            ptr        = sh;
                            first_data = 1'b0;
                        end else begin
                            mem[ptr] = sh;
                            ptr      = ptr + 8'd1;
                        end
                        sda_oe <= 1'b1;
                    end else begin
                        sda_oe <= 1'b0;     // the master answers, or not ours
                    end
                    if (addressed && stretch === 1'b1) begin
                        scl_oe <= 1'b1;
                        scl_oe <= #(STRETCH_TIME) 1'b0;
                    end

                end else if (bitn == 9) begin
                    // Acknowledge slot over: next byte.
                    bitn = 0;
                    if (addressed && reading && send_next) begin
                        txb     = mem[ptr];
                        ptr     = ptr + 8'd1;
                        sda_oe <= ~txb[7];
                    end else begin
                        reading = 1'b0;
                        sda_oe <= 1'b0;
                    end

                end else if (addressed && reading) begin
                    sda_oe <= ~txb[7 - bitn];   // next bit, MSB first

                end else begin
                    sda_oe <= 1'b0;
                end
            end
        end

        scl_prev = scl;
        sda_prev = sda;
    end

endmodule
