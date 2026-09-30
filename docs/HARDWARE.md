# FPGA Snake — Hardware Integration

## 1. Purpose

This document defines the board-level hardware configuration and physical interfaces used by the FPGA Snake project.

It covers:

* DE10-Standard board resources;
* FPGA pin assignments;
* I/O standards;
* external WS2812B connections;
* LED power and logic-level requirements.

Game behavior is defined in `SPEC.md`.

RTL structure and implementation decisions are defined in `ARCHITECTURE.md`.

---

## 2. Target Hardware

### 2.1 FPGA Board

The project targets the **Terasic DE10-Standard** development board.

| Property        | Value                            |
| :-------------- | :------------------------------- |
| FPGA Family     | Cyclone V SoC                    |
| FPGA Device     | `5CSXFC6D6F31C6`                 |
| System Clock    | 50 MHz                           |
| Quartus Version | Quartus Prime Lite 23.1          |
| LED Interface   | WS2812B-compatible RGB LED strip |

### 2.2 External Hardware

The project requires:

* one WS2812B-compatible LED strip;
* an external regulated power supply for the LED strip;
* wiring for data, power, and common ground;
* optional logic-level shifting between the FPGA and WS2812B.

The FPGA GPIO shall not be used to power the LED strip.

---

## 3. DE10-Standard Pin Mapping

The project uses the following DE10-Standard resources:

| RTL Signal     | Board Resource | FPGA Pin   | I/O Standard | Function            |
| :------------- | :------------- | :--------- | :----------- | :------------------ |
| `clk_50m`      | `CLOCK_50`     | `PIN_AF14` | 3.3-V LVTTL  | 50 MHz system clock |
| `rst_sw`       | `SW0`          | `PIN_AB30` | 2.5 V        | Reset input         |
| `key[0]`       | `KEY0`         | `PIN_AJ4`  | 3.3-V LVTTL  | Color button        |
| `key[1]`       | `KEY1`         | `PIN_AK4`  | 3.3-V LVTTL  | Color button        |
| `key[2]`       | `KEY2`         | `PIN_AA14` | 3.3-V LVTTL  | Color button        |
| `key[3]`       | `KEY3`         | `PIN_AA15` | 3.3-V LVTTL  | Color button        |
| `led_data_out` | `GPIO[0]`      | `PIN_W15`  | 3.3-V LVTTL  | WS2812B serial data |

These assignments are implemented in the Quartus `.qsf` file.

### 3.1 Push Buttons

`KEY0` through `KEY3` are active-low:

```text
Released → logic 1
Pressed  → logic 0
```

The DE10-Standard provides hardware debounce for these push buttons.

### 3.2 Reset Switch

`SW0` is used as the reset input:

```text
DOWN → logic 0
UP   → logic 1
```

The switch-bank I/O voltage depends on jumper `JP3`.

With the default DE10-Standard JP3 configuration, the corresponding VCCIO is **2.5 V**. Therefore, `rst_sw` is assigned the `2.5 V` I/O standard in Quartus.

### 3.3 WS2812B Data Output

`GPIO[0]`, FPGA pin `PIN_W15`, is used as the serial LED data output.

The FPGA output uses:

```text
I/O Standard: 3.3-V LVTTL
```

Output drive strength and slew rate are explicitly configured in the Quartus pin assignments.

---

## 4. WS2812B Physical Interface

The LED strip requires three connections:

| WS2812B Signal | Connection                     | Purpose                  |
| :------------- | :----------------------------- | :----------------------- |
| `DIN`          | DE10-Standard `GPIO[0]`        | Serial pixel data        |
| `VDD`          | External regulated supply      | LED power                |
| `GND`          | External supply GND + DE10 GND | Common voltage reference |

The basic connection is:

```text
DE10-Standard
GPIO[0] / PIN_W15
        |
        +----------------------> WS2812B DIN


External Supply
     +V ----------------------> WS2812B VDD

     GND ----+----------------> WS2812B GND
             |
DE10 GND ----+
```

The DE10-Standard and LED power supply must share a common ground.

---

## 5. LED Power

The WS2812B strip shall be powered from an external regulated supply.

The required current depends on:

* number of LEDs;
* LED brightness;
* displayed RGB values;
* animation pattern.

The power source shall therefore provide sufficient current for the intended operating condition.

The LED strip shall **not** be powered from an FPGA GPIO pin.

If a DC-DC regulator is used, it belongs only in the power path:

```text
Power Source
     |
     v
DC-DC Regulator
     |
     v
WS2812B VDD
```

A DC-DC power regulator shall not be used to convert the FPGA serial data signal.

---

## 6. Logic-Level Compatibility

The selected WS2812B datasheet specifies:

```text
VDD operating range = 3.7 V to 5.3 V

VIH(min) = 0.7 × VDD
VIL(max) = 0.3 × VDD
```

For example, if:

```text
VDD = 5.0 V
```

then:

```text
VIH(min) = 0.7 × 5.0
         = 3.5 V
```

The DE10-Standard data output uses 3.3-V logic. Therefore, direct connection to a WS2812B powered at 5 V does not provide a guaranteed HIGH-level margin according to these requirements.

### 6.1 Preferred Interface

The robust solution is:

```text
DE10 GPIO
3.3-V logic
     |
     v
Logic-Level Buffer / Level Shifter
     |
     v
WS2812B DIN
```

The buffer converts the FPGA logic level into a level compatible with the LED supply domain.

### 6.2 Reduced LED Supply Voltage

Another possible implementation is to operate the WS2812B at a lower voltage within its specified operating range.

For example:

```text
VDD = 4.5 V

VIH(min) = 0.7 × 4.5
         = 3.15 V
```

This reduces the required HIGH threshold.

This approach shall be treated as a physical implementation choice and verified on the actual hardware.

---

## 7. Data-Line Electrical Characteristics

The selected WS2812B datasheet specifies approximately:

```text
Input capacitance ≈ 15 pF
Input current     ≈ ±1 µA maximum
```

The WS2812B `DIN` therefore represents a relatively light load for the FPGA output.

Two FPGA output properties are relevant:

### Drive Strength

Drive strength controls the output buffer's ability to source or sink current and charge or discharge the connected capacitive load.

A larger drive strength does **not** increase a 3.3 V GPIO signal into a 5 V logic signal.

### Slew Rate

Slew rate controls how quickly the output transitions between LOW and HIGH.

It affects:

* rise and fall time;
* ringing;
* signal integrity;
* electromagnetic noise.

Drive strength and slew rate are therefore electrical signal-quality settings and are separate from logic-level conversion.

---

## 8. Quartus Hardware Constraints

Board-level assignments are stored in the Quartus QSF file.

The important assignments include:

```text
FPGA device
Physical pin locations
I/O standards
Output drive strength
Output slew rate
```

Timing constraints are stored separately in:

```text
top_snake_game.sdc
```

The system clock is constrained as a 50 MHz clock with a 20 ns period.

The separation is:

```text
HARDWARE.md
   → How the FPGA connects to the physical board and external hardware

.qsf
   → Actual FPGA device and pin configuration

.sdc
   → Timing constraints
```

---

## 9. Hardware Bring-Up

Hardware integration should be verified incrementally:

1. Program the DE10-Standard successfully.
2. Verify the 50 MHz clock and reset.
3. Verify `KEY0` through `KEY3`.
4. Verify the selected GPIO output.
5. Connect the WS2812B electrical interface.
6. Verify a static LED color.
7. Verify control of individual LED positions.
8. Verify moving LED behavior.
9. Integrate the complete game.

If a stage fails, that stage should be debugged before proceeding to the next one.
