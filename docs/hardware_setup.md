# Hardware Setup Guide

This document details the hardware components and connections required to build the PWM-based DAC controller.

---

## Components Required

| Component | Specification | Quantity | Purpose |
|---|---|---|---|
| 8051 MCU | AT89S52 / AT89C51 | 1 | Main controller |
| Crystal Oscillator | 24 MHz | 1 | Clock source |
| Load Capacitors | 33 pF | 2 | Crystal stabilization |
| DAC | DAC0808 / DAC0800 | 1 | Digital-to-analog conversion |
| Op-Amp | LM741 / TL071 | 1 | Bipolar output stage |
| MAX232 / CP2102 | RS-232 / USB-TTL | 1 | Serial level conversion |
| Resistors | Various | As needed | Biasing and reference |
| Capacitors | 10 µF, 0.1 µF | As needed | Decoupling |
| Power Supply | +5V DC regulated | 1 | System power |
| Breadboard / PCB | — | 1 | Prototyping |

---

## Pin Connections

### 8051 Microcontroller

| MCU Pin | Function | Connected To |
|---|---|---|
| P2.0 – P2.7 | DAC Data Bus | DAC0808 inputs (D0–D7) |
| P3.0 (RXD) | Serial Receive | MAX232 / CP2102 TX |
| P3.1 (TXD) | Serial Transmit | MAX232 / CP2102 RX |
| XTAL1, XTAL2 | Oscillator | 24 MHz crystal + 33 pF caps |
| RST | Reset | 10 µF + 8.2 kΩ RC reset circuit |
| VCC | Power | +5V |
| GND | Ground | Common ground |
| EA/VPP | External Access | Tied to VCC (internal ROM) |

### DAC0808 Connections

| DAC Pin | Function | Connected To |
|---|---|---|
| A1–A8 | Digital Inputs | P2.0–P2.7 (8051 Port 2) |
| VREF(+) | +Reference | +5V through precision resistor |
| VREF(−) | −Reference | GND |
| IOUT | Current Output | Op-amp virtual ground |
| VCC | Positive Supply | +5V (or +12V) |
| VEE | Negative Supply | −12V (for bipolar output) |
| COMP | Compensation | 0.1 µF to ground |

### Serial Interface (MAX232)

| MAX232 Pin | Connected To |
|---|---|
| T1IN | P3.1 (TXD) of 8051 |
| R1OUT | P3.0 (RXD) of 8051 |
| T1OUT | DB-9 Pin 3 (or USB-TTL TX) |
| R1IN | DB-9 Pin 2 (or USB-TTL RX) |

---

## Circuit Description

### Clock Circuit
The 24 MHz crystal oscillator is connected between XTAL1 and XTAL2 pins with 33 pF load capacitors to ground, providing the system clock.

### Reset Circuit
A standard RC power-on reset circuit (10 µF capacitor + 8.2 kΩ resistor) ensures a clean reset on power-up. The capacitor charges through the resistor, keeping RST HIGH for approximately 2 time constants (~164 ms).

### DAC Output Stage
The DAC0808 outputs a current proportional to the digital input. An operational amplifier converts this current to a voltage:

```
    DAC0808 IOUT ──────┬──── R_fb ────┐
                       │              │
                       └──── (−) Op-Amp ──── V_out
                              (+)
                               │
                            V_offset (for bipolar output)
```

For bipolar (±2V) output:
- A summing resistor network at the op-amp's inverting input provides the DC offset
- The feedback resistor (`R_fb`) sets the gain
- Output swings between +2V (DAC = 230) and −2V (DAC = 26)

### Serial Communication
The MAX232 IC converts TTL-level signals (0/5V) from the 8051 to RS-232 levels (±12V) for connection to a PC serial port. Alternatively, a CP2102 USB-to-TTL module can be used for direct USB connectivity.

---

## Power Supply Requirements

| Rail | Voltage | Current (typ.) | Purpose |
|---|---|---|---|
| VCC | +5V | ~100 mA | MCU, logic |
| V+ | +12V | ~20 mA | Op-amp, DAC positive supply |
| V− | −12V | ~20 mA | Op-amp, DAC negative supply |

> **Note**: If using a single +5V supply, the DAC output will be unipolar (0V to ~5V). Bipolar operation requires dual supply rails for the op-amp and DAC.

---

## Simulation

This project can be simulated using:

- **Proteus (ISIS)** — Full schematic simulation with 8051 and virtual instruments
- **Keil µVision** — For assembling and debugging the firmware
- **EdSim51** — Browser-based 8051 simulator for code verification

### Simulation Steps

1. Assemble the source code using Keil µVision to generate a `.hex` file
2. Load the `.hex` file onto the AT89S52 model in Proteus
3. Connect a **Virtual Terminal** to the serial port for sending duty cycle values
4. Connect a **Virtual Oscilloscope** to Port 2 to observe the PWM waveform
5. Vary the serial input to observe real-time duty cycle changes
