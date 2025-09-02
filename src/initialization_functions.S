@Description:
@ This file contains low-level initialization routines and constant definitions
@ for setting up the system clock, GPIO button interrupts, index variables,
@ and NVIC interrupt priorities. These functions are invoked during system
@ startup to configure the hardware environment of the Micro:bit.
@ Usage:
@   This module should be called once at the beginning of the main control loop.
@   Constants in this file are used throughout the project to address hardware
@   registers related to GPIO events and interrupt control (GPIOTE + NVIC).
.syntax unified
.global setup_clk, setup_btns,setup_index,set_priorities
@ GPIO and NVIC Register Addresses
.set GPIOTE_EVENTS_IN0, 0x40006100       @ Event register for GPIOTE channel 0 (P0.14 / Button A)
.set GPIOTE_INTENSET, 0x40006304         @ GPIOTE interrupt enable set register
.set GPIOTE_CONFIG0, 0x40006510          @ GPIOTE channel 0 config register
.set GPIOTE_EVENTS_IN1, 0x40006104       @ channel 1 event register
.set GPIOTE_CONFIG1, 0x40006514          @ channel 1 config register
.set NVIC_ISER0, 0xE000E100              @ NVIC interrupt set-enable register
@ Priority Register Addresses
.set SHPR3, 0xE000ED20                   @ System Handler Priority Register 3 (for SysTick)
.set NVIC_IPR1, 0xE000E404               @ NVIC Interrupt Priority Register 1 (for GPIOTE)


@ Function: setup_clk
@ Purpose: Configures system timer (SysTick) for periodic interrupts
@ Notes:
@   - Sets the reload value for the timer to control refresh speed
@   - Enables SysTick with processor clock source and interrupt
.type setup_clk, %function
setup_clk:
@ Set SYST_RVR = 0x800000 (~8M cycles). Controls image switching speed.
    ldr r0, =ADR_SYST_RVR     
    ldr r1, =0x800000
    str r1, [r0]
@ Set SYST_CSR = ENABLE | TICKINT | CLKSOURCE (0b111)
    ldr r0, =ADR_SYST_CSR     
    mov r1, 0b111
    str r1, [r0]
    bx lr


@ Function: setup_btns
@ Purpose: Configures GPIO interrupts for buttons A and B
@ Notes:
@   - Uses GPIOTE channels 0 and 1 to detect events on P0.14 and P0.23
@   - Enables interrupts for IN0 and IN1, and registers GPIOTE interrupt with NVIC
.type setup_btns, %function
setup_btns: 
@ Configure GPIOTE_CONFIG[0] to detect P0.14 (Button A)
    ldr r0, =GPIOTE_CONFIG0             
    ldr r1, =(1 | 14 << 8 | 0 << 13 | 1 << 16)
    str r1, [r0]
@ Configure GPIOTE_CONFIG[1] to detect P0.23 (Button B)
    ldr r0, =GPIOTE_CONFIG1            
    ldr r1, =(1 | 23 << 8 | 0 << 13 | 1 << 16)
    str r1, [r0]
@ Enable interrupts for both IN0 and IN1
    ldr r0, =GPIOTE_INTENSET              
    ldr r1, =0b11                    
    str r1, [r0]
@ Enable GPIOTE interrupt in NVIC (IRQ number 6)
    ldr r0, =NVIC_ISER0              
    ldr r1, =(1 << 6)
    str r1, [r0]
    bx lr 


@ Function: setup_index
@ Purpose: Initializes global variables before entering main loop
.type setup_index, %function
setup_index:
@ Initializes image_index = 0
    ldr r1, =image_index
    mov r0, #0
    str r0, [r1]
@ Initializes is_drawing = 0
    ldr r1, =is_drawing
    mov r0, #0
    str r0, [r1]
    bx lr


@ Function: set_priorities
@ Purpose: Configures interrupt priorities for SysTick and GPIOTE
@ Notes:
@   - Lower number = higher priority
@   - GPIOTE gets higher priority than SysTick
.type set_priorities, %function
set_priorities:
@ Set SysTick priority to 6 (binary 110) → SHPR3 bits 29–31
    ldr r0, =SHPR3
    ldr r1, [r0]
    bic r1, r1, #(0b111 << 29)
    orr r1, r1, #(6 << 29)
    str r1, [r0]
@ Set GPIOTE priority to 2 (binary 010) → NVIC_IPR1 bits 21–23
    ldr r0, =NVIC_IPR1
    ldr r1, [r0]
    bic r1, r1, #(0b111 << 21)
    orr r1, r1, #(2 << 21)
    str r1, [r0]
    bx lr   