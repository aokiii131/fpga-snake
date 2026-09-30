# cd D:/Project/fpga-snake/

quit -sim 

vlib work
vmap work work

vlog -sv rtl/ws2812b_driver.sv
vlog -sv tb/ws2812b_driver_tb.sv

vsim -voptargs="+acc" work.ws2812b_driver_tb

add wave -radix binary -position insertpoint sim:/ws2812b_driver_tb/DUT/*
run -all