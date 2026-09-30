create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}] 

derive_clock_uncertainty

set_false_path -from [get_ports {key*}] -to [get_registers {*u_button_conditioner|sync_ff1*}]

set_false_path -from [get_ports {rst_sw}] -to [get_registers {rst_sync1 rst_sync2}]

# WS2812B has no external sampling clock. Bound the registered DIN output
# path to 0..10 ns (half a clock period) rather than cutting the path.
# TimeQuest includes launch-clock insertion delay in this total. This is
# an FPGA budget, not a model of the cable or LED input thresholds.
set_max_delay 10.000 -to [get_ports {led_data_out}]
set_min_delay 0.000 -to [get_ports {led_data_out}]
