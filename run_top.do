# ==============================================================================
# Script: run_top.tcl
# Mo ta: Tu dong bien dich va mo phong Top-Level top_snake_game_tb tren Questa/ModelSim
# ==============================================================================

# 1. Dung mo phong hien tai neu dang chay
quit -sim

# 2. Xoa va tao moi thu vien work de tranh xung dot file cu
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# 3. Bien dich cac file RTL va Testbench theo dung thu tu phu thuoc
puts "\n--- COMPILING RTL MODULES ---"
vlog -sv -work work rtl/tick_generator.sv
vlog -sv -work work rtl/button_conditioner.sv
vlog -sv -work work rtl/game_engine.sv
vlog -sv -work work rtl/ws2812b_driver.sv
vlog -sv -work work rtl/top_snake_game.sv

puts "\n--- COMPILING TOP-LEVEL TESTBENCH ---"
vlog -sv -work work tb/top_snake_game_tb.sv

# 4. Khoi chay mo phong (vsim)
# -voptargs=+acc: mo full visibility de quan sat wave va SVA
# -assertdebug: ho tro bat su kien assertion SVA
puts "\n--- STARTING SIMULATION ---"
vsim -voptargs="+acc" -assertdebug work.top_snake_game_tb

# 5. Them tin hieu vao cua so Wave
add wave -divider "CLOCKS & RESETS"
add wave -format Logic /top_snake_game_tb/clk
add wave -format Logic /top_snake_game_tb/rst

add wave -divider "INPUT KEYS"
add wave -format Literal -radix binary /top_snake_game_tb/key
add wave -format Literal -radix binary /top_snake_game_tb/DUT/btn_event

add wave -divider "TICK GENERATOR"
add wave -format Logic /top_snake_game_tb/DUT/snake_tick
add wave -format Logic /top_snake_game_tb/DUT/bullet_tick

add wave -divider "GAME ENGINE STATE"
add wave -format Literal -radix ascii  /top_snake_game_tb/DUT/u_game_engine/current_state
add wave -format Decimal              /top_snake_game_tb/DUT/u_game_engine/head_position
add wave -format Decimal              /top_snake_game_tb/DUT/u_game_engine/snake_length
add wave -format Logic                /top_snake_game_tb/DUT/u_game_engine/bullet_active
add wave -format Decimal              /top_snake_game_tb/DUT/u_game_engine/bullet_position
add wave -format Literal -radix binary /top_snake_game_tb/DUT/u_game_engine/bullet_color

add wave -divider "LED OUTPUT"
add wave -format Logic /top_snake_game_tb/led_data_out
add wave -format Literal -radix ascii  /top_snake_game_tb/DUT/u_ws2812b_driver/current_state

# 6. Chay het kịch ban
puts "\n--- RUNNING TESTBENCH ---"
run -all

# Can chinh waveform cho vua man hinh
wave zoom full