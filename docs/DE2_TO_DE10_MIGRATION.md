# DE2 to DE10-Standard Migration

## 1. Goal

The FPGA Snake project was originally configured for the Terasic DE2 board using a Cyclone II FPGA. The goal of this migration was to port the existing design to the DE10-Standard board while keeping the RTL architecture unchanged as much as possible.

The migration focused on understanding which parts of an FPGA design are device-independent and which parts depend on the target board and FPGA technology.

## 2. Original and Target Platforms

Original platform:

* Board: Terasic DE2
* FPGA family: Cyclone II
* Device: EP2C35F672C6
* Main clock: 50 MHz

Target platform:

* Board: Terasic DE10-Standard
* FPGA family: Cyclone V SoC
* Device: 5CSXFC6D6F31C6
* Main clock: 50 MHz

Because both boards provide a 50 MHz clock, most RTL timing parameters could initially remain unchanged.

## 3. What Could Be Reused

The main RTL modules were kept unchanged during the initial port:

* `top_snake_game`
* `game_engine`
* `tick_generator`
* `button_conditioner`
* `ws2812b_driver`

This demonstrated that RTL describes hardware behavior independently from a particular FPGA device, while synthesis maps that RTL onto the resources of the selected technology.

## 4. Timing Constraints

The initial DE10 project compiled without a valid SDC file, causing Quartus to report that the design was not fully constrained.

A 50 MHz clock has a period of:

`T = 1 / 50 MHz = 20 ns`

The following clock constraint was added:

`create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}]`

After the SDC file was correctly added to the project, Quartus recognized the 50 MHz clock and performed meaningful static timing analysis.

The design then achieved positive setup and hold slack.

## 5. Pin Migration

Pin assignments were derived from the DE10-Standard User Manual and verified using the Terasic reference QSF.

The final mapping used:

* `clk_50m`      → CLOCK_50 → PIN_AF14
* `rst_sw`       → SW0      → PIN_AB30
* `key[0]`       → KEY0     → PIN_AJ4
* `key[1]`       → KEY1     → PIN_AK4
* `key[2]`       → KEY2     → PIN_AA14
* `key[3]`       → KEY3     → PIN_AA15
* `led_data_out` → GPIO0    → PIN_W15

The KEY inputs use 3.3-V LVTTL.

`SW0` uses the I/O voltage selected by JP3. With the board's default JP3 configuration, the switch bank operates at 2.5 V.

`GPIO[0]` uses 3.3-V LVTTL.

## 6. Problems Encountered

### 6.1 Wrong FPGA Device

Quartus initially reported illegal pin-location assignments.

The problem was not the pin numbers themselves. The project was targeting the wrong Cyclone V device, so pins such as AF14, AJ4, and AB30 were invalid for the selected package.

Selecting the correct DE10-Standard device resolved the issue.

### 6.2 QSF Assignments Not Applied

Quartus later reported that all seven top-level pins had no exact location assignment.

The I/O standards were visible in Pin Planner, but the Location column was empty.

Inspection of `top_snake_game.qsf` showed that the `set_instance_assignment` commands were present while the `set_location_assignment` commands were missing.

After adding the location assignments to the active QSF file, Quartus correctly placed all seven pins.

### 6.3 Output Drive and Slew Rate

Quartus reported an incomplete I/O assignment for `led_data_out` because drive strength and slew rate were not explicitly specified.

The WS2812B data input was found to be a relatively light digital load, but its electrical interface also introduced a separate voltage-level compatibility question.

### 6.4 WS2812B Logic Level

The WS2812B datasheet specifies:

`VIH(min) = 0.7 × VDD`

Therefore, with a 5 V LED supply:

`VIH(min) = 3.5 V`

A 3.3 V FPGA GPIO does not provide a guaranteed margin against this threshold.

This showed that output drive strength and output voltage are different concepts. Increasing FPGA drive strength does not convert a 3.3 V logic output into a 5 V logic output.

A proper level shifter or a carefully selected WS2812B supply voltage must therefore be considered for the physical implementation.

## 7. Remaining Warnings

After the migration, the design still contains several RTL width-truncation warnings in `ws2812b_driver.sv` and `game_engine.sv`.

Quartus also reports that the reset input is being promoted to a global routing resource even though SW0 is not connected to a dedicated clock input.

These warnings do not currently prevent compilation, but they should be reviewed during RTL cleanup.

## 8. Lessons Learned

This migration showed that moving an RTL design between FPGA boards involves more than changing pin numbers.

The important layers are:

RTL behavior
→ FPGA target device
→ timing constraints
→ physical pin assignment
→ I/O electrical standards
→ timing analysis
→ board-level electrical compatibility

The RTL can often remain largely portable, while constraints, device selection, pin mapping, and electrical interfaces are board-specific.

The most important debugging lesson was to fix problems layer by layer instead of modifying the RTL immediately when Quartus reported an error.
