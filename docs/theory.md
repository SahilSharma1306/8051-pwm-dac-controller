# Theoretical Background

This document covers the core concepts behind the PWM-based DAC controller, providing the theoretical foundation for each subsystem.

---

## 1. Pulse Width Modulation (PWM)

### Principle

Pulse Width Modulation encodes information in the **duty cycle** of a digital signal. The average voltage of a PWM signal is directly proportional to its duty cycle:

```
V_avg = V_high × (T_on / T_period)
```

Where:
- `V_high` is the logic HIGH voltage
- `T_on` is the duration the signal stays HIGH
- `T_period` is the total period of one cycle

### Software PWM on the 8051

The 8051 lacks a dedicated PWM peripheral, so we implement PWM in software using **Timer 0 interrupts**:

1. Timer 0 is configured in **Mode 2** (8-bit auto-reload) to generate periodic interrupts every **100 µs**
2. A software counter (`R1`) counts from 0 to 99, creating a **10 ms PWM period** (100 Hz)
3. On each interrupt, the counter is compared against a threshold (`R0`):
   - If `counter < threshold` → output HIGH (+2V)
   - If `counter ≥ threshold` → output LOW (-2V)

### Timing Derivation

| Parameter | Value | Calculation |
|---|---|---|
| Crystal Frequency | 24 MHz | Given |
| Machine Cycle | 0.5 µs | 12 ÷ 24 MHz |
| Timer Reload Value | 56 | Chosen |
| Counts per Overflow | 200 | 256 − 56 |
| Interrupt Period | 100 µs | 200 × 0.5 µs |
| Ticks per PWM Cycle | 100 | Software counter |
| **PWM Period** | **10 ms** | 100 × 100 µs |
| **PWM Frequency** | **100 Hz** | 1 ÷ 10 ms |

### Duty Cycle Resolution

With 100 ticks per cycle, the duty cycle resolution is **1%**. The threshold value `R0` directly maps to the duty cycle percentage:

| R0 Value | Duty Cycle | Average Output |
|---|---|---|
| 0 | 0% | −2V (constant) |
| 25 | 25% | −1V |
| 50 | 50% | 0V |
| 75 | 75% | +1V |
| 100 | 100% | +2V (constant) |

---

## 2. Digital-to-Analog Conversion (DAC)

### Overview

The 8-bit DAC (such as the DAC0808) converts the digital code on Port 2 into an equivalent analog voltage. The relationship between the digital input and analog output depends on the reference voltage and circuit configuration.

### Bipolar Output Configuration

In this project, the DAC is configured for **bipolar operation** (±2V range):

| DAC Code (Decimal) | DAC Code (Hex) | Output Voltage |
|---|---|---|
| 230 | 0xE6 | +2V |
| 128 | 0x80 | 0V (midpoint) |
| 26 | 0x1A | −2V |

The bipolar output is typically achieved using an operational amplifier (op-amp) in a **summing amplifier** configuration that offsets and scales the unipolar DAC output.

### Transfer Function

For a bipolar DAC with reference voltage `V_ref`:

```
V_out = V_ref × [(D / 256) − 0.5] × Gain
```

Where `D` is the 8-bit digital code (0–255).

---

## 3. Serial Communication (UART)

### 8051 UART Architecture

The 8051's built-in UART operates in **Mode 1**: 10-bit asynchronous communication with 1 start bit, 8 data bits, and 1 stop bit.

### Baud Rate Generation

Timer 1 in **Mode 2** (8-bit auto-reload) serves as the baud rate generator:

```
Baud Rate = (2^SMOD / 32) × (F_osc / 12) / (256 − TH1)
```

| Parameter | Value |
|---|---|
| F_osc | 24 MHz |
| SMOD | 1 (doubled rate) |
| TH1 | 243 |
| 256 − TH1 | 13 |
| **Baud Rate** | **(2/32) × 2 MHz / 13 ≈ 9615 baud** |

The ~0.16% error from the ideal 9600 baud is well within the ±3% tolerance of standard UART receivers.

### Data Flow

1. A PC or terminal sends a single byte (0–100) via a serial connection
2. The 8051 detects the reception by polling the **RI** (Receive Interrupt) flag
3. The received byte is read from the **SBUF** register
4. The value is stored in `R0`, immediately updating the PWM duty cycle
5. The RI flag is cleared, and the system waits for the next byte

---

## 4. Interrupt-Driven Architecture

### Why Interrupts?

Without interrupts, the CPU would need to manually check the timer overflow flag in a loop ("polling"), wasting CPU cycles and making it impossible to perform other tasks simultaneously. Interrupts allow:

- **Deterministic timing**: The PWM ISR executes at precise 100 µs intervals
- **Concurrent operation**: The main loop handles serial communication while PWM runs in the background
- **Low latency**: Timer overflow immediately triggers the ISR (within 1 machine cycle)

### Interrupt Priority & Nesting

| Interrupt Source | Vector Address | Priority |
|---|---|---|
| External INT0 | 0003h | Highest |
| **Timer 0** | **000Bh** | **Used (PWM)** |
| External INT1 | 0013h | — |
| Timer 1 | 001Bh | — |
| Serial Port | 0023h | Lowest |

In this project, only Timer 0 interrupt is enabled (`IE = 82h`), so no priority conflicts occur. The serial port is handled via polling in the main loop rather than its interrupt, simplifying the design.

### ISR Execution Time Budget

The ISR must complete within the interrupt period (100 µs = 200 machine cycles):

| Instruction | Cycles |
|---|---|
| `INC R1` | 1 |
| `CJNE R1, #100, pwm_check` | 2 |
| `MOV A, R1` | 1 |
| `CLR C` | 1 |
| `SUBB A, R0` | 1 |
| `JC pwm_high` | 2 |
| `MOV P2, #data` | 2 |
| `RETI` | 2 |
| **Total (worst case)** | **~12 cycles = 6 µs** |

The ISR uses only **3% of the available CPU time**, leaving 97% for the main loop's serial polling.

---

## 5. References

1. Mazidi, M. A., Mazidi, J. G., & McKinlay, R. D. — *The 8051 Microcontroller and Embedded Systems* (2nd Edition, Pearson)
2. Atmel Corporation — *AT89S52 Datasheet* (Rev. 1919D–MICRO–6/08)
3. National Semiconductor — *DAC0808 8-Bit D/A Converter Datasheet*
4. Horowitz, P. & Hill, W. — *The Art of Electronics* (3rd Edition, Cambridge University Press)
