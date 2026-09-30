# FPGA Snake

A one-dimensional color-matching game implemented in SystemVerilog on the **Terasic DE10-Standard**, using a **60-pixel WS2812B-compatible LED strip** as the display. Shoot colored bullets at an approaching snake and remove all five segments before its head reaches the player.

Gameplay, input handling, and LED transmission run entirely in FPGA logic. The design uses one 50 MHz clock domain and clock-enable ticks for movement.

| Item | Configuration |
| :--- | :--- |
| Board | Terasic DE10-Standard |
| FPGA | Cyclone V SoC, `5CSXFC6D6F31C6` |
| Top-level module | `top_snake_game` |
| Clock | 50 MHz, 20 ns period |
| Display | 60 LEDs, 24-bit GRB, MSB-first |
| Controls | Four active-low push buttons and one active-high reset switch |
| Build tools used | Quartus Prime Lite 23.1std; Questa Intel Starter FPGA Edition 2023.3 |

**Status:** RTL and testbenches are implemented, and the DE10-Standard project has compiled successfully in Quartus. Simulation results and remaining work are recorded [below](#verification-status). Output timing constraints and verification on the physical LED strip remain open.

## How to play

1. Assert `SW0 = 1`, then return it to `0` to reset the game.
2. In `IDLE`, the snake occupies pixels **55–59**, with colors **Red, Green, Blue, Yellow, Red** from head to tail. The other pixels are off.
3. Press and release any color button to start. This first press enters `PLAYING`; it does not fire a bullet.
4. Press a color button again to fire from pixel 0. Match the color of the current snake head.

| Button | Bullet color |
| :--- | :--- |
| `KEY0` | Red |
| `KEY1` | Green |
| `KEY2` | Blue |
| `KEY3` | Yellow |

- The snake moves toward pixel 0, one pixel every **250 ms**. Bullets travel in the opposite direction, one pixel every **50 ms**.
- Only one bullet can be active. Further button events are ignored until it disappears. Holding a button does not repeatedly fire.
- A matching-color collision removes the head and consumes the bullet. If it coincides with `snake_tick`, the remaining segments stay in place for that tick; the movement is not queued.
- A wrong-color collision consumes the bullet without changing the snake length. A simultaneous `snake_tick` still moves the snake normally.
- Collision detection considers the proposed positions after movement, so a bullet and head cannot pass through each other between updates.
- Removing every segment enters `WIN` and displays solid green. The head reaching pixel 0 enters `LOSE` and displays solid red. Both states stop gameplay until reset.

If multiple button events arrive together while firing is allowed, priority is `KEY0` → `KEY1` → `KEY2` → `KEY3`.

See [SPEC.md](docs/SPEC.md) for the full game specification.

## RTL organization

| Module | Responsibility |
| :--- | :--- |
| [top_snake_game](rtl/top_snake_game.sv) | Connects the four functional blocks and synchronizes reset release. |
| [button_conditioner](rtl/button_conditioner.sv) | Synchronizes each active-low key through two flip-flops and produces a one-cycle event on a press. |
| [tick_generator](rtl/tick_generator.sv) | Generates `bullet_tick` and `snake_tick` as clock enables. |
| [game_engine](rtl/game_engine.sv) | Maintains the `IDLE`, `PLAYING`, `WIN`, and `LOSE` states; updates collisions and movement; renders `pixel_data`. |
| [ws2812b_driver](rtl/ws2812b_driver.sv) | Captures a frame, converts logical colors to GRB, and serializes it onto `led_data_out`. |

The game engine receives button events and movement ticks, then supplies an array of 3-bit color codes to the LED driver. The driver cycles through `LOAD` → `SEND` → `LATCH`, capturing a snapshot in `LOAD`. Changes to the game during transmission appear in a later frame.

All blocks use `clk_50m`. Reset assertion is asynchronous; reset release passes through `rst_sync1` and `rst_sync2` before reaching the blocks. The button conditioner performs synchronization and edge detection; mechanical button debounce is provided by the board.

### Default timing and parameters

| Parameter | Hardware default | Meaning |
| :--- | :--- | :--- |
| `LED_COUNT` | 60 | Number of pixels |
| `DEFAULT_SNAKE_LENGTH` | 5 | Initial snake length |
| `BULLET_CYCLES` | 2,500,000 | Clock cycles between bullet ticks |
| `SNAKE_TICKS_COUNT` | 5 | Bullet ticks between snake ticks |
| `T0H` / `T0L` | 15 / 40 | Bit 0: HIGH for 300 ns, LOW for 800 ns |
| `T1H` / `T1L` | 40 / 15 | Bit 1: HIGH for 800 ns, LOW for 300 ns |
| `RES` | 15,000 | LATCH state duration: 300 µs |
| `BITS_PER_PIXEL` | 24 | Eight bits each for Green, Red, and Blue |

These pulse durations describe the current RTL at 50 MHz: each transmitted bit occupies **55 clocks, or 1.1 µs**. They must be checked against the actual LED device and the waveform at its input. Active color channels currently use `8'h3F` brightness.

The initialization explicitly writes five snake colors, and the serializer contains fixed 24-bit logic. Keep the snake length at **5** and pixel depth at **24** unless the corresponding RTL is updated. Simulation overrides shorten movement and latch intervals; they are not the hardware timing configuration. In particular, the driver's timing-counter width currently depends on `RES`, so arbitrary reductions can prevent it from counting a complete bit.

## Repository layout

```text
fpga-snake/
├── rtl/                         # Five SystemVerilog RTL modules
├── tb/                          # Unit and top-level testbenches
├── quartus/top_snake_game/
│   ├── top_snake_game.qpf        # Quartus project
│   ├── top_snake_game.qsf        # Device, source files, pins, and I/O settings
│   └── top_snake_game.sdc        # Clock and timing exceptions
├── docs/                        # Specification, design notes, reports, and waveforms
├── run_top.do                   # Compile and simulate the top-level TB
├── run.do                       # Compile and simulate the LED driver TB
├── re.do                        # Recompile and restart the loaded driver simulation
└── README.md
```

## Run simulations

Use Questa with SystemVerilog and assertion support. Run the commands below in its **Transcript** window, with the working directory set to the repository root. Replace the example path with your checkout location.

### Top-level simulation

```tcl
cd {D:/Project/fpga-snake}
do run_top.do
```

The script recreates the generated `work` library, compiles the RTL and top TB, adds waveform signals, and runs all six scenarios. The top TB uses **12 LEDs**, a **five-segment snake**, and shortened movement/latch intervals. A successful run ends with:

```text
TOP-LEVEL VERIFICATION COMPLETE: 6 PASS, 0 FAIL
```

Also inspect the Transcript for assertion or timing errors. TC6 decodes all 12 pixels, checks the expected GRB data, and measures bit timing. The final LOW interval includes the latch interval and is handled separately in driver waveform review.

### LED driver waveform simulation

```tcl
do run.do
```

The active scenario is `frame_snapshot()`: it changes `pixel_data` during `SEND`, shows that `tx_frame` remains unchanged, and checks the next capture by inspection of the log and waveform. Other driver scenarios are present as tasks but are not called by default. After editing the driver or its TB, use `do re.do` while that simulation is loaded.

### Individual testbenches

To select a unit TB directly, compile the sources and load its module:

```tcl
quit -sim
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv {*}[glob rtl/*.sv] {*}[glob tb/*.sv]
vsim -voptargs="+acc" work.game_engine_tb
add wave -r sim:/game_engine_tb/*
run -all
```

Replace `game_engine_tb` in both commands with `button_conditioner_tb`, `tick_generator_tb`, `ws2812b_driver_tb`, or `top_snake_game_tb` as needed. Read the actual checks in the Transcript; simulator process exit status alone does not establish a passing test.

## Build and program the FPGA

1. Install Quartus Prime Lite with Cyclone V device support and the USB-Blaster driver.
2. Open [top_snake_game.qpf](quartus/top_snake_game/top_snake_game.qpf). The project selects `5CSXFC6D6F31C6` and the `top_snake_game` entity.
3. Run **Processing → Start Compilation**. Review compilation messages and the Timing Analyzer reports, including unconstrained paths.
4. After simulation and hardware connection checks, open **Tools → Programmer**, select the board's USB-Blaster connection, and use JTAG mode.
5. Load the generated `top_snake_game.sof` for the FPGA device, enable **Program/Configure**, and click **Start**. With the current project settings, the file is generated in `quartus/top_snake_game/`.
6. Reset with `SW0`, then follow the gameplay steps above. A JTAG `.sof` download configures the FPGA for the current power session.

For a command-line build, run this from `quartus/top_snake_game/` with Quartus tools on `PATH`:

```text
quartus_sh --flow compile top_snake_game
```

### Board connections

| RTL signal | Board resource | FPGA pin | I/O standard |
| :--- | :--- | :--- | :--- |
| `clk_50m` | `CLOCK_50` | `AF14` | 3.3-V LVTTL |
| `rst_sw` | `SW0` | `AB30` | 2.5 V |
| `key[0]` | `KEY0` | `AJ4` | 3.3-V LVTTL |
| `key[1]` | `KEY1` | `AK4` | 3.3-V LVTTL |
| `key[2]` | `KEY2` | `AA14` | 3.3-V LVTTL |
| `key[3]` | `KEY3` | `AA15` | 3.3-V LVTTL |
| `led_data_out` | `GPIO[0]` | `W15` | 3.3-V LVTTL |

The switch I/O setting assumes the board's default JP3 voltage selection. Package pin `W15` identifies the FPGA pad; use the board connector pinout to locate `GPIO[0]` physically.

Power the LED strip from an appropriate external supply and connect its ground to the DE10-Standard ground. Route `GPIO[0]` to the strip's **DIN** through a logic-level interface compatible with the LED supply; a 3.3 V GPIO does not guarantee a valid HIGH for the documented WS2812B input threshold at a 5 V supply. FPGA GPIO pins supply data, not LED power. See [HARDWARE.md](docs/HARDWARE.md) for integration details and the [selected LED datasheet](docs/WS2812B-2020.PDF) for device limits.

## Verification status

The following results were checked against the working tree on **2026-09-27** using Questa Intel Starter FPGA Edition 2023.3:

| Testbench | Scope | Latest result |
| :--- | :--- | :--- |
| `button_conditioner_tb` | Reset, press, hold, and release | **TC2 fails:** its check samples after the one-cycle event has ended; the sampling time needs correction. |
| `tick_generator_tb` | Reset, tick intervals, and pulse clearing | Completed with no reported errors. |
| `game_engine_tb` | Movement, collisions, firing, reset, and terminal states, including TC13/TC14 | **167 checks reported PASS**, no reported errors. |
| `ws2812b_driver_tb` | Frame snapshot behavior | Log shows the old frame retained during SEND and new data captured next frame. Driver protocol verification also uses manual waveform review and the simulation report. |
| `top_snake_game_tb` | Reset, start, button wiring, movement integration, and serial frame decoding | **6 PASS, 0 FAIL**, no reported assertion errors. |

All RTL and TB sources compile. Questa emits a port-kind warning for the driver's unpacked `pixel_data` input. The driver TB is not a complete automated protocol checker, and these results do not imply exhaustive verification.

The latest recorded Quartus compilation on **2026-09-27** succeeded with **0 errors and 12 warnings**. Timing reports showed positive slack for the analyzed setup, hold, recovery, removal, and minimum-pulse-width checks. The current SDC defines the 20 ns clock and selective exceptions for asynchronous keys and raw reset inputs. **`led_data_out` remains unconstrained**, so full interface timing sign-off is still pending.

### Remaining work

- Correct the sampling time in button TB TC2; tighten X/Z handling in the game TB check helper and align the top button assertion's reset condition with synchronized reset.
- Complete the output timing analysis and constraints for `led_data_out`, including the physical LED interface. This task is currently deferred.
- Review remaining Quartus warnings, including arithmetic width truncation.
- Bring supporting architecture/test documents and the simulation report up to date with recent RTL and TB changes.
- Verify power, data levels, the waveform at LED DIN, and complete gameplay on the actual board and strip. Hardware validation results have not yet been recorded here.

## Documentation

| Document | Contents |
| :--- | :--- |
| [SPEC.md](docs/SPEC.md) | Game behavior and external interface requirements |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | RTL blocks, state machines, and design decisions |
| [HARDWARE.md](docs/HARDWARE.md) | DE10-Standard pin mapping and LED electrical integration |
| [TESTPLAN.md](docs/TESTPLAN.md) | Verification scenarios and expected behavior |
| [Simulation report](docs/simulation_report.pdf) · [LaTeX source](docs/simulation_report.tex) | Test discussion and waveform evidence |
| [DEBUG_LOG.md](docs/DEBUG_LOG.md) | Debugging notes |
| [DE2_TO_DE10_MIGRATION.md](docs/DE2_TO_DE10_MIGRATION.md) | Board migration history |
| [WS2812B-2020 datasheet](docs/WS2812B-2020.PDF) | Timing and electrical requirements for the referenced LED device |

The current hardware target is **DE10-Standard**. DE2 materials are retained as historical references; some supporting documents still describe earlier revisions. For the latest verification outcome and open items, use the status above together with the current RTL, TB, QSF, and SDC files.
