# cd D:/Project/fpga-snake/

quit -sim 

vlib work
vmap work work

vlog -sv rtl/game_engine.sv
vlog -sv tb/game_engine_tb.sv

vsim -voptargs="+acc" work.game_engine_tb

add wave -radix binary -position insertpoint sim:/game_engine_tb/DUT/*
run -all