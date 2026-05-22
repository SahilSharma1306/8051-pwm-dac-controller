;===============================================================================
;
;   PWM-Based DAC Controller with Serial Communication Interface
;   Target MCU  : 8051 Architecture (AT89S52 / AT89C51)
;   Crystal     : 24 MHz
;   Baud Rate   : 9600 (SMOD = 1)
;   PWM Freq    : 100 Hz (10 ms period)
;   DAC         : 8-bit (Port 2), Bipolar Output ±2V
;
;   Port Selection:
;       Port 2 is used for the DAC data bus. Port 0 cannot be used because
;       it lacks internal pull-up resistors (open-drain outputs) and would
;       require external pull-ups to drive the DAC reliably. Port 3 cannot
;       be used because it is a multi-function port — P3.0 (RXD) and P3.1
;       (TXD) are reserved for UART serial communication in this design.
;
;   Description:
;       This firmware implements a variable duty-cycle PWM generator using
;       Timer 0 interrupts. The PWM waveform drives an 8-bit DAC connected
;       to Port 2, producing a bipolar analog output that alternates between
;       +2V (DAC code 230) and -2V (DAC code 26) based on the duty cycle.
;
;       The duty cycle can be dynamically adjusted at runtime via the serial
;       port (UART), enabling real-time control from a PC or terminal. This
;       demonstrates interrupt-driven multitasking, hardware timer management,
;       and peripheral interfacing on the 8051.
;
;   Register Allocation:
;       R0  -  Duty cycle threshold (0-100), set via serial receive
;       R1  -  PWM tick counter (0-99), incremented each Timer 0 interrupt
;
;   Calculations:
;       Machine Cycle   = 12 / 24 MHz = 0.5 µs
;       Timer 0 Period  = (256 - 56) × 0.5 µs = 100 µs per interrupt
;       PWM Period      = 100 interrupts × 100 µs = 10 ms → 100 Hz
;       Baud Rate       = (2^SMOD / 32) × (Fosc/12) / (256 - TH1)
;                       = (2/32) × 2 MHz / 13 ≈ 9615 baud (~9600)
;
;   Author  : Sahil
;   License : MIT
;
;===============================================================================


;-----------------------------------------------
;  RESET & INTERRUPT VECTOR TABLE
;-----------------------------------------------

        org     0000h
        ljmp    main                    ; Reset vector → jump to main program

        org     000Bh                   ; Timer 0 overflow interrupt vector
                                        ; (address 0x000B, interrupt #1)


;===============================================================================
;  TIMER 0 ISR — PWM WAVEFORM GENERATOR
;===============================================================================
;
;  Called every 100 µs (Timer 0 overflow). Maintains a software counter (R1)
;  that counts from 0 to 99, creating a 10 ms PWM period. When the counter
;  is below the duty cycle threshold (R0), the DAC outputs +2V; otherwise,
;  it outputs -2V. Every 100th tick, a +2V "sync pulse" is emitted.
;
;  Duty Cycle = (R0 / 100) × 100%
;  Example: R0 = 75 → 75% duty cycle → output is +2V for 7.5 ms, -2V for 2.5 ms
;
;-----------------------------------------------

timer0_isr:
        inc     r1                      ; Increment PWM tick counter
        cjne    r1, #100, pwm_check     ; If counter < 100, evaluate PWM state
        mov     r1, #00h                ; Reset counter at 100 (start new cycle)
        mov     P2, #230d               ; Sync pulse: output +2V via DAC

pwm_check:
        mov     a, r1                   ; A = current tick count
        clr     c                       ; Clear carry for subtraction
        subb    a, r0                   ; A = tick_count - duty_threshold
        jc      pwm_high                ; If tick < threshold (carry set) → HIGH
        mov     P2, #26d                ; Else → output -2V (LOW portion of PWM)
        sjmp    exit_isr

pwm_high:
        mov     P2, #230d               ; Output +2V (HIGH portion of PWM)

exit_isr:
        reti                            ; Return from interrupt


;===============================================================================
;  MAIN PROGRAM — SYSTEM INITIALIZATION & SERIAL RECEIVE LOOP
;===============================================================================

main:
;-----------------------------------------------
;  Combined Timer & Peripheral Configuration
;-----------------------------------------------
        mov     tmod, #22h              ; TMOD: Timer 1 = Mode 2 (auto-reload)
                                        ;        Timer 0 = Mode 2 (auto-reload)
                                        ; Both timers in 8-bit auto-reload mode

        orl     pcon, #80h              ; Set SMOD = 1 in PCON register
                                        ; Doubles the baud rate for Timer 1

        mov     ie, #82h                ; IE register: EA = 1 (global enable)
                                        ;              ET0 = 1 (Timer 0 interrupt)
                                        ; Binary: 1000 0010

        mov     scon, #50h              ; SCON: Mode 1 (8-bit UART, variable baud)
                                        ;        REN = 1 (receiver enabled)
                                        ; Binary: 0101 0000

;-----------------------------------------------
;  Timer 0 Setup — PWM Timebase (100 µs period)
;-----------------------------------------------
        mov     tl0, #56                ; Current count value
        mov     th0, #56                ; Auto-reload value
                                        ; Overflow every (256 - 56) = 200 cycles
                                        ; Period = 200 × 0.5 µs = 100 µs

        mov     r0, #25d                ; Default duty cycle = 25%
        mov     r1, #01h                ; Initialize tick counter
        mov     P2, #230d               ; Initialize DAC output to +2V
        setb    tr0                     ; Start Timer 0

;-----------------------------------------------
;  Timer 1 Setup — Baud Rate Generator (9600)
;-----------------------------------------------
        mov     tl1, #243               ; Current count value
        mov     th1, #243               ; Auto-reload value = 243
                                        ; Baud = (2/32) × (24M/12) / (256-243)
                                        ;       = 9615 ≈ 9600 baud
        setb    tr1                     ; Start Timer 1

;-----------------------------------------------
;  Serial Receive Loop — Dynamic Duty Cycle Control
;-----------------------------------------------
;  Continuously polls the RI flag. When a byte is received via UART,
;  it is loaded directly into R0, updating the PWM duty cycle in
;  real time. Valid range: 0-100 (values > 100 produce >100% duty).
;
receive_loop:
        jnb     scon.0, receive_loop    ; Poll RI flag (SCON bit 0)
                                        ; Spin until a byte is received

        clr     scon.0                  ; Clear RI flag for next reception
        mov     r0, sbuf                ; Load received byte → duty cycle (R0)
                                        ; Immediately affects PWM output

        sjmp    receive_loop            ; Loop forever, waiting for next byte

;===============================================================================

        end
