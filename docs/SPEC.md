# FPGA Snake — System Specification

| Attribute | Specification |
| :--- | :--- |
| **Status** | Specification Baseline |
| **Target Platform** | Terasic DE10-Standard |
| **HDL** | SystemVerilog |
| **System Clock** | 50 MHz (20 ns period) |
| **LED Display** | 60-pixel WS2812B-compatible LED strip |

---

## 1. Purpose and Scope

FPGA Snake is a one-dimensional color-matching game implemented on an FPGA and displayed using a 60-pixel WS2812B-compatible LED strip.

### 1.1 In-Scope Capabilities
The system shall:
* Display and move a multi-color snake.
* Accept four color-selection buttons.
* Generate and move a colored bullet.
* Detect bullet-to-snake collisions.
* Update the snake according to the bullet color.
* Detect win and lose conditions.
* Display the game state on the LED strip.

### 1.2 Out-of-Scope Capabilities
The following features are outside the current scope:
* Score tracking
* Multiple levels
* Sound effects
* UART communication
* Seven-segment display output
* Additional gameplay modes

> **Note:** This document defines externally observable system behavior and mandatory interface requirements. Internal RTL organization and implementation decisions are defined separately in `ARCHITECTURE.md`.

---

## 2. External Interfaces

The system shall provide the following external interfaces:

* **Clock:**
  * 50 MHz master clock
  * 20 ns clock period
* **Player Inputs:**
  * Four pushbutton inputs corresponding to: `Red`, `Green`, `Blue`, `Yellow`
  * One valid button press shall generate at most one firing event
* **Reset:**
  * One active reset input
  * When reset is asserted, the system shall return to its initial game state
* **LED Output:**
  * One WS2812B-compatible serial data output controlling:
    * 60 RGB pixels
    * 24 bits per pixel
    * GRB color order
    * MSB-first transmission

---

## 3. Game Layout

The LED strip shall be treated as a one-dimensional array:

```text
Pixel 0 -------------------------------------------------------- Pixel 59
[Player side]                                                  [Far side]
                                <================ [Snake moves left]
      [Bullet moves right] ================>
```

* The **snake** shall move toward decreasing pixel indices ($\to$ Pixel 0).
* The **bullet** shall move toward increasing pixel indices ($\to$ Pixel 59).

### Initial Snake Configuration
* **Length:** 5 segments
* **Position:** Occupies Pixels 55 through 59
* **Head:** Pixel 55

| Pixel Index | Segment Role | Initial Color |
| :---: | :---: | :---: |
| **55** | Snake Head | Red |
| **56** | Body | Green |
| **57** | Body | Blue |
| **58** | Body | Yellow |
| **59** | Snake Tail | Red |

---

## 4. Game Behavior

### 4.1 Idle State
* After reset:
  * The initial snake shall be displayed.
  * The snake shall remain stationary.
  * No bullet shall be active.
* The first valid color-button event shall begin gameplay.

### 4.2 Snake Movement
* During gameplay:
  * The snake shall move toward Pixel 0.
  * Each movement event shall shift the snake by one pixel, except when a matching-color collision occurs in the same clock cycle (see Section 4.5).
  * The snake movement interval shall be **250 ms**.

### 4.3 Bullet Generation
* A valid color-button event shall create a bullet of the corresponding color.
* Only one bullet shall be active at a time.
* If a new button event occurs while a bullet is active, the new event shall be ignored.
* A new bullet shall begin at **Pixel 0**.

### 4.4 Bullet Movement
* An active bullet shall:
  * Move toward Pixel 59.
  * Advance by one pixel per movement event.
  * Advance once every **50 ms**.

### 4.5 Collision Mechanics
A collision shall occur when an active bullet's proposed position reaches or passes the snake head's proposed position after applying any movement events for the current clock cycle:
$$\text{proposed\_bullet\_position} >= \text{proposed\_snake\_head\_position}$$

* **Match (`bullet_color == snake_head_color`):**
  * The snake head shall be removed.
  * The snake length shall decrease by one.
  * The bullet shall become inactive.
  * If a snake movement event occurs in the same clock cycle, the hit shall take priority: the current head shall be removed, and the remaining snake segments shall stay at their existing pixel positions. The movement event shall not be deferred to a later cycle.
* **Mismatch (`bullet_color != snake_head_color`):**
  * The bullet shall disappear.
  * The bullet shall become inactive.
  * The snake length shall not change.
  * If a snake movement event occurs in the same clock cycle, the snake shall still move toward Pixel 0 by one pixel.

---

## 5. Win and Lose Conditions

### 5.1 Win Condition
The system shall enter the **WIN** condition when:
$$\text{snake\_length} == 0$$

During WIN:
* Game movement shall stop.
* New firing events shall be ignored.
* The entire LED strip shall turn **Green**.
* The WIN condition shall remain active until reset.

### 5.2 Lose Condition
The system shall enter the **LOSE** condition when:
$$\text{snake\_head\_position} == 0$$

During LOSE:
* Game movement shall stop.
* New firing events shall be ignored.
* The entire LED strip shall turn **Red**.
* The LOSE condition shall remain active until reset.

---

## 6. LED Protocol Requirements

The system shall generate a WS2812B-compatible serial waveform with the following specifications:

| Parameter | Value / Requirement |
| :--- | :--- |
| **Nominal Data Rate** | 800 kbit/s |
| **Pixel Depth** | 24 bits per pixel |
| **Byte Order** | GRB (Green, Red, Blue) |
| **Bit Order** | MSB-first transmission |
| **Frame Size** | 60 pixels ($60 \times 24 = 1440\text{ bits}$) |

* The logical `0`, logical `1`, and reset/latch waveforms shall comply with the timing requirements of the WS2812B device used in the project.
* The data line shall remain `LOW` for at least the required reset/latch interval after a complete frame.
* Exact electrical and waveform limits shall be taken from the selected WS2812B datasheet.

---

## 7. System Requirements

The completed design shall satisfy the following requirements:

1. **Clocking:** The system shall operate from the 50 MHz master clock.
2. **Timing Closure:** All synchronous logic shall meet timing requirements at 50 MHz.
3. **Functional Accuracy:** Game behavior shall match the requirements defined in this specification.
4. **Signal Integrity:** The WS2812B output waveform shall satisfy the selected LED device requirements.
5. **Display Completeness:** The design shall control all 60 LEDs correctly.
6. **Electrical Safety:** The external LED power and data interface shall remain within the electrical limits of the DE10-Standard and the selected LED strip.

> **Implementation Note:** Board-specific pin assignments, I/O standards, electrical integration details, RTL module structure, synchronization methods, debounce implementation, internal state representation, counters, and clock-enable generation are implementation details and shall be documented outside this specification.
