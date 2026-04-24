// tb_pwm_led.v - Verilog mirror of tb_pwm_led.vhd.

`timescale 1ns/1ps

module tb_pwm_led;

    localparam integer WIDTH      = 8;
    localparam time    CLK_PERIOD = 20;

    reg              sClk = 1'b0;
    reg  [WIDTH-1:0] sDuty = {WIDTH{1'b0}};
    wire             sPwm;

    pwm_led #(.WIDTH(WIDTH)) dut (
        .clk     (sClk),
        .duty    (sDuty),
        .pwm_out (sPwm)
    );

    always #(CLK_PERIOD/2) sClk = ~sClk;

    integer d, c, observed;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_pwm_led);

        for (d = 0; d <= 255; d = d + 1) begin
            if ((d % 32) == 0 || d == 255) begin
                sDuty = d[WIDTH-1:0];
                #(CLK_PERIOD);
                observed = 0;
                for (c = 0; c < (1 << WIDTH); c = c + 1) begin
                    #(CLK_PERIOD);
                    if (sPwm) observed = observed + 1;
                end
                if (observed != d)
                    $fatal(1, "duty=%0d expected %0d got %0d",
                           d, d, observed);
            end
        end
        $display("pwm_led simulation done!");
        $finish;
    end

endmodule
