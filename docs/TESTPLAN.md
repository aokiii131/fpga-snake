# VERIFICATION TEST PLAN: FPGA SNAKE GAME

## Scope & Objective
Validate functional correctness for all 4 sub-modules and the integrated Top module:
* `tick_generator`
* `button_conditioner`
* `game_engine`
* `ws2812b_driver`
* `top_snake_game`

---


## 1.`button_conditioner`


### 1.1. Verification Objectives & Methodology
The `button_conditioner` module is responsible for conditioning external asynchronous active-low push buttons (`key[3:0]`) via a 2-stage flip-flop synchronizer and generating a strictly single-cycle pulse (`btn_event[3:0]`) upon negative edge detection (button press).

* **Approach**: Directed functional testing using a synchronous testbench environment.
* **Clock Frequency**: 50 MHz ($T = 20\text{ ns}$).
* **Key Checks**: 
  * Asynchronous/synchronous reset behavior.
  * Synchronization latency (2 clock cycles).
  * 1-clock-cycle pulse width on assertion (`1 -> 0`).
  * Immunity to continuous hold (no re-triggering).
  * Immunity to button release (`0 -> 1`).

---

### 1.2. Test Execution & Coverage Matrix

| Test ID | Test Category | Stimulus / Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC_BTN_01**<br>*(TC1)* | **Reset Verification** | Assert `rst = 1` for 2 cycles with default pull-up `key = 4'b1111`, then de-assert. | Internal sync registers (`sync_ff1`, `sync_ff2`, `prev_sync`) initialize to `'1`; `btn_event` remains `4'b0000`. | **Passed** |
| **TC_BTN_02**<br>*(TC2)* | **Single Press Detection** | Pulse `key[0]` low (`4'b1110`) for 2 cycles, then release back to `4'b1111`. | Exactly 1 cycle after propagation delay, `btn_event[0]` pulses high for exactly 1 clock cycle (`btn_event = 4'b0001`). Other bits remain `0`. | **Passed** |
| **TC_BTN_03**<br>*(TC3)* | **Hold & Release Immunity** | Assert and hold `key[0]` low (`4'b1110`) for 5 consecutive clock cycles; release to high. | • `btn_event[0]` fires exactly **once** on the initial falling edge.<br>• While held low, `btn_event[0] == 0`.<br>• On release ($0 \rightarrow 1$), no event is generated (`btn_event == 4'b0000`). | **Passed** |
| **TC_BTN_04**<br>*(Future / TC4)* | **Multi-Button / Concurrent Press** | Simultaneously or sequentially assert multiple keys (e.g., `key = 4'b1100` or `4'b0000`). | Each bit channel operates independently; matching multi-bit pulses on `btn_event` with zero cross-channel crosstalk. | **Planned** |
| **TC_BTN_05**<br>*(Future)* | **Fast Pulse (Metastability / Glitch)** | Apply a narrow active-low glitch shorter than 1 clock period on `key`. | Signal is either cleanly absorbed or synchronized safely without producing false multiple pulses or unknown (`X`) states. | **Planned** |

---

## 2. `tick_generator`


### 2.1. Verification Objectives & Methodology
The `tick_generator` module operates as a synchronous rate divider producing single-cycle pulse enables (`bullet_tick` and `snake_tick`) rather than derived clocks. It uses a cascaded counter topology where `snake_tick` is gated and divided down directly from `bullet_tick` events.

* **Approach**: Scaled-down parameter-based directed testing.
* **Simulation Scaling**: To avoid simulating millions of idle clock cycles ($2{,}500{,}000$ cycles for 50 ms), the testbench overrides parameter constants (`TB_BULLET_CYCLES = 5`, `TB_SNAKE_TICKS = 5`).
* **Key Checks**:
  * Asynchronous reset assertion clears all internal counters and tick outputs to zero.
  * Correct period and single-cycle duration for `bullet_tick`.
  * Correct prescaling factor and single-cycle duration for `snake_tick`.
  * Proper auto-clearing (self-deassertion to 0) of both tick pulses on the immediately following clock cycle.

---

### 2.2. Test Execution & Coverage Matrix

