; ============================================================
; File    : dizzy_walk_structs.inc
; Purpose : All constants, cell types, and struct definitions
;           for the Dizzy Walk project.
; ============================================================

; ------------------------------------------------------------
; Maze dimensions
; ------------------------------------------------------------
MAZE_ROWS       EQU  100
MAZE_COLS       EQU  150
MAZE_SIZE       EQU  MAZE_ROWS * MAZE_COLS   ; 15000 bytes total

; Starting position (center of maze)
START_ROW       EQU  MAZE_ROWS / 2           ; 50
START_COL       EQU  MAZE_COLS / 2           ; 75

; Destination position (top-right quadrant)
DEST_ROW        EQU  10
DEST_COL        EQU  130

; ------------------------------------------------------------
; Cell type constants (stored in maze array)
; ------------------------------------------------------------
CELL_EMPTY      EQU  0
CELL_WALL       EQU  1
CELL_BUILDING   EQU  2
CELL_LAKE       EQU  3
CELL_PIT        EQU  4
CELL_COIN       EQU  5
CELL_DEST       EQU  6
CELL_GEM        EQU  8     ; gem treasure — worth 5 coins
GEM_VALUE       EQU  5     ; coins added when gem collected

; ------------------------------------------------------------
; Display characters (ASCII)
; ------------------------------------------------------------
CHAR_GEM        EQU  '*'

; ------------------------------------------------------------
; Irvine32 console colors
; ------------------------------------------------------------
COLOR_EMPTY     EQU  07h    ; white on black
COLOR_BUILDING  EQU  06h    ; brown/yellow
COLOR_COIN      EQU  0Eh    ; bright yellow
COLOR_DEST      EQU  0Ah    ; bright green
COLOR_PROF      EQU  0Bh    ; bright cyan
COLOR_GEM       EQU  0Dh    ; bright magenta

; ------------------------------------------------------------
; Game limits
; ------------------------------------------------------------
MAX_STEPS       EQU  10000  ; max steps before forced termination
FIXED_STEP_LIM  EQU  1000   ; step limit for "Fixed Steps" mode
MAX_TREASURES   EQU  100    ; max items in treasure log
NAME_LEN        EQU  32     ; professor name buffer size

; ------------------------------------------------------------
; Movement mode flags
; ------------------------------------------------------------
MODE_RANDOM     EQU  0
MODE_KEYBOARD   EQU  1

; ------------------------------------------------------------
; Boolean / status constants
; ------------------------------------------------------------
TRUE            EQU  1
FALSE           EQU  0
KEY_PRESENT     EQU  1
KEY_LOST        EQU  0

; ------------------------------------------------------------
; Keyboard scan codes (Irvine ReadKey returns these in AH)
; ------------------------------------------------------------
KEY_UP          EQU  48h    ; arrow up
KEY_DOWN        EQU  50h    ; arrow down
KEY_LEFT        EQU  4Bh    ; arrow left
KEY_RIGHT       EQU  4Dh    ; arrow right
KEY_ESC         EQU  1Bh    ; escape = quit

; ------------------------------------------------------------
; Stumble probability  (1 in N chance of dropping key)
; ------------------------------------------------------------
STUMBLE_CHANCE  EQU  100

; ------------------------------------------------------------
; PROFESSOR structure
; ------------------------------------------------------------
PROFESSOR STRUCT
    profName    BYTE  NAME_LEN DUP(0)  ; professor's name
    posRow      DWORD 0                ; current row (0-based)
    posCol      DWORD 0                ; current col (0-based)
    prevRow     DWORD 0                ; previous row (for redraw)
    prevCol     DWORD 0                ; previous col (for redraw)
    wallet      DWORD 0                ; coins collected
    hasKey      BYTE  KEY_PRESENT      ; 1=has key, 0=lost
    stepCount   DWORD 0                ; total steps taken
    moveMode    BYTE  MODE_RANDOM      ; 0=random, 1=keyboard
PROFESSOR ENDS

; ------------------------------------------------------------
; TREASURE_ENTRY structure (one per item picked up)
; ------------------------------------------------------------
TREASURE_ENTRY STRUCT
    itemType    BYTE  0    ; cell type of item collected
    itemRow     DWORD 0    ; row where item was found
    itemCol     DWORD 0    ; col where item was found
TREASURE_ENTRY ENDS

; ------------------------------------------------------------
; PATH_ENTRY structure (one per step taken)
; ------------------------------------------------------------
PATH_ENTRY STRUCT
    stepRow     DWORD 0
    stepCol     DWORD 0
PATH_ENTRY ENDS

; Visual simulation constants — Phase 5
VIEWPORT_ROWS   EQU  22        ; rows visible on screen
VIEWPORT_COLS   EQU  39        ; cols visible on screen
CELL_WIDTH      EQU  2
VP_ROW_MAX      EQU  78        ; = MAZE_ROWS(100) - VIEWPORT_ROWS(22)
VP_COL_MAX      EQU  111       ; = MAZE_COLS(150) - VIEWPORT_COLS(39)

; ------------------------------------------------------------
; Object quantities — change these to adjust coin/pit counts
; ------------------------------------------------------------
COIN_COUNT      EQU  300    ; coins scattered across maze
PIT_COUNT       EQU  100    ; pits scattered across maze
GEM_COUNT       EQU  100    ; gems scattered across maze