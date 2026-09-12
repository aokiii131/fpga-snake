# FPGA Snake — System Specification

**Document Status:** Specification Baseline v0.1\
**Target Platform:** Altera DE2 Development and Education Board\
**Target FPGA:** Cyclone II EP2C35F672C6\
**HDL:** SystemVerilog\
**Primary Clock:** 50 MHz\
**LED Interface:** WS2812B-compatible single-wire interface\
**LED Count:** 60 pixels

---

## 1. Purpose and Scope

This document defines the externally observable functional requirements,
hardware requirements, and mandatory timing constraints for the FPGA
Snake project.

The system shall implement a one-dimensional game on a 60-pixel WS2812B LED strip connected to an Altera DE2 development board.

The system shall:

1. Drive a 60-pixel WS2812B LED strip.
2. Display a moving multi-color snake.
3. Accept four physical pushbuttons as color-selection inputs.
4. Generate a color-coded bullet when a valid button press is detected.
5. Move the bullet along the LED strip toward the snake.
6. Detect collisions between the bullet and the snake head.
7. Modify the snake according to the collision result.
8. Detect win and lose conditions.
9. Operate from the DE2 50 MHz master clock.

The project shall not include additional features such as score tracking, multiple levels, sound output, UART communication, seven-segment display output, or other gameplay mechanisms unless they are explicitly added to this specification.