| Test ID | Test Category | Stimulus / Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC_TICK_01**<br>*(TC0)* | **Reset Verification** | Assert asynchronous `rst = 1` for 2 cycles, then release. | • `bullet_counter` and `snake_count` clear to 0.<br>• `bullet_tick == 0` and `snake_tick == 0` during and immediately after reset. | **Passed** |
| **TC_TICK_02**<br>*(TC1)* | **Bullet Tick Periodicity** | Run clock continuously for `TB_BULLET_CYCLES` cycles after reset. | `bullet_tick` pulses high (`1`) precisely at cycle boundary (`BULLET_CYCLES - 1`). | **Passed** |
| **TC_TICK_03**<br>*(TC2)* | **Snake Tick Cascading** | Propagate simulation through `TB_SNAKE_TICKS` successive bullet cycles (total $5 \times 5 = 25$ clock cycles). | `snake_tick` asserts high (`1`) synchronously aligned with the $N$-th `bullet_tick`. | **Passed** |
| **TC_TICK_04**<br>*(TC3 & TC4)* | **Single-Cycle Pulse Duration** | Sample outputs 1 clock cycle after `bullet_tick` and `snake_tick` assertion. | Both `bullet_tick` and `snake_tick` de-assert to `0` after exactly 1 cycle (no latching / sticky flags). | **Passed** |
| **TC_TICK_05**<br>*(Future)* | **Continuous Multi-Period & Rollover** | Allow simulation to run across 3+ full snake tick cycles continuously. | Counters roll over accurately without drift or phase jitter; ticks maintain strictly constant intervals. | **Planned** |
| **TC_TICK_06**<br>*(Future)* | **Mid-Count Asynchronous Reset** | Assert `rst = 1` arbitrarily while counters are mid-count (e.g., cycle 3 of 5). | Immediate drop of internal counters and output ticks to 0 without false glitch triggers. | **Planned** |

---

## 3. `game_engine`


### 3.1. Verification Objectives & Methodology
The `game_engine` module implements the core FSM and datapath of the Snake shooter game, controlling snake positioning, bullet firing, collision look-ahead logic, win/lose criteria, and mapping game entities to the output strip array (`pixel_data`).

* **Approach**: Self-checking task-based directed simulation with assertion checks (`check` task) and cycle-accurate tracking (`$past`).
* **Design Configurations**: Parameterized with `LED_COUNT = 60` and `DEFAULT_LENGTH = 5`.
* **Key Verification Areas**:
  * **FSM Transitions**: `IDLE` $\rightarrow$ `PLAYING` $\rightarrow$ `WIN`/`LOSE` $\rightarrow$ Reset to `IDLE`.
  * **Bullet Generation & Movement**: Single-active bullet constraint, 4-button color mapping priority encoder, forward progression on `bullet_tick`.
  * **Snake Movement**: Array shifting towards index 0 on `snake_tick`.
  * **Collision & Look-Ahead**: Same-color hit (snake shrinks, bullet vanishes) vs. mismatched color miss (bullet vanishes, snake unchanged).
  * **Corner Cases**: Simultaneous `bullet_tick` & `snake_tick` in the same cycle, and button spam/hold immunity during inflight bullet.
  * **Display Rendering**: Correct overlay on `pixel_data` across `PLAYING`, all-green on `WIN`, and all-red on `LOSE`.

---

### 3.2. Test Execution & Coverage Matrix

