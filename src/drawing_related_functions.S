@Description:
@This file contains low-level image rendering functions used in the LED matrix display system of the Micro:bit project. 
@It supports both animated (multi-frame) and static (single-frame) image drawing, as well as related helper functions for frame updates and draw control logic.
@ Usage:
@   These functions are shared across the main loop and button handler logic.
@   They manage both Mode 0 (auto animation) and Mode 1 (manual image switching).
.syntax unified
.global draw_image, Draw, update_Frame_State,if_should_draw,prepare_to_draw, check_if_button_pressed @for mode0 and mode1
.global Draw_mode1, draw_static_image @for mode1


    
@ Function: draw_image
@ Purpose: Displays a multi-frame animated image on the LED matrix by iterating through columns and frames with delay.
@ Input: r0 = pointer to the image (passed from Draw,%function)
@ Procedure:
@   - Outer loop draws each frame (r7 = frame index)
@   - Inner loop draws 5 columns for that frame (r4 = col index)
@   - Uses r6 as base image pointer
@   - Uses r5 = 1 << col to control the active column pin
@   - Adds delay per column to allow visibility
@ Notes:
@   - Assumes each image frame consists of 5 columns (5x5 LED)
@   - Multiple frames allow simple animation
@   - Final call clears row pins
.type draw_image, %function    
draw_image:
    push {r4, r5, r6, r7, lr}
    mov r6, r0          @ r6 ← image pointer (base address)
    mov r7, #0          @ r7 = frame index (starts from 0)
