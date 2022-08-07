# Blink led
Simple test of FPGA. 
It blinks a led with a period of 2 seconds. Done by a syncronic process, depending on the input clock, which is of 50MHz (50E6 == 0x2FAF080).

A second led is handled by an active-low button XNOR the led1. So the led2 is not inverted respect to led1 when the button is not pressed (**Button1 is HIGH**), and inverted when is pushed (**Button1 is LOW**)

## Generated logic diagram
Since we are using a syncronic process, there are two D flip-flops: one for the counter, and the other for the output state signals.
![logic diagram](doc/blink_led_diagram.svg)
