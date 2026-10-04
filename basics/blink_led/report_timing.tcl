# Run after quartus_sh --flow compile blink_led from this directory.
# These reports use the selected operating condition. Check the full
# compilation reports for all timing corners as well.
package require ::quartus::project
package require ::quartus::sta
project_open blink_led
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file output_files/clocks.rpt
report_timing -setup -npaths 5 -detail full_path -file output_files/setup.rpt
report_timing -hold -npaths 5 -detail full_path -file output_files/hold.rpt
report_ucp -file output_files/unconstrained.rpt
delete_timing_netlist
project_close
