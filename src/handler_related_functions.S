@Description:
@This file contains all interrupt handler functions and button event logic for the Micro:bit image system. 
@It manages timer-driven updates, GPIO event handling, mode switching, and input-triggered changes to playback speed and image index.
@ Usage:
@   These functions are called by the main loop and SysTick/GPIOTE interrupts.
@   They handle button presses, update playback speed, and manage image display modes.
.syntax unified
.global SysTick_Handler,GPIOTE_IRQHandler, handler_btn_a, handler_btn_b, update_tick_to_play, handler_ab_combination
@ GPIO event register addresses
.set GPIOTE_EVENTS_IN0, 0x40006100
.set GPIOTE_EVENTS_IN1, 0x40006104



@ Function: SysTick_Handler
@ Purpose: Increments the global tick counter every SysTick interrupt
.type SysTick_Handler, %function
SysTick_Handler:
    ldr r0, =tick_counter
    ldr r1, [r0]
    add r1, r1, #1
    str r1, [r0]
    bx lr



@ Function: GPIOTE_IRQHandler
@ Purpose: Handles button interrupts on IN0 and IN1, sets flag for main loop to detect
@ Notes:
@   - Sets bit0 of btn_state if button A (IN0) pressed
@   - Sets bit1 of btn_state if button B (IN1) pressed
@   - Sets btn_flag to 1 to signal main loop to check button state
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
    push {lr}
@ Check if Button A (IN0) triggered
    ldr r0, =GPIOTE_EVENTS_IN0
    ldr r1, [r0]
    cmp r1, #0
    beq check_b
@ Clear event register and set btn_state bit0
    mov r1, #0
    str r1, [r0]
    ldr r0, =btn_state
    ldr r1, [r0]
    orr r1, r1, #0b01        @ set bit0: button A pressed
    str r1, [r0]
check_b:
@ Check if Button B (IN1) triggered
    ldr r0, =GPIOTE_EVENTS_IN1
    ldr r1, [r0]
    cmp r1, #0
    beq done
@ Clear event register and set btn_state bit1
    mov r1, #0
    str r1, [r0]
    ldr r0, =btn_state
    ldr r1, [r0]
    orr r1, r1, #0b10        @ set bit1: button B pressed
    str r1, [r0]
done:
@ Signal main loop that a button was pressed
    ldr r0, =btn_flag
    mov r1, #1
    str r1, [r0]
    pop {lr}
    bx lr



@ Function: handler_btn_a
@ Purpose: Handles logic for Button A (P0.14)
@          - In mode0: increases speed_index (slower playback)
@          - In mode1: moves to the previous image (circular index)
@ Notes:   
@       - speed_index = 0 is fastest  &  speed_index = 4 is slowest
@       - image_index wraps from 0 → 11 in mode1
.type handler_btn_a, %function
handler_btn_a:
    push {lr}
@ Check current mode
    ldr r0, =mode_flag
    ldr r1, [r0]
    cmp r1, #0
    beq if_mode0_a
    cmp r1, #1
    beq if_mode1_a
@ Mode 0 : Increase speed_index if less than 4
if_mode0_a:
    ldr r0, =speed_index
    ldr r1, [r0]
    cmp r1, #4
    it lt
    addlt r1, r1, #1
    str r1, [r0]
    bl update_tick_to_play
    b end_handler_btn_a
@ Mode 1 : Decrease image_index if greater than 0, and wrap to end(11) if at start(0)
if_mode1_a:
    ldr r0, =image_index
    ldr r1, [r0]
    cmp r1, #0
    beq wrap_to_end
    sub r1, r1, #1
    str r1, [r0]             @ Increase image_index if less than 12
    b end_handler_btn_a
    wrap_to_end:
        mov r1, #11          @ Wrap to end(11) if at the start(0)
        str r1, [r0]
end_handler_btn_a:
    pop {lr}
    bx lr



@ Function: handler_btn_b
@ Purpose: Handles Button B (P0.23) logic 
@          - In mode0: decreases speed_index (faster playback)
@          - In mode1: moves to the next image (circular index)
@ Notes:
@    - speed_index: 0 (fastest), 4 (slowest)
@    - image_index wraps from 11 → 0 in mode1
.type handler_btn_b, %function
handler_btn_b:
    push {lr}
@ Check current mode
    ldr r0, =mode_flag
    ldr r1, [r0]
    cmp r1, #0
    beq if_mode0_b
    cmp r1, #1
    beq if_mode1_b
@ Mode 0 : Decrease speed_index if greater than 0
if_mode0_b:   
    ldr r0, =speed_index
    ldr r1, [r0]
    cmp r1, #0
    it gt
    subgt r1, r1, #1
    str r1, [r0]
    bl update_tick_to_play
    b end_handler_btn_b
@ Mode 1 : Increase image_index if less than 11,and wrap to start(0) if at the end(11)
if_mode1_b:
    ldr r0, =image_index
    ldr r1, [r0]
    cmp r1, #11
    beq wrap_to_start
    add r1, r1, #1
    str r1, [r0]             @ Increase image_index if less than 12
    b end_handler_btn_b
    wrap_to_start:
        mov r1, #0             @ Wrap to start(0) if at the end(11)
        str r1, [r0]
end_handler_btn_b:
    pop {lr}
    bx lr
 


@ Function: update_tick_to_play
@ Purpose: Updates tick_to_play value according to speed_index and speed_levels table
@ Notes:
@   - tick_to_play = speed_levels[speed_index]
.type update_tick_to_play, %function
update_tick_to_play:
    push {lr}
    ldr r0, =speed_index
    ldr r1, [r0]                 @ r1 = speed_index
    ldr r0, =speed_levels
    ldr r2, [r0, r1, LSL #2]     @ r2 = speed_levels[r1]
    ldr r0, =tick_to_play
    str r2, [r0]
    pop {lr}
    bx lr



@ Function: handler_ab_combination
@ Purpose: Toggles between display modes (currently switches mode_flag between 0 and 1)
@ Notes:
@   - Current implementation: 0 → 1, 1 → 0
@   - May need extension for toggle through more than two modes
.type handler_ab_combination, %function
handler_ab_combination:
    push {lr}
    ldr r0, =mode_flag
    ldr r1, [r0]
    eor r1, r1, #1         @ Flip bit: 0->1, 1->0
    str r1, [r0]
    ldr r0, =image_index
    ldr r1, [r0]
    mov r1, #0         
    str r1, [r0]         @ Set image_index to 0
    pop {lr}
    bx lr