| Test ID | Test Category / Objective | Stimulus / Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC_GAME_01**<br>*(TC1)* | **Reset & Initialization** | Assert `rst = 1` for 2 clock cycles then de-assert. | • FSM initializes to `IDLE`.<br>• `snake_length = 5`, `head_position = 55`.<br>• `bullet_active = 0`.<br>• Snake array populated at indices 55–59 with preset pattern `[RED, GREEN, BLUE, YELLOW, RED]`. | **Passed** |
| **TC_GAME_02**<br>*(TC2)* | **FSM: IDLE to PLAYING** | In `IDLE`, apply a single-cycle pulse on `btn_event`. | FSM transitions cleanly to `PLAYING` on the next clock cycle. | **Passed** |
| **TC_GAME_03**<br>*(TC3)* | **Snake Movement** | In `PLAYING`, assert 1-cycle `snake_tick = 1`. | • `head_position` decrements by 1 (55 $\rightarrow$ 54).<br>• Whole snake body shifts left by 1 index (`snake_array[54:58]` valid, `snake_array[59]` cleared to `OFF`). | **Passed** |
| **TC_GAME_04**<br>*(TC4)* | **Bullet Generation & Spawn** | Assert `btn_event[0]` (Red trigger) while `bullet_active == 0`. | • `bullet_active` asserts to `1`, `bullet_position = 0`, `bullet_color = RED`.<br>• `pixel_data[0]` renders `RED`, all subsequent cells remain `OFF`. | **Passed** |
| **TC_GAME_05**<br>*(TC5)* | **Bullet Forward Progression** | Assert 1-cycle `bullet_tick = 1`. | • `bullet_position` increments by 1 (0 $\rightarrow$ 1).<br>• `pixel_data[0]` turns `OFF`, `pixel_data[1]` renders `RED`. | **Passed** |
| **TC_GAME_06**<br>*(TC6)* | **Hit Collision (Matching Color)** | Step bullet forward until `bullet_position` collides with matching head color (`RED`). | • Bullet consumed: `bullet_active = 0`, `bullet_color = OFF`.<br>• Hit registered: `snake_length` decrements (5 $\rightarrow$ 4), `head_position` increments (54 $\rightarrow$ 55).<br>• Destroyed head cleared to `OFF` in `pixel_data`. | **Passed** |
| **TC_GAME_07**<br>*(TC7)* | **Miss Collision (Mismatched Color)** | Fire non-matching bullet (`YELLOW`), advance until collision with `head_position`. | • Bullet consumed: `bullet_active = 0`.<br>• Game remains in `PLAYING`.<br>• Snake body unharmed: `snake_length` and `head_position` remain unchanged. | **Passed** |
| **TC_GAME_08**<br>*(TC8)* | **Win State Trigger & Render** | Repeatedly fire matching bullets until `snake_length == 0`. | • FSM transitions to `WIN`.<br>• Entire array `pixel_data[0:59]` lights up solid `GREEN`. | **Passed** |
| **TC_GAME_09**<br>*(TC9)* | **Lose State Trigger & Render** | Advance snake via `snake_tick` without hitting bullets until `head_position == 0`. | • FSM transitions to `LOSE`.<br>• Entire array `pixel_data[0:59]` lights up solid `RED`. | **Passed** |
| **TC_GAME_10**<br>*(TC10)* | **Game Restart from Terminal State** | Assert `rst = 1` while in `LOSE` state. | FSM reliably returns to `IDLE`; snake position/length, bullet registers, and arrays restore to defaults. | **Passed** |
| **TC_GAME_11**<br>*(TC11)* | **Simultaneous Tick Handling** | Assert `bullet_tick = 1` and `snake_tick = 1` simultaneously (both normal motion and at collision boundary). | • Movement: Bullet steps right (+1) while snake steps left (-1) cleanly in the same clock edge.<br>• Collision: Look-ahead logic correctly detects head-on collision without clipping through each other. | **Passed** |
| **TC_GAME_12**<br>*(TC12)* | **Rapid-Fire & Spam Prevention** | While a bullet is inflight, stress with: (1) Random button spam, (2) Multi-button combo (`4'b1111`), (3) Multi-cycle continuous hold. | • Inflight bullet unaffected in position, active state, and color.<br>• No new bullet spawned at index 0 (`pixel_data[0] == OFF`). | **Passed** |

---

---

## 4. `ws2812b_driver`

### 4.1. Verification Objectives & Methodology
The `ws2812b_driver` module serializes a 3-bit logical pixel array (`pixel_data`) into standard 24-bit GRB pulses for WS2812B addressable LEDs over a single-wire interface (`led_data_out`). It executes an iterative FSM loop: frame latching (`LOAD`), pulse serialization (`SEND`), and reset latch hold (`LATCH`).