frame_loop:
    cmp r7, #40      @ 40 frames max per image (for animation)
    beq end_draw_frame
    mov r4, #0          @ col index = 0

    loop_cols:
        cmp r4, #5
        beq next_frame               @ 5 columns per frame, go to next frame

        mov r0, #0 
        bl write_row_pins_natural    @ Clear row pins before each col, to avoid ghosting lights
        mov r5, #1          
        lsl r5, r4                   @ r5 = 1 << r4
        mov r0, r5
        bl write_column_pins         
        ldr r0, [r6, r4, LSL #2]     @ r0 = image[col] = one column's row bits
        bl write_row_pins_natural    @turn on lights
        ldr r0, =0x4000
        bl delay                     @ Delay to allow visibility of the column
        add r4, r4, #1               @ col++
    b loop_cols
    
    next_frame:
        add r7, r7, #1               @ frame++
    b frame_loop

end_draw_frame:
    mov r0, #0
    bl write_row_pins_natural  @ Clear all row pins after drawing all frames, to avoid ghosting lights
    pop {r4, r5, r6, r7, lr}
    bx lr



@ Function: Draw
@ Purpose: 
@    Retrieves the image address from image_table using image_index, and invokes draw_image to display the current image.
@ Used in: mode0 autoplay loop (to display the current image frame)
@ Shared vars: image_table, image_index
.type Draw , %function
Draw:
    push {lr}
    ldr r0, =image_table
    ldr r1, =image_index
    ldr r2, [r1]
    ldr r3, [r0, r2, LSL #2]
    mov r0, r3  @ r0 = image_table[image_index], get image address
    bl draw_image
    pop {lr}
    bx lr



@ Function: update_Frame_State
@ Purpose:
@   Advances the image_index by 1 after each frame is drawn (mode0), wrapping back to 0 if it exceeds the total number of images.
@   Also sets is_drawing = 0 to signal that the current frame has finished.
@ Details:
@   - image_index++ (up to 12 images, wraps to 0 after index 11)
@   - is_drawing = 0 allows next frame to be drawn again
@ Used after: draw() completes a single image display cycle
@ Shared vars: image_index, is_drawing
.type update_Frame_State, %function
update_Frame_State:
    ldr r1, =image_index
    ldr r2, [r1]       @ r2 = current image_index
    add r2, r2, #1     @ image_index++
    cmp r2, #12
    it ge
    movge r2, #0        @current image_index if >= 12, wrap to 0
    str r2, [r1]
    ldr r0, =is_drawing
    mov r1, #0
    str r1, [r0]        @set is_drawing = 0
    bx lr



@ Function: if_should_draw
@ Purpose: Determines whether the system is currently allowed to draw a new frame.
@          It checks:
@           1. if a drawing is already in progress (via is_drawing flag)
@           2. if enough time has passed based on tick_counter and tick_to_play
@ Returns: r0 = 1 if allowed to draw;  r0 = 0 if drawing is blocked
@ Used in: main.S main_loop to decide whether to proceed with Draw()
@ Shared Variables:
@   - is_drawing, tick_counter, tick_to_play
@ Notes: This acts as a lock to avoid double drawing due to fast SysTick updates
.type if_should_draw, %function
if_should_draw:
@ Check if is_drawing == 1 (drawing in progress), if so, return 0 (not allowed to draw)
    ldr r0, =is_drawing
    ldr r1, [r0]
    cmp r1, #1
    beq set_false 
@ Compare tick_counter and tick_to_play
    ldr r0, =tick_counter
    ldr r1, [r0]
    ldr r2, =tick_to_play
    ldr r3, [r2]
    cmp r1, r3 
    blt set_false  @tick_counter < tick_to_play, return r0 = 0 (not allowed to draw)
    mov r0, #1     @else, return r0 = 1 (allowed to draw)    
    b end_check
set_false:
    mov r0, #0         
end_check:
    bx lr



@ Function: prepare_to_draw
@ Purpose: Prepares the system for a new frame drawing by:
@     1. Setting the is_drawing flag to 1 (lock drawing)
@     2. Resetting tick_counter to 0 (restart draw delay timer)
@ Used in:
@   - main_loop before Draw() is called, ensures draw operation cannot be triggered too frequently
.type prepare_to_draw, %function
prepare_to_draw:
    ldr r0, =is_drawing
    mov r1, #1
    str r1, [r0]           @ Set is_drawing to 1 to lock drawing operation
    ldr r0, =tick_counter
    mov r1, #0
    str r1, [r0]           @ Reset tick_counter to 0
    bx lr



@ Function: check_if_button_pressed
@ Purpose:
@   Checks for any button input (A, B, or A+B) and dispatches to the corresponding button handler function. 
@   This function acts as the central hub for input processing.
@ Workflow:
@   1. Checks `btn_flag` to confirm there's a new button input.
@   2. Clears `btn_flag` and reads `btn_state` (bitwise status of A/B).
@   3. If both buttons (A+B) pressed → call handler_ab_combination
@   4. If only A is pressed → call handler_btn_a
@   5. If only B is pressed → call handler_btn_b
@   6. Clears `btn_state` after handling
@ Inputs:
@   - btn_flag: whether a new button input was detected (1 = new input)
@   - btn_state: button status: bit0=A, bit1=B
@ Output:
@   - Calls corresponding handler and resets btn_state
@ Used by:
@   - main_loop (called once per iteration if frame drawing is allowed)
.type check_if_button_pressed, %function
check_if_button_pressed:
    push {lr}
@ Check if btn_flag is set (indicating a new button input)
    ldr r0, =btn_flag
    ldr r1, [r0]
    cmp r1, #1
    bne end_check_button_pressed @ No new input → return early
@ Clear btn_flag
    mov r1, #0
    str r1, [r0]
@ Read btn_state to determine button status
    ldr r0, =btn_state
    ldr r1, [r0]
@ Check which buttons are pressed using bitwise comparison
    cmp r1, #0b11
    beq both_pressed @ Branch if both buttons pressed (A+B)
    cmp r1, #0b01
    beq only_a       @ Branch if only button A pressed
    cmp r1, #0b10
    beq only_b       @ Branch if only button B pressed
    b clear_btn      @ If no buttons pressed, just clear btn_state and return
only_a:
    bl handler_btn_a   @ Call handler for button A
    b clear_btn
only_b:
    bl handler_btn_b   @ Call handler for button B
    b clear_btn
both_pressed:
    bl handler_ab_combination    @ Call handler for A+B combination
    b clear_btn
clear_btn:
    ldr r0, =btn_state
    mov r1, #0
    str r1, [r0]                  @ Clear btn_state after handling
end_check_button_pressed:
    pop {lr}
    bx lr
   


@ Function: Draw_mode1
@ Purpose: Draws a static image based on the current image_index in mode 1
@ Notes:
@   - Loads image pointer from image_table using image_index
@   - Calls draw_static_image to display a single static frame
.type Draw_mode1, %function
Draw_mode1:
    push {lr}
    ldr r0, =image_table
    ldr r1, =image_index
    ldr r2, [r1]
    ldr r3, [r0, r2, LSL #2]
    mov r0, r3
    bl draw_static_image             
    pop {lr}
    bx lr



@ Function: draw_static_image
@ Purpose: Displays a 5x5 static image by setting column and row pins
@ Notes:
@   - Does not loop or change frames, used for displaying one image only
.type draw_static_image, %function
draw_static_image:
    push {r4, r5, r6, lr}
    mov r6, r0        @ r6 ← image pointer
    mov r4, #0        @ col = 0
@ Clear row pins before drawing static image, to avoid ghosting lights
    mov r0, #0 
    bl write_row_pins_natural  
loop_cols_static:
    cmp r4, #5                 @ 5 columns per static image        
    beq end_static_image

    mov r0, #0
    bl write_row_pins_natural  @ Clear row pins before each column, to avoid ghosting lights
    mov r5, #1
    lsl r5, r4                 @ r5 = 1 << col
    mov r0, r5
    bl write_column_pins
    ldr r0, [r6, r4, LSL #2]   @ r0 = image[col] = one column's row bits
    bl write_row_pins_natural  @ Turn on lights for this column
    ldr r0, =0x4000
    bl delay                   @ Delay to allow visibility of the column
    add r4, r4, #1             @ col++
    b loop_cols_static
end_static_image:
    pop {r4, r5, r6, lr}
    bx lr