This document specifies **what the system shall do**. RTL structure, module decomposition, internal data representation, and implementation-specific design decisions shall be documented separately in [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## 2. System Boundaries and Requirements

The system boundary includes:

- The DE2 50 MHz clock input.
- The DE2 pushbutton inputs.
- The `SW[17]` reset/start input.
- The WS2812B data output.
- The game behavior visible on the LED strip.

The following items are outside the functional scope of this specification:

- Internal RTL module hierarchy.
- Internal FSM encoding.
- Internal snake data representation.
- Internal bullet data representation.
- Internal pixel-buffer implementation.
- Internal debounce algorithm.
- Internal frame-buffer transfer mechanism.

These implementation details shall not change the externally observable behavior defined in this document.

---

## 3. Hardware Platform

### 3.1 FPGA Device

The target FPGA shall be:

```text
Altera Cyclone II EP2C35F672C6
```

The target development board shall be the Altera DE2 Development and Education Board.

### 3.2 Master Clock

The DE2 master oscillator shall operate at:

```text
Frequency: 50 MHz
Period:    20 ns
Pin:       PIN_N2
```

All synchronous system behavior shall be derived from this clock.

The design shall meet timing closure at:

```text
Clock frequency: 50 MHz
Clock period:    20 ns
```

---

## 4. User Input Interface

The system shall use the four on-board DE2 pushbuttons as bullet-color inputs.

All pushbuttons shall be treated as active-low inputs:

```text
Logic 0 = pressed
Logic 1 = released
```

### 4.1 Button Mapping

| Button   | FPGA Pin  | Function             |
| -------- | --------- | -------------------- |
| `KEY[0]` | `PIN_G26` | Fire a Red bullet    |
| `KEY[1]` | `PIN_N23` | Fire a Green bullet  |
| `KEY[2]` | `PIN_P23` | Fire a Blue bullet   |
| `KEY[3]` | `PIN_W26` | Fire a Yellow bullet |

### 4.2 Button Event Requirements

A physical button press shall generate at most one logical firing event.

The system shall:

1. Synchronize button inputs to the 50 MHz clock domain.
2. Interpret the active-low input polarity correctly.
3. Prevent mechanical contact bounce from generating multiple firing events.
4. Generate a single logical button event for each valid press.

The presence of hardware Schmitt-trigger circuitry shall not be considered sufficient for clock-domain synchronization or event generation.

The debounce implementation and debounce interval are implementation details and shall be documented in [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## 5. Reset and Start Control

The system shall use `SW[17]` as the global reset control.

Reset shall initialize the system to the IDLE state as specified above.

SW[17] = 1 (UP position) shall assert reset.
SW[17] = 0 (DOWN position) shall release reset and allow the system to run.

When reset is asserted, the system shall:

1. Clear the LED output state.
2. Initialize the snake to its initial five-segment configuration.
3. Set the bullet state to inactive.
4. Initialize the game state.
5. Enter the idle state.

In the idle state:

- The snake shall remain stationary.
- No bullet shall be active.
- The first valid button event shall start gameplay.

The reset behavior shall be implemented consistently throughout the design.

The implementation of the reset circuitry is an internal RTL design decision
and shall be documented in [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## 6. LED Strip Interface

The system shall drive a WS2812B-compatible LED strip through a single data wire.

### 6.1 Electrical Requirements

The LED strip shall be powered by a dedicated external 5 V power supply.

The DE2 expansion-header 5 V supply shall not be used to power the 60-pixel LED strip.

The LED data connection shall be:

```text
FPGA GPIO: GPIO_0[0]
FPGA Pin:  PIN_D25
```

The DE2 FPGA GPIO output voltage shall be treated as 3.3 V.

A suitable 3.3 V-to-5 V level shifter is recommended for the WS2812B data signal when required by the selected LED strip or electrical setup.

The FPGA output shall not be connected to an incompatible voltage level.

The FPGA ground and LED-strip power-supply ground shall share a suitable common reference.

---

## 7. WS2812B Protocol Requirements

The LED strip shall use a single-wire NZR (Non-Return-to-Zero) communication protocol.

The nominal data rate shall be:

```text
800 Kbps
```

Each pixel shall receive 24 bits of color data.

The transmission format shall be:

```text
G7 G6 ... G0
R7 R6 ... R0
B7 B6 ... B0
```

The protocol requirements are:

```text
24 bits per pixel
GRB byte order
Most Significant Bit first
```

Each physical pixel shall consume the first 24 bits intended for it and forward the remaining data stream to the next pixel.

---

## 8. WS2812B Timing Requirements

The WS2812B waveform shall be generated from the 50 MHz master clock.

One clock cycle shall correspond to:

```text
20 ns
```

The baseline timing requirements are:

| Parameter | Description           |         Target Time |
| --------- | --------------------- | ------------------: |
| `T0H`     | Logical `0` high time |          220–380 ns |
| `T0L`     | Logical `0` low time  |         580 ns–1 µs |
| `T1H`     | Logical `1` high time |         580 ns–1 µs |
| `T1L`     | Logical `1` low time  |          220–420 ns |
| `RES`     | Reset/latch low time  |             >280 µs |

The generated waveform shall use deterministic timing derived from the 50 MHz clock.

The logical `0` and logical `1` waveforms shall satisfy the timing requirements defined above.

The physical timing requirements shall be checked against the datasheet for the actual LED strip used in the project. If the actual strip requires different timing limits, this specification shall be updated before final implementation.

---

## 9. LED Frame Requirements

The system shall control:

```text
60 pixels
```

Each pixel shall contain:

```text
24 bits
```

One complete frame shall contain:

```text
60 × 24 = 1,440 bits
```

Pixels shall be transmitted in physical strip order:

```text
Pixel 0
Pixel 1
...
Pixel 59
```

Pixel 0 shall be the end physically connected to the FPGA data output.

The logical pixel values generated by the game shall be transmitted to the LED strip using the WS2812B protocol defined in this specification.

The LED output shall represent the current game state.

---

## 10. Color Definitions

The system shall support the following gameplay colors:

- Red
- Green
- Blue
- Yellow

The nominal brightness shall be approximately 25% of the maximum brightness.

The active color intensity shall use:

```text
8'h3F
```

The logical pixel values shall use the following 24-bit GRB encoding:

| Color       | 24-bit GRB Value |
| ----------- | ---------------- |
| Green       | `24'h3F_00_00`   |
| Red         | `24'h00_3F_00`   |
| Blue        | `24'h00_00_3F`   |
| Yellow      | `24'h3F_3F_00`   |
| Off / Empty | `24'h00_00_00`   |

These values shall be used consistently for snake segments, bullets, win indication, lose indication, and empty pixels.

---

## 11. LED Strip Arrangement and Coordinate System

The LED strip shall be treated as a one-dimensional linear array.

```text
      Pixel 0                       Pixel 59
        │                               │
        ▼                               ▼
    Player / FPGA                   Far end
```

The coordinate system shall be:

```text
Pixel 0  = end connected to the FPGA data output
Pixel 59 = far end of the strip
```

The snake shall initially occupy Pixels 55 through 59.

The snake shall move toward decreasing pixel indices.

The bullet shall move toward increasing pixel indices.

---

## 12. Snake Requirements

### 12.1 Initial Snake State

After reset, the system shall initialize a five-segment snake occupying:

```text
Pixel 55
Pixel 56
Pixel 57
Pixel 58
Pixel 59
```

The initial snake length shall be:

```text
5 segments
```

The initial head position shall be:

```text
Pixel 55
```

### 12.2 Snake Color Pattern

The snake shall use a fixed repeating color pattern consisting of:

```text
Pixel 55 = Red
Pixel 56 = Green
Pixel 57 = Blue
Pixel 58 = Yellow
Pixel 59 = Red
```

### 12.3 Snake Movement

The snake shall move toward Pixel 0.

The snake shall move by one pixel per movement event.

The snake movement interval shall be:

```text
250 ms
```

The nominal snake movement rate shall therefore be:

```text
4 positions per second
```

The snake shall not move while the system is in the idle, win, or lose state.

---

## 13. Bullet Behavior

### 13.1 Bullet Generation

A valid button event shall generate a bullet with the color assigned to that button.

Only one bullet shall be active at a time.

If a button event occurs while a bullet is already active, the new event shall be ignored.

### 13.2 Bullet Initial Position

A newly generated bullet shall start at:

```text
Pixel 0
```

### 13.3 Bullet Movement

* The bullet shall move toward Pixel 59.

* The bullet shall move by one pixel per movement event.

* The bullet movement interval shall be:

```text
50 ms
```

The nominal bullet movement rate shall therefore be:

```text
20 positions per second
```

The bullet shall move five times faster than the snake.

### 13.4 Bullet Lifetime

* A bullet shall remain active until it collides with the snake head.

* Upon collision, the bullet shall become inactive.

### 13.5 Collision Target

* The bullet shall interact only with the snake head.

* Collision with non-head snake segments shall not trigger a collision event.

---

## 14. Collision Requirements

A collision shall occur when the active bullet position equals the snake head position:

```text
bullet_position == snake_head_position
```

Collision processing shall compare the bullet color with the snake head color.

### 14.1 Matching Color

If:

```text
bullet_color == snake_head_color
```

the system shall:

1. Remove the snake head segment.
2. Decrease the snake length by one.
3. Remove the bullet.
4. Evaluate the win condition.

### 14.2 Non-Matching Color

If:

```text
bullet_color != snake_head_color
```

the system shall:

1. Attach the bullet to the snake.
2. Convert the bullet into a new snake head.
3. Increase the snake length by one.
4. Remove the bullet from the active-bullet state.

The non-matching-color behavior is a functional gameplay requirement.

---

## 15. Game States

The system shall support the following externally observable game states:

```text
IDLE
PLAYING
WIN
LOSE
```

The reset operation shall initialize the system and place it in the `IDLE` state.

The internal RTL state encoding is an implementation detail.

### 15.1 Idle State

In the idle state:

- The initial snake shall be displayed.
- The snake shall remain stationary.
- No bullet shall be active.
- The first valid button event shall transition the system to the playing state.

### 15.2 Playing State

In the playing state:

- The snake shall move according to the snake movement interval.
- An active bullet shall move according to the bullet movement interval.
- Collision processing shall be enabled.
- Win and lose conditions shall be evaluated.

### 15.3 Win State

In the win state:

- Snake movement shall stop.
- Bullet movement shall stop.
- New bullet events shall be ignored.
- The entire LED strip shall blink green.

### 15.4 Lose State

In the lose state:

- Snake movement shall stop.
- Bullet movement shall stop.
- New bullet events shall be ignored.
- The entire LED strip shall blink red.

---

## 16. Win Condition

The system shall enter the win state when:

```text
Snake length == 0
```

When the win condition is reached, the entire LED strip shall display solid green.

The win indication shall alternate between:

- All pixels GREEN for 500 ms.
- All pixels OFF for 500 ms.

The sequence shall repeat continuously until the system is reset.

The system shall remain in the win state until reset unless a different restart behavior is explicitly added to this specification.

---

## 17. Lose Condition

The system shall enter the lose state when the snake head reaches Pixel 0:

```text
snake_head_position == 0
```

When the lose condition is reached, the entire LED strip shall display solid red.

The lose indication shall alternate between:

- All pixels RED for 500 ms.
- All pixels OFF for 500 ms.

The sequence shall repeat continuously until the system is reset.

The system shall remain in the lose state until reset unless a different restart behavior is explicitly added to this specification.

---

## 18. Game Timing Requirements

All game timing shall be derived from the 50 MHz master clock.

The system shall provide a 50 ms game-update interval.

At 50 MHz:

```text
50 ms / 20 ns = 2,500,000 clock cycles
```

Therefore, the 50 ms game interval shall correspond to:

```text
2,500,000 master-clock cycles
```

The bullet shall update once every 50 ms.

The snake shall update once every five 50 ms intervals:

```text
5 × 50 ms = 250 ms
```

The game timing shall not rely on an independently generated low-frequency clock.

The implementation shall use synchronous timing derived from the 50 MHz clock.

---

## 19. LED Refresh Requirements

The LED output shall be refreshed continuously while the system is operating.

A complete frame shall contain:

```text
60 pixels × 24 bits = 1,440 bits
```

At a nominal data rate of 800 Kbps, the payload transmission time shall be approximately:

```text
1,440 / 800,000 = 1.8 ms
```

After transmitting a complete frame, the data output shall remain LOW for at least:

```text
280 µs
```

This LOW interval shall provide the WS2812B reset/latch time before the next frame is transmitted.

The LED output shall continue to reflect the current game state, including idle, playing, win, and lose behavior.

---

## 20. Timing and Synthesis Requirements

The design shall satisfy the following requirements:

1. All synchronous logic shall meet timing closure at 50 MHz.
2. The primary clock period shall be 20 ns.
3. WS2812B pulse timing shall be generated deterministically from the 50 MHz clock.
4. Game timing shall be derived from the 50 MHz clock.
5. The design shall not depend on an unnecessary independent low-frequency clock.
6. The RTL shall be synthesizable for the Cyclone II EP2C35F672C6 FPGA.
7. The design shall not exceed the electrical limitations of the DE2 GPIO interface.
8. The LED strip shall be powered from an external 5 V supply.

---


## 21. Reference Documentation

### 21.1 [WS2812B-2020.PDF](./WS2812B-2020.PDF)

This document is the authoritative reference for the WS2812B protocol,
timing, electrical characteristics, and communication sequence.

### 21.2 [DE2 Manual](./DE2%20-%20manual.pdf)

This document is the primary reference for the DE2 board architecture,
board-level hardware characteristics, and user I/O behavior.

### 21.3 [DE2 Pin Assignments](./DE_2_pin_assignments.csv)

This document is the authoritative reference for FPGA physical pin
assignments used by this project.

If a hardware-specific requirement differs between the project
specification and the corresponding hardware documentation, the relevant
hardware documentation shall take precedence, and this specification
shall be updated accordingly.

---

## 22. Open Requirements

The following hardware-dependent item shall be confirmed before final
hardware deployment:

1. Confirm whether a 3.3 V-to-5 V level shifter is required for the selected WS2812B LED strip.

This open requirement does not block RTL implementation.

---

## 23. Specification Change Control

This document defines the functional baseline for the FPGA Snake project.

Any change to externally observable behavior, hardware interfaces, or
mandatory timing requirements shall require an update to this specification.

Changes limited to internal RTL structure or implementation details shall be
documented in [ARCHITECTURE.md](./ARCHITECTURE.md) instead.