* **Approach**: Scaled-down directed simulation environment targeting timing boundaries, FSM looping, and data snapshot integrity.
* **Simulation Scaling**: Scaled down via module parameters (`TEST_LEDS = 3`, `TEST_RES = 50`) to accelerate simulation time while preserving cycle-level protocol fidelity.
* **Key Checks**:
  * Asynchronous reset initialization to `LOAD` with zeroed counters.
  * Frame snapshot isolation (changes on `pixel_data` mid-transmission must not corrupt the current `tx_frame`).
  * 3-to-24 bit GRB color decoding accuracy.
  * FSM state progression and handoff: `LOAD` $\rightarrow$ `SEND` $\rightarrow$ `LATCH` $\rightarrow$ `LOAD`.
  * Cycle-accurate single-wire pulse timing for Bit 0 ($T0H/T0L$) and Bit 1 ($T1H/T1L$).

---

### 4.2. Test Execution & Coverage Matrix

| Test ID | Test Category / Objective | Stimulus / Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC_DRV_01**<br>*(TC1)* | **Reset Behavior & Initialization** | Assert `rst = 1` for 2 cycles, then release back to `0`. | • FSM initializes to `LOAD`.<br>• `pixel_counter = 0`, `bit_counter = 23`, `timing_counter = 0`.<br>• `led_data_out = 0`. | **Passed** |
| **TC_DRV_02**<br>*(TC2)* | **TX Frame Capture** | In `LOAD` state, drive random data across `pixel_data[0:TEST_LEDS-1]`. | Entire `pixel_data` array is captured atomically into internal buffer `tx_frame`; FSM immediately advances to `SEND`. | **Passed** |
| **TC_DRV_03**<br>*(TC5)* | **Frame Snapshot Isolation** | Modify `pixel_data` values after the module transitions from `LOAD` to `SEND`. | `tx_frame` remains locked to the original snapshot values; no tearing or mid-frame color corruption occurs. | **Passed** |
| **TC_DRV_04**<br>*(TC3)* | **Serialization to Latch Handoff** | Run clock until all LEDs and bits complete transmission (`pixel_counter == LED_COUNT - 1`, `bit_counter == 0`, `timing_counter == BIT_TOTAL_CYCLES - 1`). | FSM cleanly transitions from `SEND` to `LATCH` state. | **Passed** |
| **TC_DRV_05**<br>*(TC4)* | **Latch Reset Hold & Loopback** | Maintain simulation in `LATCH` until `timing_counter == RES - 1`. | • `led_data_out` holds continuously at `0` for the entire `RES` duration.<br>• FSM loops back to `LOAD` to capture the next frame. | **Passed** |
| **TC_DRV_06**<br>*(Future / Timing)* | **1-Wire Bit Waveform Timing** | Sample `led_data_out` high and low pulse widths during `SEND` for Bit 0 and Bit 1. | • Bit 0: High for exactly `T0H` (15 cycles), Low for `T0L` (40 cycles).<br>• Bit 1: High for exactly `T1H` (40 cycles), Low for `T1L` (15 cycles). | **Planned** |
| **TC_DRV_07**<br>*(Future / Protocol)* | **GRB Decoding Verification** | Inject distinct logical colors (`RED: 3'b001`, `GREEN: 3'b010`, `BLUE: 3'b011`, `YELLOW: 3'b100`, `OFF: 3'b000`). | Serial bitstream decodes correctly to standard 24-bit GRB formats (`24'h00_3F_00`, `24'h3F_00_00`, `24'h00_00_3F`, `24'h3F_3F_00`, `24'h00_00_00`) with MSB-first transmission. | **Planned** |

---

## 5. `top_snake_game`


### 5.1. Verification Objectives & Methodology
The `top_snake_game` module integrates all four sub-systems (`tick_generator`, `button_conditioner`, `game_engine`, and `ws2812b_driver`). Verification focuses on end-to-end signal propagation, inter-module interface wiring, protocol-compliant 1-wire serialization, and continuous assertion-based invariant monitoring.

* **Approach**: Top-level integration testbench featuring:
  * **SystemVerilog Assertions (SVA)**: Concurrent background checks for synchronizer pulse compliance and driver output stuck-at-fault prevention.
  * **Real-time Protocol Checker Task**: Cycle-accurate pulse-width measurement task (`read_pixel_24bit`) that samples physical timings ($T_{high}, T_{low}$) on `led_data_out` to reconstruct and validate 24-bit GRB frames.
