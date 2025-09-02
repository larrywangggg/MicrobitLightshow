@ Description:
@ This file contains the program entry point (`main`) and defines the main
@ control loop logic for the Micro:bit image system.
@ It coordinates system initialization, input handling, mode switching,
@ and conditional drawing based on system state and timer ticks.
@ Initialization steps include:
@     - init_leds:        Enable GPIO for LED matrix
@     - setup_index:      Set default values for flags, counters, and pointers
@     - set_priorities:   Configure SysTick and GPIOTE interrupt priorities
@     - setup_clk:        Enable and configure SysTick for timing control
@     - setup_btns:       Enable GPIO event detection for buttons A and B
@ The main loop (`main_loop`) executes indefinitely:
@     - Checks if drawing is allowed (via `if_should_draw`)
@     - Checks button input and handles accordingly
@     - Determines current mode (mode0: animation, mode1: static images)
@     - Executes appropriate drawing function (`Draw` or `Draw_mode1`)
@     - Loops back to await next tick or input
.syntax unified
.global main


.type main, %function
main:
@ Initialize system components
    bl init_leds          
    bl setup_index       @ Set initial values for flags and counters
    bl set_priorities    @ Set interrupt priorities for SysTick and GPIOTE
    bl setup_clk         @ Enable SysTick timer for periodic interrupts
    bl setup_btns        @ Configure GPIO for button events
main_loop:
@Check if it's time to draw
    bl if_should_draw
    cmp r0, #0
    beq end_this_loop
@Check for button press events
    bl check_if_button_pressed  
@Check current display mode and jump to appropriate path
    ldr r0, =mode_flag            
    ldr r0, [r0]                  
    cmp r0, #1              
    beq mode1_path                   @If mode_flag == 1, branch to mode1
mode0_path:
    bl prepare_to_draw               @ Prepare drawing parameters
    bl Draw                          @ Draw image for mode 0
    bl update_Frame_State            @ Update frame or state variables
    b end_this_loop
mode1_path:
    bl Draw_mode1                    @ Draw image for mode 1

end_this_loop:
    b main_loop 