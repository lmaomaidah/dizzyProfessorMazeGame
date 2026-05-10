# Dizzy Walk — x86 Assembly Maze Simulation
**Course:** Computer Organization & Assembly Language — FAST-NUCES, Spring 2026

A maze simulation written entirely in x86 assembly language (MASM) using the Irvine32 
library. The program simulates a dizzy professor navigating home through a 100×150 2D 
grid, with real-time visual output, obstacle handling, and persistent file logging.

## Features
- Dual movement modes: random (auto) and keyboard-controlled (WASD/arrow keys)
- Obstacles: walls, buildings, lakes, and stumbles (may drop the key)
- Pits: instant termination with reason displayed
- Coin collection added to the professor's wallet
- Key-based destination outcome: enters home (key present) or sleeps outside (key lost)
- Console-based visual simulation: start, intermediate, and final maze states
- File I/O: logs path taken, treasures collected, and their locations per session

## Project Structure
- dizzy_walk_main.asm ;main program logic
- dizzy_walk_macros.inc ;all macros functions
- dizzy_walk_structs.inc ;structure declaration
- dizzy_walk_ui.inc ;ui declarations

## Requirements
- MASM assembler
- Irvine32 library (by Kip Irvine)
- Windows (32-bit console environment)

## How to Run
1. Set up MASM with the Irvine32 library linked
2. Assemble and link the `.asm` file(s)
3. Run the executable — choose random or keyboard mode at prompt

## Assumptions
- Listed inline in source code comments where applicable
- Starting position defaults to maze center

## Notes
All values are symbol-defined — no hard-coded magic numbers.
Code is fully commented following standard procedure documentation conventions.