* **Simulation Scaling**: Scaled down via `defparam` overrides (`BULLET_CYCLES_TEST = 20`, `RES_TEST = 40`, `LED_COUNT_TEST = 6`, `LENGTH_TEST = 3`) to expedite multi-module interaction loops.
* **Key Verification Areas**:
  * Global asynchronous reset dissemination across all child FSMs and counter pipelines.
  * End-to-end dataflow: Button input edge $\rightarrow$ Synchronized pulse $\rightarrow$ Game state mutation $\rightarrow$ Memory map update $\rightarrow$ Serial bitstream output.
  * Inter-module tick pacing and physical timing margins on the 1-wire bus.

---

### 5.2. Test Execution & Coverage Matrix

| Test ID | Test Category / Objective | Stimulus / Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC_TOP_01**<br>*(TC1)* | **Global System Reset** | Assert `rst_sw = 1` for 5 clock cycles, then de-assert. | All sub-modules initialize cleanly:<br>• `game_engine` enters `IDLE`.<br>• `ws2812b_driver` enters `LOAD`.<br>• All internal event/tick wires reset to `0`. | **Passed** |
| **TC_TOP_02**<br>*(TC2)* | **System Start / Wake-Up** | In `IDLE`, pulse active-low `key[2]` low for 2 clock cycles. | Synchronizer issues `btn_event[2]`; `game_engine` transitions successfully from `IDLE` to `PLAYING`. | **Passed** |
| **TC_TOP_03**<br>*(TC3)* | **End-to-End Button to Pixel Fire** | In `PLAYING`, press `key[0]` (Red trigger). | • `btn_event[0]` fires after 2-cycle latency.<br>• `game_engine` spawns `RED` bullet (`bullet_active = 1`).<br>• `pixel_data[0]` immediately renders `RED`. | **Passed** |
| **TC_TOP_04**<br>*(TC4)* | **Key Wiring & Channel Isolation** | Sequentially toggle active-low inputs `key[1]`, `key[0]`, and `key[3]`. | Each physical input pin routes strictly to its corresponding `btn_event` channel bit without cross-talk or transposition. | **Passed** |
| **TC_TOP_05**<br>*(TC5)* | **Inter-Module Tick Propagation** | Wait for `BULLET_CYCLES_TEST + 5` clock cycles after firing a bullet. | `tick_generator` pulses `bullet_tick` into `game_engine`; inflight bullet steps forward (`bullet_position > 0`). | **Passed** |
| **TC_TOP_06**<br>*(TC6)* | **Hardware Bitstream & Waveform Verification** | Real-time monitoring of `led_data_out` using testbench protocol checker task (`read_pixel_24bit`). | • Timing widths strictly adhere to WS2812B specs ($T0H \approx 300\text{ ns}$, $T1H \approx 800\text{ ns}$).<br>• Captured serial 24-bit GRB frame matches expected hex encoding (`24'h00_3F_00` for Red or `24'h00_00_00` for Off). | **Passed** |

---

### 5.3. SystemVerilog Assertions (SVA) Formal Monitoring

| Assertion Property | Monitored Signal / Interface | Formal Property Specification | Target Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **SVA 1**<br>`p_btn0_event` | `key[0]` $\rightarrow$ `btn_event[0]` | `@(posedge clk) disable iff (rst)`<br>`$fell(key[0]) \|-> ##2 (btn_event[0] == 1) ##1 (btn_event[0] == 0)` | Guarantees exact 2-cycle synchronization latency and strictly 1-cycle event pulse width on falling edges. | **Active / 0 Violations** |
| **SVA 2**<br>`p_no_stuck_high` | `led_data_out` | `@(posedge clk)`<br>`led_data_out \|-> ##[1:45] (led_data_out == 1'b0)` | Asserts that `led_data_out` never locks high for longer than maximum Bit 1 duration ($T1H = 40\text{ cycles} + 5\text{ margin}$). | **Active / 0 Violations** |