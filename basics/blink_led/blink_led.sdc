# The EasyFPGA board oscillator drives clk at 50 MHz (20 ns period).
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty

# The LED has no external receiving clock or setup/hold specification.
# Exclude only that output path; all internal counter paths stay timed.
set_false_path -to [get_ports {led}]
