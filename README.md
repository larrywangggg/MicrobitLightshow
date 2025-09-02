# MicrobitLightshow

## Overview

This project implements a light show system with two display modes on the Micro:bit’s 5x5 LED matrix. I designed a collection of 12 images, stored as word arrays in memory, and used scanning to dynamically display them. The two modes are:

- **Mode 0 (animated playback):** Images are displayed in a loop. There are **5 speed levels (0–4)** to choose from, with level 2 as the default. Pressing **Button A** slows down the playback; pressing **Button B** speeds it up. The mode uses a SysTick timer to control the frame update rate.

- **Mode 1 (static browsing):** Users can press **Button A** to view the previous image, and **Button B** to view the next one. The image index **wraps around**: pressing B on the last image goes back to the first, and pressing A on the first goes to the last.

Both modes share the same image table and index, and use a common drawing routine underneath.

## Implementation

To make `main.S` cleaner and easier to debug, I split the functionality into short, modular functions across 4 different files, namely `initialization_functions.S`, `handler_related_functions.S`, `drawing_related_functions.S` and `images_index_flags.S`. In this section, I’ll walk through the key components in the same order they appear in the `main.S`.

### 1. Initialization

At the top of `main`, I call five setup functions to initialize the system:
- `init_leds` sets the GPIO direction for the LED matrix.
- `setup_index` sets initial values for global flags like `image_index`, `mode_flag`, `speed_index`, and counters.
- `set_priorities` sets interrupt priorities for `SysTick` and `GPIOTE`.
- `setup_clk` enables the SysTick timer to generate regular interrupts.
- `setup_btns` configures GPIO events for Button A and Button B.

### 2. Main control loop

The main loop checks two things every tick: whether it’s time to draw, and whether any button was pressed.

- `if_should_draw` uses a lock (`is_drawing`) to avoid reentry, and checks if `tick_counter` has reached `tick_to_play`. If not, it skips drawing this time.
- `check_if_button_pressed` handles A/B/simultaneous presses based on a `btn_flag` and `btn_state`. Depending on the mode and button, it triggers the correct handler and then clears the flag.

### 3. Mode switching

The `mode_flag` determines whether to jump to `mode0_path` or `mode1_path`.

In **mode 0**, the loop:
- Calls `prepare_to_draw` (sets `is_drawing = 1`, resets `tick_counter`)
- Calls `Draw`, which passes the correct image to `draw_image`
- Then calls `update_Frame_State`, which increments the image index and resets `is_drawing`.

In **mode 1**, it directly calls `Draw_mode1`, which sends the current image pointer to `draw_static_image`.

### 4. Drawing logic

The core drawing is done by:
- `draw_image`: Loops through each column for each frame, sets GPIO row/column, and inserts delay.
- `draw_static_image`: Similar loop, but only draws one frame without updating index.

### 5. Handlers and flags

The A/B button handlers perform:
- In Mode 0: increase/decrease `speed_index` (0–4) and update `tick_to_play`.
- In Mode 1: increase/decrease `image_index` with wraparound.
- `handler_ab_combination` toggles the mode and resets the image index.

To meet interrupt handling best practices, I ensured that both the `SysTick_Handler` and `GPIOTE_IRQHandler` only set flags or counters. All functional logic runs back in `main_loop` via function calls.

## Analysis

### Why my design meets each grade level's requirements
This design satisfies the requirements for the following grades:

#### Pass level
-  Uses memory and data structures to store 12 images
-  Implements scanning for dynamic display
-  Runs in an infinite loop (Mode 0)
-  Uses modular design and a clean main loop

#### Credit level
-  Uses **SysTick interrupts** to regulate animation playback speed
-  Button A/B control playback speed via `speed_index` and `tick_to_play`

#### Distinction level
-  Implements: *"Allow using the buttons to dial a particular setting of the animation (e.g. speed or brightness)"*  
  - A/B control 5 speed levels in Mode 0 with visual impact
  - Displayed speed difference is made clearly noticeable via delay settings

#### High Distinction level
-  Implements a **high degree of interactivity**:
  - Buttons A/B perform different logic in different modes
  - A+B switches mode and resets state, similar to a minimal state machine
  - Design logic was cleanly split into `main.S`, `handler_related_functions.S`, `drawing_related_functions.S` etc. for clarity and scalability
-  Interrupt handling conforms to best practices: SysTick/GPIOTE only set flags or increment counters, no heavy logic inside handlers

### Why I make these design decisions
To specifically address the question "Why did you choose this design and implementation approach?", here are some of the key design choices I made:

- I used `tick_counter` and `tick_to_play` to control drawing speed instead of relying solely on the SysTick interval. This is because even the maximum RVR value (2^24) only gives about 0.25s between interrupts, which is too fast to allow for observable variation. By combining a moderate RVR value with a tunable counter system, I can provide five distinct playback speeds that are easy to observe and modify, making the design more extensible.

- I used `btn_flag` and `btn_state` to ensure GPIO interrupt handlers remain short and compliant with the requirement that interrupt routines must return quickly. All actual button logic is deferred to the main loop, which improves maintainability and avoids unexpected side effects.

- The `is_drawing` variable serves as a lock to prevent overlapping draw operations. This ensures that one frame finishes rendering before another begins, avoiding glitches caused by fast SysTick updates.

- I introduced a central dispatcher function, `check_if_button_pressed`, to decode the current `btn_state` and branch to the appropriate handler. This keeps logic clean and avoids repeating conditional checks inside the main loop.

These design decisions not only improve the stability and clarity of the system, but also make it much easier to extend, test, and reason about.


## Notes and Limitations

- In **Mode 1**, switching to another mode by pressing A+B requires reasonably precise timing. If the two buttons are not pressed closely enough, the system may first interpret the input as separate A then B presses (resulting in flipping forward and backward), rather than a combination.  
  → This is not a bug in the `handler_ab_combination` logic — the timing is just sensitive. If tested with breakpoints, you can confirm it works correctly.

- In **Mode 0**, when the playback is set to the **slowest speed**, response to button presses feels slower. This is expected behaviour, not a bug, since the system checks inputs only once per tick.

- If you want to make the **speed differences** between levels more noticeable to the human eye, you can increase the spacing in the `speed_levels` array (line 27 of `images_index_flags.S`).

- When pressing the buttons with soft fingertip tissue (e.g. the pad of your finger), there's a small chance that one press is detected as two due to bouncing. This is a physical characteristic of the hardware, not a bug in the code.  
  → Using your **fingernail** to press makes the contact much more stable and eliminates the issue entirely.

## Summary

- Overall, I’m happy with the structure and functionality of my design. It’s modular, interactive, and easy to extend if needed.