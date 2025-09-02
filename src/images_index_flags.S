@Description:
@This file defines all global flags, state variables, and image data used throughout the Micro:bit image system.
@These variables are shared between drawing routines, button handlers, and the main control loop to coordinate mode switching, drawing speed, and image rendering.
.syntax unified
.global smile_face,sad_face,peaceful_face,left_arrow,right_arrow,up_arrow,down_arrow,hourglass,heart,Win,Lose,Bolt @images
.global image_table,image_index  @image_table and image_index
.global tick_counter,speed_levels,tick_to_play, speed_index @indexes and counters
.global btn_flag,btn_state,mode_flag,is_drawing   @flags and states


.data
mode_flag:      
    .word 0      @ Current playback mode: 0 = autoplay (mode0), 1 = manual browse (mode1)
btn_state:
    .word 0      @ Button press state: bit0 = A pressed, bit1 = B pressed (0b01 = A, 0b10 = B, 0b11 = both)      
btn_flag:       
    .word 0      @ btn_flag: 0 = no new input, 1 = new input detected
speed_index:
    .word 2      @ Index into speed_levels[]: 0 = fastest, 4 = slowest
tick_counter:
    .word 0      @ Counts SysTick ticks, resets after reaching tick_to_play
tick_to_play:   
    .word 10     @ Trigger redraw when tick_counter = tick_to_play
is_drawing:
    .word 0      @ Indicates whether the system is currently drawing (used to block updates)
speed_levels: 
    .word 1, 5, 10, 14, 20    @ Delay multipliers, corresponding to speed_index (used by update_tick_to_play)
image_index:
    .word 0      @ Current image ID being shown (0–11)
image_table:
    .word smile_face,sad_face,peaceful_face,right_arrow,left_arrow,up_arrow,down_arrow,hourglass,heart,Win,Lose,Bolt  @ List of image addresses
    
smile_face: 
    .word 0b00010 @ Column 1
    .word 0b01001 @ Column 2
    .word 0b00001 @ Column 3
    .word 0b01001 @ Column 4
    .word 0b00010 @ Column 5

sad_face:  
    .word 0b00001
    .word 0b01010
    .word 0b00010
    .word 0b01010
    .word 0b00001

peaceful_face: 
    .word 0b00000
    .word 0b01001
    .word 0b00001
    .word 0b01001
    .word 0b00000

right_arrow: 
    .word 0b00100
    .word 0b00100
    .word 0b00100
    .word 0b01110
    .word 0b00100

left_arrow: 
    .word 0b00100
    .word 0b01110
    .word 0b00100
    .word 0b00100
    .word 0b00100

up_arrow: 
    .word 0b00000
    .word 0b01000
    .word 0b11111
    .word 0b01000
    .word 0b00000

down_arrow: 
    .word 0b00000
    .word 0b00010
    .word 0b11111
    .word 0b00010
    .word 0b00000

hourglass: 
    .word 0b10001
    .word 0b11011
    .word 0b11111
    .word 0b11011
    .word 0b10001

heart: 
    .word 0b01100
    .word 0b11110
    .word 0b01111
    .word 0b11110
    .word 0b01100

Win: 
    .word 0b01110
    .word 0b00001
    .word 0b01110
    .word 0b00001
    .word 0b01110

Lose: 
    .word 0b00000
    .word 0b11111
    .word 0b00001
    .word 0b00001
    .word 0b00000

Bolt: 
    .word 0b00000
    .word 0b00101
    .word 0b01110
    .word 0b10100
    .word 0b00000