; ============================================================
; File    : dizzy_walk_main.asm
; Author  : Daud, Maidah, Hani | Roll: i240045, i242116, i242113
; Course  : Cyber Security - COAL Spring 2026, FAST NU
; Purpose : Dizzy Walk -- main entry point.
;           Phase 1: Data structures, maze initialization,
;           and console verification of all structures.
; ============================================================

INCLUDE Irvine32.inc
includelib kernel32.lib
includelib user32.lib
includelib gdi32.lib
INCLUDE dizzy_walk_structs.inc
INCLUDE dizzy_walk_macros.inc
INCLUDE dizzy_walk_ui.inc

; ── Windows Beep API ─────────────────────────────────────────
Beep PROTO STDCALL dwFreq:DWORD, dwDuration:DWORD

; Sound frequency constants
SND_COIN        EQU  1200
SND_GEM         EQU  900
SND_KEY_DROP    EQU  250
SND_PIT         EQU  120
SND_SUCCESS     EQU  1600
SND_MENU        EQU  800
SND_DUR_SHORT   EQU  80
SND_DUR_MED     EQU  200
SND_DUR_LONG    EQU  500

; ============================================================
; .DATA -- all initialized variables
; ============================================================
.data

    ; ----------------------------------------------------------
    ; Maze storage -- flat byte array, row-major order
    ; Access cell (r,c) as: maze[r * MAZE_COLS + c]
    ; ----------------------------------------------------------
    maze            BYTE MAZE_SIZE DUP(CELL_EMPTY)

    ; ----------------------------------------------------------
    ; Professor instance
    ; ----------------------------------------------------------
    prof            PROFESSOR <>

    ; ----------------------------------------------------------
    ; Path log -- stores (row, col) for every step taken
    ; Each PATH_ENTRY is 8 bytes (two DWORDs)
    ; ----------------------------------------------------------
    pathLog         PATH_ENTRY MAX_STEPS DUP(<>)
    pathCount       DWORD 0

    ; ----------------------------------------------------------
    ; Treasure log -- stores item + position for each pickup
    ; Each TREASURE_ENTRY is 9 bytes
    ; ----------------------------------------------------------
    treasureLog     TREASURE_ENTRY MAX_TREASURES DUP(<>)
    treasureCount   DWORD 0

    ; ----------------------------------------------------------
    ; UI / message strings
    ; ----------------------------------------------------------
    msgTitle        BYTE "=== DIZZY WALK ===", 0Dh, 0Ah, 0
    msgEnterName    BYTE "Enter professor name: ", 0
    msgPressKey     BYTE 0Dh, 0Ah, "Press any key to continue...", 0

    ; Input buffer for professor name
    nameBuffer      BYTE NAME_LEN DUP(0)

    ; ----------------------------------------------------------
    ; Phase 3 -- game state flag and message strings
    ; ----------------------------------------------------------
    gameOver        BYTE  FALSE

    msgPitFall      BYTE  "Fell into a pit!", 0Dh, 0Ah, 0
    msgDestKey      BYTE  "SUCCESS: Professor reached home with the key!", 0Dh, 0Ah, 0
    msgDestNoKey    BYTE  "FAIL: Reached home but lost the key. Sleeping outside...", 0Dh, 0Ah, 0
    msgMaxSteps     BYTE  "GAME OVER: Maximum steps reached. Professor is lost.", 0Dh, 0Ah, 0
    msgKeyDropped   BYTE  "Oops! Key Lost!", 0Dh, 0Ah, 0
    msgCoinFound    BYTE  "Coin collected! Wallet = ", 0
    msgEscQuit      BYTE  "Player quit (ESC).", 0Dh, 0Ah, 0

    ; ----------------------------------------------------------
    ; Phase 4 -- file handling
    ; ----------------------------------------------------------
    fileHandle      DWORD 0
    fileName        BYTE  "adventure_log.txt", 0

    ; File write buffer -- build strings here before writing
    fileBuf         BYTE  256 DUP(0)

    ; Labels written to file
    fHdr            BYTE  "=== DIZZY WALK ADVENTURE LOG ===", 0Dh, 0Ah, 0
    fName           BYTE  "Professor : ", 0
    fSteps          BYTE  "Steps     : ", 0
    fCoins          BYTE  "Coins     : ", 0
    fKey            BYTE  "Key       : ", 0
    fResult         BYTE  "Result    : ", 0
    fHasKey         BYTE  "Entered home successfully.", 0Dh, 0Ah, 0
    fNoKey          BYTE  "Slept outside -- key was lost.", 0Dh, 0Ah, 0
    fPit            BYTE  "Fell into a pit.", 0Dh, 0Ah, 0
    fMaxSteps       BYTE  "Lost -- max steps reached.", 0Dh, 0Ah, 0
    fQuit           BYTE  "Player quit early.", 0Dh, 0Ah, 0
    fDivider        BYTE  "-----------------------------------", 0Dh, 0Ah, 0
    fNewline        BYTE  0Dh, 0Ah, 0

    ; Tracks which ending happened (set alongside gameOver)
    ; 0=pit  1=destKey  2=destNoKey  3=maxSteps  4=quit
    endReason       BYTE  0

    ; ----------------------------------------------------------
    ; Phase 5 -- visual simulation strings (side panel versions)
    ; ----------------------------------------------------------
    ; These are kept for compatibility but actual drawing is
    ; done by the new DrawSidePanel procedure.

    ; Game over screen messages
    msgVisGameOver  BYTE "GAME OVER", 0
    msgVisSuccess   BYTE "SUCCESS! ", 0
    
    ; Viewport offset trackers (top-left corner of viewport in maze coords)
    vpRow           DWORD 0    ; which maze row is at top of screen
    vpCol           DWORD 0    ; which maze col is at left of screen

    screenR         DWORD 0    ; current screen row in DrawMaze loop
    screenC         DWORD 0    ; current screen col in DrawMaze loop

    ; PlaceMazeObjects mode-aware temporaries
objRow          DWORD 0    ; temp row for object placement
objCol          DWORD 0    ; temp col for object placement
objLen          DWORD 0    ; temp length for walls
objH            DWORD 0    ; temp height for buildings
objW            DWORD 0    ; temp width for buildings



    ; ----------------------------------------------------------
    ; Phase 7 -- additional file output strings
    ; ----------------------------------------------------------
    fTreasHeader    BYTE  "Treasures :", 0Dh, 0Ah, 0
    fTreasItem      BYTE  "  Coin at Row=", 0
    fTreasComma     BYTE  " Col=", 0
    fTreasNone      BYTE  "  None collected.", 0Dh, 0Ah, 0
    fFinalPos       BYTE  "Final Pos : Row=", 0
    fFinalPosCol    BYTE  " Col=", 0
    fFinalPosEnd    BYTE  0Dh, 0Ah, 0
    fKeyLost        BYTE  "Key Lost  : Yes", 0Dh, 0Ah, 0
    fKeyKept        BYTE  "Key Lost  : No", 0Dh, 0Ah, 0

    msgGemFound     BYTE  "Gem found! +5 coins! Wallet = ", 0
    fTreasGem       BYTE  "Gem  at Row=", 0
    msgTreasGem     BYTE  "GEM ", 0

    ; ----------------------------------------------------------
    ; Side panel strings (new for enhanced UI)
    ; ----------------------------------------------------------
    panelTitle      BYTE  "DIZZY WALK", 0    ; panel header text
    panelProfLbl    BYTE  "Prof:", 0
    panelPosLbl     BYTE  "Pos :", 0
    panelStepLbl    BYTE  "Step:", 0
    panelCoinLbl    BYTE  "Coin:", 0
    panelKeyLbl     BYTE  "Key :", 0
    panelModeLbl    BYTE  "Mode:", 0
    panelKeyYes     BYTE  0F8h, " YES", 0       ; ° YES
    panelKeyNo      BYTE  "X NO ", 0
    panelModeRnd    BYTE  "RANDOM", 0
    panelModeKbd    BYTE  "KEYBD ", 0
    panelScoreLbl   BYTE  "Scr :", 0
    panelLgndHdr    BYTE  "CHARACTERS", 0
    panelEvHdr      BYTE  "  EVENTS  ", 0
    panelRowSep     BYTE  0C3h, 0              ; ├ (start of separator)
    panelComma      BYTE  ",", 0
    ; Legend text lines (each 17 chars max so it fits the 20-wide panel)
    lgnd1           BYTE  0DBh, " Wall    BLOCK", 0    ; █ Wall
    lgnd2           BYTE  0B2h, " Building BLK", 0    ; ▓ Building
    lgnd3           BYTE  0F7h, " Lake    BLOCK", 0    ; ≈ Lake
    lgnd4           BYTE  0D7h, " Pit     FATAL", 0    ; × Pit
    lgnd5           BYTE  0F8h, " Coin    +1   ", 0    ; ° Coin
    lgnd6           BYTE  04h,  " Gem     +5   ", 0    ; ♦ Gem
    lgnd7           BYTE  0CEh, " Home    GOAL ", 0    ; ╬ Home

    ; Event log circular buffer
    ; EVLOG_MAX=10 lines, EVLOG_BUF_LEN=18 chars each (+ null)
    evLog           BYTE  EVLOG_MAX * (EVLOG_BUF_LEN + 1) DUP(0)
    evLogCount      DWORD 0     ; how many events written so far
    evLogHead       DWORD 0     ; index of oldest event (circular)

    ; Small number-to-string scratch buffer for panel values
    numScratch      BYTE  12 DUP(0)

    ; ── Welcome screen strings ──────────────────────────────
    ; Title banner
    wBanner1        BYTE  " ________  ___  ________  ________     ", 0
    wBanner2        BYTE  "|\\   ___ \\|\\  \\|\\___   ___\\\\____   \\   ", 0
    wBanner3        EQU   wBanner2    ; reuse (symmetric)
    wTitleLine      BYTE  0DAh,0C4h,0C4h,0C4h," DIZZY WALK -- PROFESSOR'S ADVENTURE ",0C4h,0C4h,0C4h,0BFh,0
    wSubTitle       BYTE  "  Assembly Language Game  |  FAST NU COAL 2026  ", 0
    wBox1           BYTE  0DAh,0
    wBoxH           BYTE  0C4h,0
    wBoxTopR        BYTE  0BFh,0
    wBoxBotL        BYTE  0C0h,0
    wBoxBotR        BYTE  0D9h,0
    wBoxV           BYTE  0B3h,0
    wBoxSepL        BYTE  0C3h,0
    wBoxSepR        BYTE  0B4h,0

    ; Section headers
    wHdrObjective   BYTE  " OBJECTIVE ", 0
    wHdrControls    BYTE  " CONTROLS", 0
    wHdrCells       BYTE  " MAP KEY ", 0
    wHdrRules       BYTE  " RULES   ", 0

    ; Rule/objective text (max 60 chars wide each)
    wObj1   BYTE  "  Guide the Professor through a randomized maze to", 0
    wObj2   BYTE  "  reach his home (", 0CEh, "). Collect coins & gems.", 0
    wObj3   BYTE  "  Keep your key safe -- you need it to get inside!", 0

    wCtrl1  BYTE  "  RANDOM mode : fully automatic -- just watch!", 0
    wCtrl2  BYTE  "  KEYBOARD mode: W/", 18h," Up   S/",19h," Down", 0
    wCtrl3  BYTE  "                A/","  Left  D/"," Right", 0
    wCtrl4  BYTE  "                ESC  Quit the game", 0

    wCell1  BYTE  "  ", 0DBh, "  Wall   -- impassable block", 0
    wCell2  BYTE  "  ", 0B2h, "  Building -- impassable structure", 0
    wCell3  BYTE  "  ", 0F7h, "  Lake   -- impassable water", 0
    wCell4  BYTE  "  ", 0D7h, "  Pit    -- INSTANT DEATH, avoid!", 0
    wCell5  BYTE  "  ", 0F8h, "  Coin   -- collect for +1 to wallet", 0
    wCell6  BYTE  "  ", 0FEh, "  Gem    -- collect for +5 to wallet", 0
    wCell7  BYTE  "  ", 0CEh, "  Home   -- destination, reach with key", 0
    wCell8  BYTE  "  ", 01h,  "  You    -- the Professor (that's you!)", 0

    wRule1  BYTE  "  1. You MUST hold your key to enter home.", 0
    wRule2  BYTE  "  2. Every step has a 1% chance to drop key.", 0
    wRule3  BYTE  "  3. Max 10,000 steps before professor is lost.", 0
    wRule4  BYTE  "  4. Falling in a pit ends the game instantly.", 0
    wRule5  BYTE  "  5. Collected items are removed from the map.", 0
    wRule6  BYTE  "  6. All runs are saved to adventure_log.txt.", 0

    ; Separator cha
    wSepChar    BYTE  0C4h, 0   ; ─

    ; ----------------------------------------------------------
    ; Main Menu -- ASCII art banner and menu strings
    ; ----------------------------------------------------------
    ; ASCII art "DIZZY WALK" banner (Centered with 24 leading spaces)
    ban1 BYTE "             ", 0DBh,0DBh,0DBh,0DBh,"  ",0DBh,"  ",0DBh,0DBh,0DBh,0DBh,0DBh," ",0DBh,0DBh,0DBh,0DBh,0DBh," ",0DBh,"   ",0DBh,"    ",0DBh,"   ",0DBh,"  ",0DBh,0DBh,0DBh,"  ",0DBh,"     ",0DBh,"  ",0DBh, 0
    ban2 BYTE "             ",0DBh,"   ",0DBh," ",0DBh,"     ",0DBh,"     ",0DBh,"  ",0DBh,"   ",0DBh,"    ",0DBh,"   ",0DBh," ",0DBh,"   ",0DBh," ",0DBh,"     ",0DBh," ",0DBh," ", 0
    ban3 BYTE "             ",0DBh,"   ",0DBh," ",0DBh,"    ",0DBh,"     ",0DBh,"    ",0DBh," ",0DBh,"     ",0DBh," ",0DBh," ",0DBh," ",0DBh,0DBh,0DBh,0DBh,0DBh," ",0DBh,"     ",0DBh,0DBh,"  ", 0
    ban4 BYTE "             ",0DBh,"   ",0DBh," ",0DBh,"   ",0DBh,"     ",0DBh,"      ",0DBh,"      ",0DBh,0DBh," ",0DBh,0DBh," ",0DBh,"   ",0DBh," ",0DBh,"     ",0DBh," ",0DBh," ", 0
    ban5 BYTE "             ",0DBh,0DBh,0DBh,0DBh,"  ",0DBh,"  ",0DBh,0DBh,0DBh,0DBh,0DBh," ",0DBh,0DBh,0DBh,0DBh,0DBh,"   ",0DBh,"      ",0DBh,"   ",0DBh," ",0DBh,"   ",0DBh," ",0DBh,0DBh,0DBh,0DBh,0DBh," ",0DBh,"  ",0DBh, 0
    ; Game info strings
    mnInfo1     BYTE "DIZZY WALK: The Drunk Professor", 0
    mnMazeInfo  BYTE "A 100 x 150 CONSOLE MAZE GAME", 0

    ; Tagline description
    mnDesc1     BYTE "Help the dizzy professor reach the door before disaster strikes.", 0
    mnDesc2     BYTE "Collect coins. Keep the key safe.", 0

    ; Menu options
    mnOpt1      BYTE "1. Start Manual Mode - Fixed Steps", 0
    mnOpt2      BYTE "2. Start Manual Mode - Endless", 0
    mnOpt3      BYTE "3. Start Random Mode - Fixed Steps   ", 0
    mnOpt4      BYTE "4. Start Random Mode - Endless   ", 0
    mnOpt5      BYTE "5. Instructions ", 0
    mnOpt6      BYTE "6. Exit ", 0
    mnPrompt    BYTE "Select an option: ", 0
    mnInvalid   BYTE "Invalid option! Try again.", 0

    ; Results screen strings
    rsTitle     BYTE " GAME RESULTS  ", 0
    rsReason    BYTE "Result    :  ", 0
    rsSteps     BYTE "Steps     :  ", 0
    rsCoins     BYTE "Coins     :  ", 0
    rsKeyLbl    BYTE "Key       :  ", 0
    rsNameLbl   BYTE "Professor  : ", 0
    rsModeLbl   BYTE "Mode      : ", 0
    rsManFixed  BYTE "Manual - Fixed Steps ", 0
    rsManEndl   BYTE "Manual - Endless ", 0
    rsRndFixed  BYTE "Random - Fixed Steps                          ", 0
    rsRndEndl   BYTE "Random - Endless                              ", 0
    rsSuccess   BYTE "SUCCESS! Reached home with key! ", 0
    rsNoKey     BYTE "FAIL! Reached home without key. ", 0
    rsPit       BYTE "GAME OVER! Fell into a pit! ", 0
    rsMaxStep   BYTE "LOST! Maximum steps reached. ", 0
    rsQuit      BYTE "Player quit the game. ", 0
    rsRetMenu   BYTE "Press any key to return to menu...", 0
    rsHeld      BYTE "YES", 0
    rsLost      BYTE "NO", 0

    ; Game mode tracking
    gameMode    BYTE 0        ; 1=ManFixed, 2=ManEndless, 3=RndFixed, 4=RndEndless
    stepLimit   DWORD 10000   ; current step limit for this game

; ============================================================
; .CODE -- all procedures and main entry point
; ============================================================
.code

; ============================================================
; Procedure : InitProfessor
; ============================================================
InitProfessor PROC USES eax ecx esi edi

    mov  eax, START_ROW
    mov  prof.posRow,  eax
    mov  prof.prevRow, eax

    mov  eax, START_COL
    mov  prof.posCol,  eax
    mov  prof.prevCol, eax

    mov  prof.wallet,    0
    mov  prof.hasKey,    KEY_PRESENT
    mov  prof.stepCount, 0

    lea  esi, nameBuffer
    lea  edi, prof.profName
    mov  ecx, NAME_LEN
    rep  movsb

    ret
InitProfessor ENDP

; ============================================================
; Procedure : InitMaze
; ============================================================
InitMaze PROC USES eax ecx edi

    lea  edi, maze
    mov  ecx, MAZE_SIZE
    mov  al,  CELL_EMPTY
    rep  stosb

    MAZE_INDEX DEST_ROW, DEST_COL, esi
    mov  BYTE PTR maze[esi], CELL_DEST

    ret
InitMaze ENDP

; ============================================================
; Procedure : DisplayProfessorInfo
; ============================================================
DisplayProfessorInfo PROC USES eax edx




    lea  edx, prof.profName
    call WriteString
    NEWLINE


    PRINT_NUM prof.wallet
    NEWLINE


    cmp  prof.hasKey, KEY_PRESENT
    je   ShowYes

    jmp  AfterKey
ShowYes:

AfterKey:


    PRINT_NUM prof.posRow

    PRINT_NUM prof.posCol
    NEWLINE

    cmp  prof.moveMode, MODE_RANDOM
    je   ShowRandom

    jmp  AfterMode
ShowRandom:

AfterMode:


    mov  eax, MAZE_ROWS
    call WriteDec

    mov  eax, MAZE_COLS
    call WriteDec



    mov  eax, DEST_ROW
    call WriteDec

    mov  eax, DEST_COL
    call WriteDec
    NEWLINE


    ret
DisplayProfessorInfo ENDP

; ============================================================
; Procedure : CheckCollision
; ============================================================
CheckCollision PROC USES ebx ecx

    cmp  ebx, 0
    jl   OutOfBounds
    cmp  ebx, MAZE_ROWS
    jge  OutOfBounds

    cmp  ecx, 0
    jl   OutOfBounds
    cmp  ecx, MAZE_COLS
    jge  OutOfBounds

    MAZE_INDEX ebx, ecx, esi
    movzx eax, BYTE PTR maze[esi]
    jmp  CollisionDone

OutOfBounds:
    mov  al, 0FFh

CollisionDone:
    ret
CheckCollision ENDP

; ============================================================
; Procedure : MoveUp
; ============================================================
MoveUp PROC USES ebx ecx

    mov  ebx, prof.posRow
    mov  ecx, prof.posCol
    dec  ebx

    call CheckCollision

    mov  edx, prof.posRow
    mov  prof.prevRow, edx
    mov  edx, prof.posCol
    mov  prof.prevCol, edx

    cmp  al, 0FFh
    je   MoveUpBlocked
    cmp  al, CELL_WALL
    je   MoveUpBlocked
    cmp  al, CELL_BUILDING
    je   MoveUpBlocked
    cmp  al, CELL_LAKE
    je   MoveUpBlocked

    mov  prof.posRow, ebx
    inc  prof.stepCount
    call LogStep
    jmp  MoveUpDone

MoveUpBlocked:
MoveUpDone:
    ret
MoveUp ENDP

; ============================================================
; Procedure : MoveDown
; ============================================================
MoveDown PROC USES ebx ecx

    mov  ebx, prof.posRow
    mov  ecx, prof.posCol
    inc  ebx

    call CheckCollision

    mov  edx, prof.posRow
    mov  prof.prevRow, edx
    mov  edx, prof.posCol
    mov  prof.prevCol, edx

    cmp  al, 0FFh
    je   MoveDownBlocked
    cmp  al, CELL_WALL
    je   MoveDownBlocked
    cmp  al, CELL_BUILDING
    je   MoveDownBlocked
    cmp  al, CELL_LAKE
    je   MoveDownBlocked

    mov  prof.posRow, ebx
    inc  prof.stepCount
    call LogStep
    jmp  MoveDownDone

MoveDownBlocked:
MoveDownDone:
    ret
MoveDown ENDP

; ============================================================
; Procedure : MoveLeft
; ============================================================
MoveLeft PROC USES ebx ecx

    mov  ebx, prof.posRow
    mov  ecx, prof.posCol
    dec  ecx

    call CheckCollision

    mov  edx, prof.posRow
    mov  prof.prevRow, edx
    mov  edx, prof.posCol
    mov  prof.prevCol, edx

    cmp  al, 0FFh
    je   MoveLeftBlocked
    cmp  al, CELL_WALL
    je   MoveLeftBlocked
    cmp  al, CELL_BUILDING
    je   MoveLeftBlocked
    cmp  al, CELL_LAKE
    je   MoveLeftBlocked

    mov  prof.posCol, ecx
    inc  prof.stepCount
    call LogStep
    jmp  MoveLeftDone

MoveLeftBlocked:
MoveLeftDone:
    ret
MoveLeft ENDP

; ============================================================
; Procedure : MoveRight
; ============================================================
MoveRight PROC USES ebx ecx

    mov  ebx, prof.posRow
    mov  ecx, prof.posCol
    inc  ecx

    call CheckCollision

    mov  edx, prof.posRow
    mov  prof.prevRow, edx
    mov  edx, prof.posCol
    mov  prof.prevCol, edx

    cmp  al, 0FFh
    je   MoveRightBlocked
    cmp  al, CELL_WALL
    je   MoveRightBlocked
    cmp  al, CELL_BUILDING
    je   MoveRightBlocked
    cmp  al, CELL_LAKE
    je   MoveRightBlocked

    mov  prof.posCol, ecx
    inc  prof.stepCount
    call LogStep
    jmp  MoveRightDone

MoveRightBlocked:
MoveRightDone:
    ret
MoveRight ENDP

; ============================================================
; Procedure : LogStep
; ============================================================
LogStep PROC USES eax ebx edi

    mov  eax, pathCount
    cmp  eax, MAX_STEPS
    jge  LogStepDone

    mov  ebx, SIZEOF PATH_ENTRY
    imul eax, ebx
    lea  edi, pathLog
    add  edi, eax

    mov  eax, prof.posRow
    mov  [edi].PATH_ENTRY.stepRow, eax

    mov  eax, prof.posCol
    mov  [edi].PATH_ENTRY.stepCol, eax

    inc  pathCount

LogStepDone:
    ret
LogStep ENDP

; ============================================================
; Procedure : UpdateViewport
; ============================================================
UpdateViewport PROC USES eax

    mov  eax, prof.posRow
    sub  eax, VIEWPORT_ROWS / 2
    cmp  eax, 0
    jge  UVP_RowPos
    mov  eax, 0
    jmp  UVP_SetRow
UVP_RowPos:
    cmp  eax, VP_ROW_MAX
    jle  UVP_SetRow
    mov  eax, VP_ROW_MAX
UVP_SetRow:
    mov  vpRow, eax

    mov  eax, prof.posCol
    sub  eax, VIEWPORT_COLS / 2
    cmp  eax, 0
    jge  UVP_ColPos
    mov  eax, 0
    jmp  UVP_SetCol
UVP_ColPos:
    cmp  eax, VP_COL_MAX
    jle  UVP_SetCol
    mov  eax, VP_COL_MAX
UVP_SetCol:
    mov  vpCol, eax

    ret
UpdateViewport ENDP

; ============================================================
; Procedure : SetCellColor
; ============================================================
SetCellColor PROC USES eax

    movzx eax, al

    cmp  eax, CELL_WALL
    je   SCC_Wall
    cmp  eax, CELL_BUILDING
    je   SCC_Building
    cmp  eax, CELL_LAKE
    je   SCC_Lake
    cmp  eax, CELL_PIT
    je   SCC_Pit
    cmp  eax, CELL_COIN
    je   SCC_Coin
    cmp  eax, CELL_DEST
    je   SCC_Dest
    cmp  eax, CELL_GEM
    je   SCC_Gem
    ; Default: CELL_EMPTY -- dark grey on black (░ shade)
    mov  eax, 02h
    call SetTextColor
    jmp  SCC_Done

SCC_Wall:
    ; bright white on dark grey -- █ pops clearly
    mov  eax, 07h
    call SetTextColor
    jmp  SCC_Done
SCC_Building:
    ; brown/yellow on black -- ▓ stands out
    mov  eax, COLOR_BUILDING
    call SetTextColor
    jmp  SCC_Done
SCC_Lake:
    ; bright blue on black -- ≈ water feel
    mov  eax, 09h
    call SetTextColor
    jmp  SCC_Done
SCC_Pit:
    ; bright red on black -- × danger
    mov  eax, 0Ch
    call SetTextColor
    jmp  SCC_Done
SCC_Coin:
    ; bright yellow on black -- ° gleaming
    mov  eax, COLOR_COIN
    call SetTextColor
    jmp  SCC_Done
SCC_Dest:
    ; bright green on black -- ╬ safe haven
    mov  eax, COLOR_DEST
    call SetTextColor
    jmp  SCC_Done
SCC_Gem:
    ; bright magenta on black -- ♦ precious
    mov  eax, 0Dh
    call SetTextColor
    jmp  SCC_Done

SCC_Done:
    ret
SetCellColor ENDP

; ============================================================
; Procedure : CellTypeToChar
; Purpose   : Converts cell type to Unicode display character.
;             Uses the richer chars from dizzy_walk_ui.inc.
; ============================================================
CellTypeToChar PROC

    cmp  al, CELL_WALL
    je   CTC_Wall
    cmp  al, CELL_BUILDING
    je   CTC_Building
    cmp  al, CELL_LAKE
    je   CTC_Lake
    cmp  al, CELL_PIT
    je   CTC_Pit
    cmp  al, CELL_COIN
    je   CTC_Coin
    cmp  al, CELL_DEST
    je   CTC_Dest
    cmp  al, CELL_GEM
    je   CTC_Gem
    ; Default: empty -- light shade ░
    mov  al, 0FAh
    ret
CTC_Wall:
    mov  al, CHAR_WALL_U
    ret
CTC_Building:
    mov  al, CHAR_BUILD_U
    ret
CTC_Lake:
    mov  al, CHAR_LAKE_U
    ret
CTC_Pit:
    mov  al, CHAR_PIT_U
    ret
CTC_Coin:
    mov  al, CHAR_COIN_U
    ret
CTC_Dest:
    mov  al, CHAR_DEST_U
    ret
CTC_Gem:
    mov  al, CHAR_GEM
    ret

CellTypeToChar ENDP

; ============================================================
; Procedure : DrawCell
; ============================================================
DrawCell PROC USES eax edx

    call Gotoxy

    mov  al, bl
    call SetCellColor

    mov  al, bl
    call CellTypeToChar

    call WriteChar
    call WriteChar

    ret
DrawCell ENDP

; ============================================================
; Procedure : DrawMaze
; ============================================================
DrawMaze PROC USES eax ebx ecx edx esi

    mov  screenR, 0

DM_RowLoop:
    mov  eax, screenR
    cmp  eax, VIEWPORT_ROWS
    jge  DM_Done

    mov  screenC, 0

DM_ColLoop:
    mov  eax, screenC
    cmp  eax, VIEWPORT_COLS
    jge  DM_NextRow

    mov  eax, vpRow
    add  eax, screenR

    mov  ebx, vpCol
    add  ebx, screenC

    MAZE_INDEX eax, ebx, esi
    movzx ecx, BYTE PTR maze[esi]
    mov  bl, cl

    mov  eax, screenR
    mov  dh, al

    mov  eax, screenC
    imul eax, CELL_WIDTH
    mov  dl, al

    call DrawCell

    mov  eax, screenC
    inc  eax
    mov  screenC, eax
    jmp  DM_ColLoop

DM_NextRow:
    mov  eax, screenR
    inc  eax
    mov  screenR, eax
    jmp  DM_RowLoop

DM_Done:
    ret
DrawMaze ENDP

; ============================================================
; Procedure : DrawProfessor
; ============================================================
DrawProfessor PROC USES eax edx

    mov  eax, prof.posRow
    sub  eax, vpRow
    mov  dh, al

    mov  eax, prof.posCol
    sub  eax, vpCol
    imul eax, CELL_WIDTH
    mov  dl, al

    call Gotoxy

    ; Bright cyan on black -- professor stands out vividly
    mov  eax, 0F0h          ; bright white ON bright cyan -- unmissable
    call SetTextColor
    mov  al, 02h            ; ☻ filled smiley
    call WriteChar
    mov  al, ' '
    call WriteChar 

    ret
DrawProfessor ENDP

; ============================================================
; Procedure : EraseOldPos
; ============================================================
EraseOldPos PROC USES eax ebx ecx edx esi

    mov  eax, prof.prevRow
    sub  eax, vpRow
    cmp  eax, 0
    jl   EOP_Done
    cmp  eax, VIEWPORT_ROWS
    jge  EOP_Done

    mov  ecx, prof.prevCol
    sub  ecx, vpCol
    cmp  ecx, 0
    jl   EOP_Done
    cmp  ecx, VIEWPORT_COLS
    jge  EOP_Done

    MAZE_INDEX prof.prevRow, prof.prevCol, esi
    movzx eax, BYTE PTR maze[esi]
    mov  bl, al

    mov  eax, prof.prevRow
    sub  eax, vpRow
    mov  dh, al

    mov  eax, prof.prevCol
    sub  eax, vpCol
    imul eax, CELL_WIDTH
    mov  dl, al

    call DrawCell

EOP_Done:
    ret
EraseOldPos ENDP

; ============================================================
; Procedure : DWordToStr
; Purpose   : Converts EAX to decimal string in numScratch.
;             Null-terminates. Returns length in ECX.
; Receives  : EAX = number
; Returns   : numScratch filled, ECX = length
; Registers : EAX, EBX, ECX, EDX, EDI (all pushed/popped)
; ============================================================
DWordToStr PROC USES eax ebx edx edi

    lea  edi, numScratch
    mov  ebx, 10
    mov  ecx, 0

    cmp  eax, 0
    jne  DTS_Div
    mov  BYTE PTR [edi], '0'
    mov  BYTE PTR [edi+1], 0
    mov  ecx, 1
    jmp  DTS_Done

DTS_Div:
    cmp  eax, 0
    je   DTS_Build
    xor  edx, edx
    div  ebx
    push edx
    inc  ecx
    jmp  DTS_Div

DTS_Build:
    ; pop digits in order into numScratch
    push ecx            ; save count
    mov  edi, 0
DTS_Pop:
    cmp  ecx, 0
    je   DTS_Null
    pop  edx
    add  dl, '0'
    mov  numScratch[edi], dl
    inc  edi
    dec  ecx
    jmp  DTS_Pop
DTS_Null:
    mov  numScratch[edi], 0
    pop  ecx            ; restore count

DTS_Done:
    ret
DWordToStr ENDP

; ============================================================
; Procedure : DrawPanelBorder
; Purpose   : Draws the static border and section headers of
;             the side panel. Call once at InitVisual.
;             Uses box-drawing chars from dizzy_walk_ui.inc.
; Receives  : nothing
; Returns   : nothing
; Registers : EAX, ECX, EDX (saved via USES)
; ============================================================
DrawPanelBorder PROC USES eax ecx edx

    ; Set panel border color: bright white on blue
    mov  eax, COL_PANEL_BOX
    call SetTextColor

    ; ── Top border ──────────────────────────────────────────
    mov  dh, PANEL_TOP
    mov  dl, PANEL_LEFT
    call Gotoxy
    mov  al, UI_TOPLEFT
    call WriteChar
    mov  ecx, PANEL_WIDTH - 2
DPB_TopH:
    mov  al, UI_HLINE
    call WriteChar
    loop DPB_TopH
    mov  al, UI_TOPRIGHT
    call WriteChar

    ; ── Side verticals + fill rows 1..PANEL_HEIGHT-2 ────────
    mov  ecx, 1             ; current row offset from PANEL_TOP
DPB_SideLoop:
    cmp  ecx, PANEL_HEIGHT - 1
    jge  DPB_BottomBorder

    mov  eax, ecx
    add  eax, PANEL_TOP
    mov  dh, al
    mov  dl, PANEL_LEFT
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar

    ; Fill row interior with spaces (PANEL_WIDTH-2 spaces)
    push ecx
    mov  ecx, PANEL_WIDTH - 2
DPB_FillRow:
    mov  al, ' '
    call WriteChar
    loop DPB_FillRow
    pop  ecx

    ; Right border char
    mov  eax, ecx
    add  eax, PANEL_TOP
    mov  dh, al
    mov  dl, PANEL_LEFT + PANEL_WIDTH - 1
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar

    inc  ecx
    jmp  DPB_SideLoop

DPB_BottomBorder:
    ; ── Bottom border ────────────────────────────────────────
    mov  eax, PANEL_TOP + PANEL_HEIGHT - 1
    mov  dh, al
    mov  dl, PANEL_LEFT
    call Gotoxy
    mov  al, UI_BOTLEFT
    call WriteChar
    mov  ecx, PANEL_WIDTH - 2
DPB_BotH:
    mov  al, UI_HLINE
    call WriteChar
    loop DPB_BotH
    mov  al, UI_BOTRIGHT
    call WriteChar

    ; ── Title row (row 0) ────────────────────────────────────
    mov  eax, COL_PANEL_HDR
    call SetTextColor
    mov  dh, PANEL_ROW_TITLE
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    ; Center "DIZZY WALK" (10 chars) in 18-char interior
    ; Pad 4 spaces each side = 4 + 10 + 4 = 18
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar
    mov  edx, OFFSET panelTitle
    call WriteString
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar

    ; ── Separator row 8 (after stats) ────────────────────────
    mov  eax, COL_PANEL_BOX
    call SetTextColor
    mov  dh, 8
    mov  dl, PANEL_LEFT
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  ecx, PANEL_WIDTH - 2
DPB_Sep1:
    mov  al, UI_HLINE
    call WriteChar
    loop DPB_Sep1
    mov  al, UI_T_LEFT
    call WriteChar

    ; ── LEGEND header row ────────────────────────────────────
    mov  eax, COL_PANEL_HDR
    call SetTextColor
    mov  dh, PANEL_ROW_LGND
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar
    mov  edx, OFFSET panelLgndHdr
    call WriteString
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar

    ; ── Legend lines ─────────────────────────────────────────
    ; lgnd1..lgnd7 -- each goes at PANEL_LEFT+2, row PANEL_ROW_L1..L7

    ; lgnd1 -- Wall
    mov  eax, 07h           ; grey (wall color)
    call SetTextColor
    mov  dh, PANEL_ROW_L1
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd1
    call WriteString

    ; lgnd2 -- Building
    mov  eax, COLOR_BUILDING
    call SetTextColor
    mov  dh, PANEL_ROW_L2
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd2
    call WriteString

    ; lgnd3 -- Lake
    mov  eax, 09h
    call SetTextColor
    mov  dh, PANEL_ROW_L3
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd3
    call WriteString

    ; lgnd4 -- Pit
    mov  eax, 0Ch
    call SetTextColor
    mov  dh, PANEL_ROW_L4
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd4
    call WriteString

    ; lgnd5 -- Coin
    mov  eax, COLOR_COIN
    call SetTextColor
    mov  dh, PANEL_ROW_L5
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd5
    call WriteString

    ; lgnd6 -- Gem
    mov  eax, COLOR_GEM
    call SetTextColor
    mov  dh, PANEL_ROW_L6
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd6
    call WriteString

    ; lgnd7 -- Home/Dest
    mov  eax, COLOR_DEST
    call SetTextColor
    mov  dh, PANEL_ROW_L7
    mov  dl, PANEL_LEFT + 2
    call Gotoxy
    mov  edx, OFFSET lgnd7
    call WriteString

    ; ── Separator row 17 (before events) ─────────────────────
    mov  eax, COL_PANEL_BOX
    call SetTextColor
    mov  dh, PANEL_ROW_DIV2
    mov  dl, PANEL_LEFT
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  ecx, PANEL_WIDTH - 2
DPB_Sep2:
    mov  al, UI_HLINE
    call WriteChar
    loop DPB_Sep2
    mov  al, UI_T_LEFT
    call WriteChar

    ; ── EVENTS header row ────────────────────────────────────
    mov  eax, COL_PANEL_HDR
    call SetTextColor
    mov  dh, PANEL_ROW_EVHDR
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar
    mov  edx, OFFSET panelEvHdr
    call WriteString
    mov  al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    call WriteChar

    ; Reset color
    mov  eax, COLOR_EMPTY
    call SetTextColor

    ret
DrawPanelBorder ENDP

; ============================================================
; Procedure : DrawSidePanel
; Purpose   : Refreshes the dynamic fields of the side panel:
;             professor name, position, steps, coins, key,
;             mode.  Does NOT redraw the border/legend (those
;             are static and set by DrawPanelBorder once).
; Receives  : nothing
; Returns   : nothing
; Registers : EAX, EDX (USES)
; ============================================================
DrawSidePanel PROC USES eax edx ecx

    ; ── Professor name ───────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_NAME
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelProfLbl
    call WriteString

    mov  eax, COL_PANEL_VAL
    call SetTextColor
    lea  edx, prof.profName
    call WriteString

    ; Pad rest of row with spaces (up to right border)
    mov  eax, COL_PANEL_BG
    call SetTextColor
    ; We'll write 8 spaces to erase leftover chars
    mov  ecx, 8
DSP_PadName:
    mov  al, ' '
    call WriteChar
    loop DSP_PadName

    ; ── Position ─────────────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_POS
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelPosLbl
    call WriteString

    mov  eax, COL_PANEL_POS
    call SetTextColor
    mov  eax, prof.posRow
    call WriteDec
    mov  al, ','
    call WriteChar
    mov  eax, prof.posCol
    call WriteDec
    ; Pad
    mov  ecx, 5
DSP_PadPos:
    mov  al, ' '
    call WriteChar
    loop DSP_PadPos

    ; ── Steps ────────────────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_STEPS
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelStepLbl
    call WriteString

    mov  eax, COL_PANEL_VAL
    call SetTextColor
    mov  eax, prof.stepCount
    call WriteDec
    mov  ecx, 6
DSP_PadStep:
    mov  al, ' '
    call WriteChar
    loop DSP_PadStep

    ; ── Coins ────────────────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_COINS
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelCoinLbl
    call WriteString

    mov  eax, COL_PANEL_LCOIN
    call SetTextColor
    mov  eax, prof.wallet
    call WriteDec
    mov  ecx, 6
DSP_PadCoin:
    mov  al, ' '
    call WriteChar
    loop DSP_PadCoin

    ; ── Key ──────────────────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_KEY
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelKeyLbl
    call WriteString

    cmp  prof.hasKey, KEY_PRESENT
    je   DSP_KeyYes
    mov  eax, COL_PANEL_BAD
    call SetTextColor
    mov  edx, OFFSET panelKeyNo
    call WriteString
    mov  ecx, 4
DSP_PadKeyN:
    mov  al, ' '
    call WriteChar
    loop DSP_PadKeyN
    jmp  DSP_AfterKey
DSP_KeyYes:
    mov  eax, COL_PANEL_OK
    call SetTextColor
    mov  edx, OFFSET panelKeyYes
    call WriteString
    mov  ecx, 4
DSP_PadKeyY:
    mov  al, ' '
    call WriteChar
    loop DSP_PadKeyY
DSP_AfterKey:

    ; ── Mode ─────────────────────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_MODE
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelModeLbl
    call WriteString

    mov  eax, COL_PANEL_VAL
    call SetTextColor
    mov  al, prof.moveMode
    cmp  al, MODE_RANDOM
    je   DSP_ModeRnd
    mov  edx, OFFSET panelModeKbd
    call WriteString
    jmp  DSP_AfterMode
DSP_ModeRnd:
    mov  edx, OFFSET panelModeRnd
    call WriteString
DSP_AfterMode:

    ; ── Score (wallet * 10) ──────────────────────────────────
    mov  eax, COL_PANEL_LBL
    call SetTextColor
    mov  dh, PANEL_ROW_DEST   ; row 7 -- use for score
    mov  dl, PANEL_LEFT + 1
    call Gotoxy
    mov  edx, OFFSET panelScoreLbl
    call WriteString

    mov  eax, 0Eh             ; bright yellow for score
    call SetTextColor
    mov  eax, prof.wallet
    imul eax, 10              ; score = coins * 10
    call WriteDec
    mov  ecx, 5
DSP_PadScore:
    mov  al, ' '
    call WriteChar
    loop DSP_PadScore

    ; Reset color
    mov  eax, COLOR_EMPTY
    call SetTextColor

    ret
DrawSidePanel ENDP

; ============================================================
; Procedure : AddEventLog
; Purpose   : Adds a short event string (max 17 chars) to the
;             circular event log and redraws all event rows.
;             The newest event always appears at the top.
; Receives  : ESI = address of null-terminated event string
;             EAX = color to use for this event line
; Returns   : nothing
; Registers : EAX, EBX, ECX, EDX, ESI, EDI (USES)
; ============================================================
AddEventLog PROC USES eax ebx ecx edx esi edi

    ; Save event color for later (store in EBX since USES saves it)
    mov  ebx, eax           ; EBX = color

    ; Work backwards: copy slot[N-2] -> slot[N-1] down to slot[0]->slot[1]
    mov  ecx, EVLOG_MAX - 1     ; number of shifts
AEL_Shift:
    ; source = evLog + (ecx-1)*(EVLOG_BUF_LEN+1)
    ; dest   = evLog + ecx*(EVLOG_BUF_LEN+1)
    mov  eax, ecx
    dec  eax
    imul eax, (EVLOG_BUF_LEN + 1)
    lea  edi, evLog
    add  edi, eax               ; EDI = source slot

    mov  eax, ecx
    imul eax, (EVLOG_BUF_LEN + 1)
    lea  edx, evLog
    add  edx, eax               ; EDX = dest slot

    ; Copy EVLOG_BUF_LEN+1 bytes
    push ecx
    push esi
    mov  esi, edi
    mov  edi, edx
    mov  ecx, EVLOG_BUF_LEN + 1
    rep  movsb
    pop  esi
    pop  ecx

    dec  ecx
    jnz  AEL_Shift

    ; ── Write new event string into slot 0 ───────────────────
    lea  edi, evLog             ; slot 0 starts at evLog[0]
    mov  ecx, EVLOG_BUF_LEN
AEL_CopyNew:
    mov  al, [esi]
    cmp  al, 0
    je   AEL_PadSlot0
    mov  [edi], al
    inc  esi
    inc  edi
    dec  ecx
    jnz  AEL_CopyNew
    jmp  AEL_Term0
AEL_PadSlot0:
    mov  BYTE PTR [edi], ' '    ; pad with spaces
    inc  edi
    dec  ecx
    jnz  AEL_PadSlot0
AEL_Term0:
    mov  BYTE PTR [edi], 0      ; null terminate

    ; ── Redraw all event rows ────────────────────────────────
    mov  ecx, 0                 ; slot index
AEL_DrawLoop:
    cmp  ecx, EVLOG_MAX
    jge  AEL_DrawDone

    ; Compute address of slot[ecx]
    mov  eax, ecx
    imul eax, (EVLOG_BUF_LEN + 1)
    lea  edi, evLog
    add  edi, eax               ; EDI = evLog[ecx]

    ; Screen row = PANEL_ROW_EV0 + ecx
    mov  eax, PANEL_ROW_EV0
    add  eax, ecx
    mov  dh, al
    mov  dl, PANEL_LEFT + 1
    call Gotoxy

    ; Color: newest line gets passed color, others are grey
    cmp  ecx, 0
    jne  AEL_OldLine
    mov  eax, ebx               ; newest = caller's color
    jmp  AEL_SetLineColor
AEL_OldLine:
    mov  eax, COL_PANEL_LOG     ; older events = white on blue
AEL_SetLineColor:
    call SetTextColor

    ; Write the slot string (already padded to EVLOG_BUF_LEN)
    mov  edx, edi
    call WriteString

    inc  ecx
    jmp  AEL_DrawLoop

AEL_DrawDone:
    mov  eax, COLOR_EMPTY
    call SetTextColor
    ret
AddEventLog ENDP

; ============================================================
; Procedure : DrawStatusBar
; Purpose   : NOW DELEGATES to DrawSidePanel.
;             The old bottom status bar is gone; all status
;             info lives in the side panel.
;             This proc kept for compatibility (AnimateStep
;             calls it).
; ============================================================
DrawStatusBar PROC USES eax edx
    call DrawSidePanel
    ret
DrawStatusBar ENDP

; ============================================================
; Procedure : InitVisual
; Purpose   : Sets up the console, draws maze, professor,
;             and the full side panel (border + static data).
; ============================================================
InitVisual PROC USES eax

    call Clrscr
    call UpdateViewport
    call DrawMaze
    call DrawProfessor
    call DrawPanelBorder        ; draw static border + legend once
    call DrawSidePanel          ; draw dynamic stats

    ret
InitVisual ENDP

; ============================================================
; Procedure : AnimateStep
; ============================================================
AnimateStep PROC USES eax ebx

    mov  eax, vpRow
    mov  ebx, vpCol

    call EraseOldPos

    call UpdateViewport

    cmp  eax, vpRow
    jne  AS_FullRedraw
    cmp  ebx, vpCol
    jne  AS_FullRedraw
    jmp  AS_DrawProf

AS_FullRedraw:
    call DrawMaze

AS_DrawProf:
    call DrawProfessor
    call DrawSidePanel          ; update stats in side panel

    ret
AnimateStep ENDP

; ============================================================
; Procedure : FillDiamond
; ============================================================
FillDiamond PROC USES eax ebx ecx edx edi esi

    mov  edx, objRow
    sub  edx, objLen

FD_RowLoop:
    mov  eax, objRow
    add  eax, objLen
    cmp  edx, eax
    jg   FD_Done

    mov  eax, edx
    sub  eax, objRow
    jge  FD_Positive
    neg  eax
FD_Positive:
    mov  ecx, objLen
    sub  ecx, eax
    jle  FD_NextRow

    mov  edi, objCol
    sub  edi, ecx
    push ecx

    pop  ecx
    mov  eax, ecx
    imul eax, 2
    inc  eax
    mov  ecx, eax

FD_ColLoop:
    cmp  edx, 0
    jl   FD_ColSkip
    cmp  edx, MAZE_ROWS - 1
    jg   FD_ColSkip
    cmp  edi, 0
    jl   FD_ColSkip
    cmp  edi, MAZE_COLS - 1
    jg   FD_ColSkip

    MAZE_INDEX edx, edi, esi
    mov  BYTE PTR maze[esi], CELL_LAKE

FD_ColSkip:
    inc  edi
    loop FD_ColLoop

FD_NextRow:
    inc  edx
    jmp  FD_RowLoop

FD_Done:
    ret
FillDiamond ENDP

; ============================================================
; Procedure : PlaceSingleWall (horizontal)
; Purpose   : Helper -- places a horizontal wall of given length
;             at (EBX=row, EDI=startCol), ECX=length.
; ============================================================
PlaceSingleHWall PROC USES eax ebx ecx edi esi
PSHW_Loop:
    cmp  edi, MAZE_COLS - 1
    jge  PSHW_Done
    MAZE_INDEX ebx, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST  ; never overwrite destination
    je   PSHW_Skip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PSHW_Skip
    mov  BYTE PTR maze[esi], CELL_WALL
PSHW_Skip:
    inc  edi
    loop PSHW_Loop
PSHW_Done:
    ret
PlaceSingleHWall ENDP

; ============================================================
; Procedure : PlaceSingleVWall (vertical)
; ============================================================
PlaceSingleVWall PROC USES eax ebx ecx edi esi
PSVW_Loop:
    cmp  ebx, MAZE_ROWS - 1
    jge  PSVW_Done
    MAZE_INDEX ebx, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST
    je   PSVW_Skip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PSVW_Skip
    mov  BYTE PTR maze[esi], CELL_WALL
PSVW_Skip:
    inc  ebx
    loop PSVW_Loop
PSVW_Done:
    ret
PlaceSingleVWall ENDP

; ============================================================
; Procedure : PlaceDiamondLake
; Purpose   : Places one diamond lake using objRow/objCol/objLen
; ============================================================
PlaceDiamondLake PROC USES eax ebx ecx edi esi

    ; Side 1: top to right
    mov  eax, objRow
    sub  eax, objLen
    mov  ebx, eax
    mov  edi, objCol
    mov  ecx, objLen
PDL_S1:
    cmp  ebx, 0
    jl   PDL_S1S
    cmp  edi, MAZE_COLS - 1
    jge  PDL_S1S
    MAZE_INDEX ebx, edi, esi
    mov  BYTE PTR maze[esi], CELL_LAKE
PDL_S1S:
    inc  ebx
    inc  edi
    loop PDL_S1

    ; Side 2: right to bottom
    mov  eax, objRow
    mov  ebx, eax
    mov  eax, objCol
    add  eax, objLen
    mov  edi, eax
    mov  ecx, objLen
PDL_S2:
    cmp  ebx, MAZE_ROWS - 1
    jge  PDL_S2S
    cmp  edi, 0
    jl   PDL_S2S
    MAZE_INDEX ebx, edi, esi
    mov  BYTE PTR maze[esi], CELL_LAKE
PDL_S2S:
    inc  ebx
    dec  edi
    loop PDL_S2

    ; Side 3: bottom to left
    mov  eax, objRow
    add  eax, objLen
    mov  ebx, eax
    mov  edi, objCol
    mov  ecx, objLen
PDL_S3:
    cmp  ebx, MAZE_ROWS - 1
    jge  PDL_S3S
    cmp  edi, 0
    jl   PDL_S3S
    MAZE_INDEX ebx, edi, esi
    mov  BYTE PTR maze[esi], CELL_LAKE
PDL_S3S:
    dec  ebx
    dec  edi
    loop PDL_S3

    ; Side 4: left to top
    mov  eax, objRow
    mov  ebx, eax
    mov  eax, objCol
    sub  eax, objLen
    mov  edi, eax
    mov  ecx, objLen
PDL_S4:
    cmp  ebx, 0
    jl   PDL_S4S
    cmp  edi, MAZE_COLS - 1
    jge  PDL_S4S
    MAZE_INDEX ebx, edi, esi
    mov  BYTE PTR maze[esi], CELL_LAKE
PDL_S4S:
    dec  ebx
    inc  edi
    loop PDL_S4

    call FillDiamond

    ret
PlaceDiamondLake ENDP

; ============================================================
; Procedure : PlaceMazeObjects
; Purpose   : Places walls, building, lake, pits, coins, gems.
; ============================================================
PlaceMazeObjects PROC USES eax ebx ecx edx esi edi

    mov  al, prof.moveMode
    cmp  al, MODE_RANDOM
    je   PMO_RandomMode

    ; =========================================================
    ; KEYBOARD MODE -- fully randomised objects across full maze
    ; =========================================================

    ; ---- Horizontal wall 1 ----------------------------------
    mov  eax, 80
    call RandomRange
    add  eax, 5
    mov  objRow, eax
    mov  eax, 100
    call RandomRange
    add  eax, 5
    mov  objCol, eax
    mov  eax, 20
    call RandomRange
    add  eax, 10
    mov  objLen, eax
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, objLen
    call PlaceSingleHWall

    ; ---- Vertical wall 1 ------------------------------------
    mov  eax, 80
    call RandomRange
    add  eax, 5
    mov  objRow, eax
    mov  eax, 120
    call RandomRange
    add  eax, 5
    mov  objCol, eax
    mov  eax, 20
    call RandomRange
    add  eax, 10
    mov  objLen, eax
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, objLen
    call PlaceSingleVWall

    ; ---- Horizontal wall 2 ----------------------------------
    mov  eax, 80
    call RandomRange
    add  eax, 5
    mov  objRow, eax
    mov  eax, 100
    call RandomRange
    add  eax, 5
    mov  objCol, eax
    mov  eax, 25
    call RandomRange
    add  eax, 10
    mov  objLen, eax
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, objLen
    call PlaceSingleHWall

    ; ---- Extra walls (EXTRA_WALLS=4 additional) -------------
    mov  ecx, EXTRA_WALLS
KBD_ExtraWalls:
    push ecx

    mov  eax, 80
    call RandomRange
    add  eax, 5
    mov  objRow, eax
    mov  eax, 120
    call RandomRange
    add  eax, 5
    mov  objCol, eax
    mov  eax, 18
    call RandomRange
    add  eax, 8
    mov  objLen, eax

    ; Alternate H/V based on loop parity
    mov  eax, 2
    call RandomRange
    cmp  eax, 0
    je   KBD_ExtraH
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, objLen
    call PlaceSingleVWall
    jmp  KBD_ExtraDone
KBD_ExtraH:
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, objLen
    call PlaceSingleHWall
KBD_ExtraDone:
    pop  ecx
    loop KBD_ExtraWalls

    ; ---- Building -- random ----------------------------------
    mov  eax, 70
    call RandomRange
    add  eax, 5
    mov  objRow, eax
    mov  eax, 110
    call RandomRange
    add  eax, 5
    mov  objCol, eax
    mov  eax, 8
    call RandomRange
    add  eax, 3
    mov  objH, eax
    mov  eax, 15
    call RandomRange
    add  eax, 5
    mov  objW, eax

    mov  eax, objRow
KBD_BuildRow:
    mov  edx, objRow
    add  edx, objH
    cmp  eax, edx
    jge  KBD_BuildDone
    cmp  eax, MAZE_ROWS - 1
    jge  KBD_BuildDone
    mov  edi, objCol
    mov  ecx, objW
KBD_BuildCol:
    cmp  edi, MAZE_COLS - 1
    jge  KBD_BuildColDone
    MAZE_INDEX eax, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST
    je   KBD_BuildSkip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  KBD_BuildSkip
    mov  BYTE PTR maze[esi], CELL_BUILDING
KBD_BuildSkip:
    inc  edi
    loop KBD_BuildCol
KBD_BuildColDone:
    inc  eax
    jmp  KBD_BuildRow
KBD_BuildDone:

    ; ---- Second building (extra density) --------------------
    mov  eax, 70
    call RandomRange
    add  eax, 15
    mov  objRow, eax
    mov  eax, 100
    call RandomRange
    add  eax, 20
    mov  objCol, eax
    mov  eax, 6
    call RandomRange
    add  eax, 3
    mov  objH, eax
    mov  eax, 12
    call RandomRange
    add  eax, 4
    mov  objW, eax

    mov  eax, objRow
KBD_Build2Row:
    mov  edx, objRow
    add  edx, objH
    cmp  eax, edx
    jge  KBD_Build2Done
    cmp  eax, MAZE_ROWS - 1
    jge  KBD_Build2Done
    mov  edi, objCol
    mov  ecx, objW
KBD_Build2Col:
    cmp  edi, MAZE_COLS - 1
    jge  KBD_Build2ColDone
    MAZE_INDEX eax, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST
    je   KBD_Build2Skip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  KBD_Build2Skip
    mov  BYTE PTR maze[esi], CELL_BUILDING
KBD_Build2Skip:
    inc  edi
    loop KBD_Build2Col
KBD_Build2ColDone:
    inc  eax
    jmp  KBD_Build2Row
KBD_Build2Done:

    ; ---- Lake 1 -- diamond, random ---------------------------
    mov  eax, 60
    call RandomRange
    add  eax, 15
    mov  objRow, eax
    mov  eax, 100
    call RandomRange
    add  eax, 15
    mov  objCol, eax
    mov  eax, 4
    call RandomRange
    add  eax, 6
    mov  objLen, eax
    call PlaceDiamondLake

    ; ---- Lake 2 -- extra lake (EXTRA_LAKES=2 total extra) ----
    mov  eax, 60
    call RandomRange
    add  eax, 20
    mov  objRow, eax
    mov  eax, 80
    call RandomRange
    add  eax, 30
    mov  objCol, eax
    mov  eax, 3
    call RandomRange
    add  eax, 5
    mov  objLen, eax
    call PlaceDiamondLake

    jmp  PMO_BothModes

    ; =========================================================
    ; RANDOM MODE -- objects near spawn (50,75) for demo
    ; =========================================================
PMO_RandomMode:

    ; ---- Horizontal wall near spawn -------------------------
    mov  eax, 5
    call RandomRange
    add  eax, 38
    mov  objRow, eax
    mov  eax, 15
    call RandomRange
    add  eax, 60
    mov  objCol, eax
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, 20
    call PlaceSingleHWall

    ; ---- Vertical wall near spawn ---------------------------
    mov  eax, 5
    call RandomRange
    add  eax, 88
    mov  objCol, eax
    mov  ebx, 40
    mov  edi, objCol
    mov  ecx, 20
    call PlaceSingleVWall

    ; ---- Second horizontal wall -----------------------------
    mov  eax, 5
    call RandomRange
    add  eax, 54
    mov  objRow, eax
    mov  eax, 10
    call RandomRange
    add  eax, 65
    mov  objCol, eax
    mov  ebx, objRow
    mov  edi, objCol
    mov  ecx, 18
    call PlaceSingleHWall


    ; ---- Building near spawn --------------------------------
    mov  ebx, 55
PMO_RndBuildRow:
    cmp  ebx, 61
    jge  PMO_RndBuildDone
    mov  edi, 58
    mov  ecx, 11
PMO_RndBuildCol:
    MAZE_INDEX ebx, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST
    je   PMO_RndBuildSkip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PMO_RndBuildSkip
    mov  BYTE PTR maze[esi], CELL_BUILDING
PMO_RndBuildSkip:
    inc  edi
    loop PMO_RndBuildCol
    inc  ebx
    jmp  PMO_RndBuildRow
PMO_RndBuildDone:

    ; ---- Second building (near different area) ---------------
    mov  ebx, 30
PMO_RndBuild2Row:
    cmp  ebx, 37
    jge  PMO_RndBuild2Done
    mov  edi, 80
    mov  ecx, 10
PMO_RndBuild2Col:
    MAZE_INDEX ebx, edi, esi
    cmp  BYTE PTR maze[esi], CELL_DEST
    je   PMO_RndB2Skip
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PMO_RndB2Skip
    mov  BYTE PTR maze[esi], CELL_BUILDING
PMO_RndB2Skip:
    inc  edi
    loop PMO_RndBuild2Col
    inc  ebx
    jmp  PMO_RndBuild2Row
PMO_RndBuild2Done:

    ; ---- Lake near spawn ------------------------------------
    mov  objRow, 44
    mov  objCol, 72
    mov  objLen, 7
    call PlaceDiamondLake

    ; ---- Second lake (different area) -----------------------
    mov  objRow, 30
    mov  objCol, 100
    mov  objLen, 6
    call PlaceDiamondLake

    ; ---- Fall through to shared coin/pit/gem placement ------

    ; =========================================================
    ; BOTH MODES: coins, pits, gems (always random, full maze)
    ; =========================================================
PMO_BothModes:

    ; ---- Random coins (COIN_COUNT=350 from ui.inc) ----------
    mov  ecx, COIN_COUNT
PMO_CoinLoop:
    push ecx
    mov  eax, 90
    call RandomRange
    add  eax, 5
    mov  ebx, eax
    mov  eax, 140
    call RandomRange
    add  eax, 5
    mov  ecx, eax
    mov  eax, ebx
    sub  eax, START_ROW
    imul eax, eax
    mov  edx, ecx
    sub  edx, START_COL
    imul edx, edx
    add  eax, edx
    cmp  eax, 9
    jl   PMO_CoinSkip
    MAZE_INDEX ebx, ecx, esi
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PMO_CoinSkip
    mov  BYTE PTR maze[esi], CELL_COIN
    pop  ecx
    loop PMO_CoinLoop
    jmp  PMO_PitsStart
PMO_CoinSkip:
    pop  ecx
    loop PMO_CoinLoop

PMO_PitsStart:
    ; ---- Random pits (PIT_COUNT=200) ------------------------
    mov  ecx, PIT_COUNT
PMO_PitLoop:
    push ecx
    mov  eax, 90
    call RandomRange
    add  eax, 5
    mov  ebx, eax
    mov  eax, 140
    call RandomRange
    add  eax, 5
    mov  ecx, eax
    mov  eax, ebx
    sub  eax, START_ROW
    imul eax, eax
    mov  edx, ecx
    sub  edx, START_COL
    imul edx, edx
    add  eax, edx
    cmp  eax, 25
    jl   PMO_PitSkip
    MAZE_INDEX ebx, ecx, esi
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PMO_PitSkip
    mov  BYTE PTR maze[esi], CELL_PIT
    pop  ecx
    loop PMO_PitLoop
    jmp  PMO_GemStart
PMO_PitSkip:
    pop  ecx
    loop PMO_PitLoop

PMO_GemStart:
    ; ---- Random gems (GEM_COUNT=180) ------------------------
    mov  ecx, GEM_COUNT
PMO_GemLoop:
    push ecx
    mov  eax, 90
    call RandomRange
    add  eax, 5
    mov  ebx, eax
    mov  eax, 140
    call RandomRange
    add  eax, 5
    mov  ecx, eax
    mov  eax, ebx
    sub  eax, START_ROW
    imul eax, eax
    mov  edx, ecx
    sub  edx, START_COL
    imul edx, edx
    add  eax, edx
    cmp  eax, 225
    jl   PMO_GemSkip
    MAZE_INDEX ebx, ecx, esi
    cmp  BYTE PTR maze[esi], CELL_EMPTY
    jne  PMO_GemSkip
    mov  BYTE PTR maze[esi], CELL_GEM
    pop  ecx
    loop PMO_GemLoop
    jmp  PMO_AllDone
PMO_GemSkip:
    pop  ecx
    loop PMO_GemLoop

PMO_AllDone:
    ret
PlaceMazeObjects ENDP

; ============================================================
; Procedure : ClearMsgRow
; Purpose   : Kept for backwards compatibility 
; ============================================================
ClearMsgRow PROC USES eax ecx edx
    ; No-op: side panel handles all messages now.
    ret
ClearMsgRow ENDP

; ============================================================
; Procedure : CheckStumble
; ============================================================
CheckStumble PROC USES eax

    cmp  prof.hasKey, KEY_PRESENT
    jne  StumbleDone

    mov  eax, STUMBLE_CHANCE
    call RandomRange

    cmp  eax, 0
    jne  StumbleDone

    mov  prof.hasKey, KEY_LOST

    ; SOUND: Loud alarming key drop sound
    INVOKE Beep, 800, SND_DUR_SHORT
    INVOKE Beep, 400, SND_DUR_SHORT
    INVOKE Beep, SND_KEY_DROP, SND_DUR_MED

    ; Add event to side panel log
    push eax
    push esi
    lea  esi, msgKeyDropped
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi
    pop  eax

StumbleDone:
    ret
CheckStumble ENDP

; ============================================================
; Procedure : LogTreasure
; ============================================================
LogTreasure PROC USES ebx edi

    mov  ebx, treasureCount
    cmp  ebx, MAX_TREASURES
    jge  LogTreasureDone

    push eax

    mov  eax, SIZEOF TREASURE_ENTRY
    imul eax, ebx
    lea  edi, treasureLog
    add  edi, eax

    pop  eax
    mov  [edi].TREASURE_ENTRY.itemType, al

    mov  eax, prof.posRow
    mov  [edi].TREASURE_ENTRY.itemRow, eax

    mov  eax, prof.posCol
    mov  [edi].TREASURE_ENTRY.itemCol, eax

    inc  treasureCount

LogTreasureDone:
    ret
LogTreasure ENDP

; ============================================================
; Procedure : HandlePostMove
; ============================================================
HandlePostMove PROC
    push eax
    push ebx
    push ecx
    push esi

    movzx ebx, al

    cmp  bl, 0FFh
    je   HPM_Done
    cmp  bl, CELL_WALL
    je   HPM_Done
    cmp  bl, CELL_BUILDING
    je   HPM_Done
    cmp  bl, CELL_LAKE
    je   HPM_Done

    cmp  bl, CELL_PIT
    jne  HPM_NotPit

    ; ── Pit event ────────────────────────────────────────────
    ; SOUND: Very loud descending death sound
    INVOKE Beep, 400, SND_DUR_SHORT
    INVOKE Beep, 200, SND_DUR_SHORT
    INVOKE Beep, SND_PIT, SND_DUR_LONG
    push esi
    lea  esi, msgPitFall
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi

    mov endReason, 0
    mov  gameOver, TRUE
    jmp  HPM_Done
HPM_NotPit:

    call CheckStumble

    ; ── Coin event ────────────────────────────────────────────
    cmp  bl, CELL_COIN
    jne  HPM_NotCoin
    inc  prof.wallet
    mov  al, CELL_COIN
    call LogTreasure
    MAZE_INDEX prof.posRow, prof.posCol, esi
    mov  BYTE PTR maze[esi], CELL_EMPTY

    ; SOUND: loud double-ping for coin
    INVOKE Beep, SND_COIN, SND_DUR_SHORT
    INVOKE Beep, 1500, SND_DUR_SHORT

    ; Build "Coin +1 W=NNN" string in fileBuf then log it
    push ebx
    push ecx
    lea  edi, fileBuf
    mov  BYTE PTR [edi],    'C'
    mov  BYTE PTR [edi+1],  'o'
    mov  BYTE PTR [edi+2],  'i'
    mov  BYTE PTR [edi+3],  'n'
    mov  BYTE PTR [edi+4],  ' '
    mov  BYTE PTR [edi+5],  'W'
    mov  BYTE PTR [edi+6],  '='
    ; write wallet value at offset 7
    mov  eax, prof.wallet
    lea  esi, numScratch
    call DWordToStr
    ; copy numScratch to fileBuf+7
    lea  esi, numScratch
    mov  edi, 7
EV_CoinCopy:
    mov  al, numScratch[edi - 7]
    cmp  al, 0
    je   EV_CoinDone
    mov  fileBuf[edi], al
    inc  edi
    jmp  EV_CoinCopy
EV_CoinDone:
    mov  fileBuf[edi], 0

    pop  ecx
    pop  ebx

    push esi
    lea  esi, fileBuf
    mov  eax, COL_PANEL_LCOIN
    call AddEventLog
    pop  esi

    jmp  HPM_Done
HPM_NotCoin:

    ; ── Gem event ─────────────────────────────────────────────
    cmp  bl, CELL_GEM
    jne  HPM_NotGem
    add  prof.wallet, GEM_VALUE
    mov  al, CELL_GEM
    call LogTreasure
    MAZE_INDEX prof.posRow, prof.posCol, esi
    mov  BYTE PTR maze[esi], CELL_EMPTY

    ; SOUND: loud triumphant ascending gem chime
    INVOKE Beep, 600, SND_DUR_SHORT
    INVOKE Beep, 900, SND_DUR_SHORT
    INVOKE Beep, 1200, SND_DUR_MED

    push ebx
    push ecx
    lea  edi, fileBuf
    mov  BYTE PTR [edi],   04h   ; ♦ gem diamond symbol
    mov  BYTE PTR [edi+1], 'G'
    mov  BYTE PTR [edi+2], 'e'
    mov  BYTE PTR [edi+3], 'm'
    mov  BYTE PTR [edi+4], ' '
    mov  BYTE PTR [edi+5], 'W'
    mov  BYTE PTR [edi+6], '='
    ; convert wallet value to string, then copy into fileBuf+7
    mov  eax, prof.wallet
    call DWordToStr
    lea  esi, numScratch
    mov  edi, 7
EV_GemCopy:
    mov  al, numScratch[edi - 7]
    cmp  al, 0
    je   EV_GemDone
    mov  fileBuf[edi], al
    inc  edi
    jmp  EV_GemCopy
EV_GemDone:
    mov  fileBuf[edi], 0

    pop  ecx
    pop  ebx

    push esi
    lea  esi, fileBuf
    mov  eax, COL_PANEL_LGEM
    call AddEventLog
    pop  esi

    jmp  HPM_Done
HPM_NotGem:

    ; ── Destination event ─────────────────────────────────────
    cmp  bl, CELL_DEST
    jne  HPM_Done
    cmp  prof.hasKey, KEY_PRESENT
    je   HPM_HasKey

    push esi
    lea  esi, msgDestNoKey
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi

    mov endReason, 2
    mov  gameOver, TRUE
    jmp  HPM_Done
HPM_HasKey:
    push esi
    lea  esi, msgDestKey
    mov  eax, COL_PANEL_OK
    call AddEventLog
    pop  esi

    ; SOUND: Loud triumphant success fanfare
    INVOKE Beep, 523, SND_DUR_SHORT
    INVOKE Beep, 659, SND_DUR_SHORT
    INVOKE Beep, 784, SND_DUR_SHORT
    INVOKE Beep, SND_SUCCESS, SND_DUR_LONG

    mov endReason, 1
    mov  gameOver, TRUE

HPM_Done:
    pop  esi
    pop  ecx
    pop  ebx
    pop  eax
    ret
HandlePostMove ENDP

; ============================================================
; Procedure : GetRandomDirection
; ============================================================
GetRandomDirection PROC

    mov  eax, 4
    call RandomRange

    cmp  eax, 0
    je   GRD_Up
    cmp  eax, 1
    je   GRD_Down
    cmp  eax, 2
    je   GRD_Left

    call MoveRight
    jmp  GRD_Done
GRD_Up:
    call MoveUp
    jmp  GRD_Done
GRD_Down:
    call MoveDown
    jmp  GRD_Done
GRD_Left:
    call MoveLeft

GRD_Done:
    ret
GetRandomDirection ENDP

; ============================================================
; Procedure : HandleKeyboardInput
; ============================================================
HandleKeyboardInput PROC

    call ReadKey

    cmp  al, KEY_ESC
    jne  HKI_NotEsc

    push esi
    lea  esi, msgEscQuit
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi

    mov endReason, 4
    mov  gameOver, TRUE
    mov  al, CELL_EMPTY
    jmp  HKI_Done
HKI_NotEsc:

    cmp  al, 'W'
    je   HKI_Up
    cmp  al, 'w'
    je   HKI_Up
    cmp  al, 'S'
    je   HKI_Down
    cmp  al, 's'
    je   HKI_Down
    cmp  al, 'A'
    je   HKI_Left
    cmp  al, 'a'
    je   HKI_Left
    cmp  al, 'D'
    je   HKI_Right
    cmp  al, 'd'
    je   HKI_Right

    cmp  al, 0
    jne  HKI_Unknown
    cmp  ah, KEY_UP
    je   HKI_Up
    cmp  ah, KEY_DOWN
    je   HKI_Down
    cmp  ah, KEY_LEFT
    je   HKI_Left
    cmp  ah, KEY_RIGHT
    je   HKI_Right

HKI_Unknown:
    mov  al, 0FFh
    jmp  HKI_Done

HKI_Up:
    call MoveUp
    jmp  HKI_Done
HKI_Down:
    call MoveDown
    jmp  HKI_Done
HKI_Left:
    call MoveLeft
    jmp  HKI_Done
HKI_Right:
    call MoveRight

HKI_Done:
    ret
HandleKeyboardInput ENDP

; ============================================================
; Procedure : WriteNumToFile
; ============================================================
WriteNumToFile PROC USES eax ebx ecx edx esi

    lea  esi, fileBuf
    mov  ebx, 10
    mov  ecx, 0

    cmp  eax, 0
    jne  WNF_DivLoop
    mov  BYTE PTR [esi], '0'
    mov  BYTE PTR [esi+1], 0Dh
    mov  BYTE PTR [esi+2], 0Ah
    mov  BYTE PTR [esi+3], 0

    mov  eax, fileHandle
    lea  edx, fileBuf
    mov  ecx, 3
    call WriteToFile
    jmp  WNF_Done

WNF_DivLoop:
    cmp  eax, 0
    je   WNF_BuildStr
    xor  edx, edx
    div  ebx
    push edx
    inc  ecx
    jmp  WNF_DivLoop

WNF_BuildStr:
    mov  esi, 0
WNF_PopLoop:
    cmp  ecx, 0
    je   WNF_Append
    pop  edx
    add  dl, '0'
    mov  fileBuf[esi], dl
    inc  esi
    dec  ecx
    jmp  WNF_PopLoop

WNF_Append:
    mov  fileBuf[esi],   0Dh
    mov  fileBuf[esi+1], 0Ah
    mov  fileBuf[esi+2], 0

    mov  eax, fileHandle
    lea  edx, fileBuf
    mov  ecx, esi
    add  ecx, 2
    call WriteToFile

WNF_Done:
    ret
WriteNumToFile ENDP

; ============================================================
; Procedure : WriteNumToFileRaw
; ============================================================
WriteNumToFileRaw PROC USES eax ebx ecx edx

    lea  esi, fileBuf
    mov  ebx, 10
    mov  ecx, 0

    cmp  eax, 0
    jne  WNFR_DivLoop
    mov  BYTE PTR [esi], '0'
    mov  BYTE PTR [esi+1], 0
    mov  eax, fileHandle
    lea  edx, fileBuf
    mov  ecx, 1
    call WriteToFile
    jmp  WNFR_Done

WNFR_DivLoop:
    cmp  eax, 0
    je   WNFR_Build
    xor  edx, edx
    div  ebx
    push edx
    inc  ecx
    jmp  WNFR_DivLoop

WNFR_Build:
    mov  esi, 0
WNFR_PopLoop:
    cmp  ecx, 0
    je   WNFR_Write
    pop  edx
    add  dl, '0'
    mov  fileBuf[esi], dl
    inc  esi
    dec  ecx
    jmp  WNFR_PopLoop

WNFR_Write:
    mov  fileBuf[esi], 0
    mov  eax, fileHandle
    lea  edx, fileBuf
    mov  ecx, esi
    call WriteToFile

WNFR_Done:
    ret
WriteNumToFileRaw ENDP

; ============================================================
; Procedure : WriteAdventureLog
; ============================================================
WriteAdventureLog PROC USES eax ebx ecx edx edi

    mov  edx, OFFSET fileName
    call CreateOutputFile
    mov  fileHandle, eax

    cmp  eax, 0FFFFFFFFh
    je   WAL_Done

    WRITE_FILE_STR fileHandle, fHdr
    WRITE_FILE_STR fileHandle, fDivider

    WRITE_FILE_STR fileHandle, fName

    lea  edi, prof.profName
    mov  ecx, NAME_LEN
    mov  al,  0
    repne scasb
    mov  eax, NAME_LEN
    sub  eax, ecx
    dec  eax

    mov  ebx, fileHandle
    mov  edx, OFFSET prof.profName
    mov  ecx, eax
    mov  eax, ebx
    call WriteToFile
    WRITE_FILE_STR fileHandle, fNewline

    WRITE_FILE_STR fileHandle, fSteps
    mov  eax, prof.stepCount
    call WriteNumToFile

    WRITE_FILE_STR fileHandle, fFinalPos
    mov  eax, prof.posRow
    call WriteNumToFileRaw
    WRITE_FILE_STR fileHandle, fFinalPosCol
    mov  eax, prof.posCol
    call WriteNumToFile

    WRITE_FILE_STR fileHandle, fCoins
    mov  eax, prof.wallet
    call WriteNumToFile

    WRITE_FILE_STR fileHandle, fKey
    cmp  prof.hasKey, KEY_PRESENT
    je   WAL_KeyKept
    WRITE_FILE_STR fileHandle, fKeyLost
    jmp  WAL_AfterKey
WAL_KeyKept:
    WRITE_FILE_STR fileHandle, fKeyKept
WAL_AfterKey:

    WRITE_FILE_STR fileHandle, fTreasHeader

    cmp  treasureCount, 0
    jne  WAL_TreasLoop
    WRITE_FILE_STR fileHandle, fTreasNone
    jmp  WAL_AfterTreas

WAL_TreasLoop:
    mov  ebx, 0
    mov  ecx, treasureCount

WAL_TreasNext:
movzx eax, [edi].TREASURE_ENTRY.itemType
cmp  eax, CELL_GEM
je   WAL_WriteGem
WRITE_FILE_STR fileHandle, fTreasItem
jmp  WAL_WriteTreasRow
WAL_WriteGem:
    WRITE_FILE_STR fileHandle, fTreasGem
WAL_WriteTreasRow:
mov  eax, [edi].TREASURE_ENTRY.itemRow
call WriteNumToFileRaw
WRITE_FILE_STR fileHandle, fTreasComma
mov  eax, [edi].TREASURE_ENTRY.itemCol
call WriteNumToFile

WAL_AfterTreas:

    WRITE_FILE_STR fileHandle, fResult
    movzx eax, endReason

    cmp  eax, 0
    je   WAL_Pit
    cmp  eax, 1
    je   WAL_DestKey
    cmp  eax, 2
    je   WAL_DestNoKey
    cmp  eax, 3
    je   WAL_MaxSteps
    WRITE_FILE_STR fileHandle, fQuit
    jmp  WAL_Footer

WAL_Pit:
    WRITE_FILE_STR fileHandle, fPit
    jmp  WAL_Footer
WAL_DestKey:
    WRITE_FILE_STR fileHandle, fHasKey
    jmp  WAL_Footer
WAL_DestNoKey:
    WRITE_FILE_STR fileHandle, fNoKey
    jmp  WAL_Footer
WAL_MaxSteps:
    WRITE_FILE_STR fileHandle, fMaxSteps

WAL_Footer:
    WRITE_FILE_STR fileHandle, fDivider

    mov  eax, fileHandle
    call CloseFile

WAL_Done:
    ret
WriteAdventureLog ENDP

; ============================================================
; Procedure : DrawWelcomeScreen
; Purpose   : Displays the colorful instructions window.
;             Theme matches main menu: magenta/gold/white.
;             Centered box, cols 2..75 (width 74 inner 72).
; ============================================================
DrawWelcomeScreen PROC USES eax ecx edx

    call Clrscr

    ; ── Title banner row 0 (bright yellow on black) ───────────
    mov  eax, 0Eh
    call SetTextColor

    mov  dh, 0
    mov  dl, 0
    call Gotoxy
    ; Fill row 0 with spaces
    mov  ecx, 78
DWS_TitleFill:
    mov  al, ' '
    call WriteChar
    loop DWS_TitleFill

    mov  dh, 0
    mov  dl, 8
    call Gotoxy
    mov  edx, OFFSET wTitleLine
    call WriteString

    ; ── Subtitle row 1 ────────────────────────────────────────
    mov  eax, 0Dh            ; bright magenta
    call SetTextColor
    mov  dh, 1
    mov  dl, 16
    call Gotoxy
    mov  edx, OFFSET wSubTitle
    call WriteString

    ; ── Box top border (row 2), cols 2..75 ───────────────────
    mov  eax, 0Dh            ; magenta border
    call SetTextColor
    mov  dh, 2
    mov  dl, 2
    call Gotoxy
    mov  al, UI_TOPLEFT
    call WriteChar
    mov  ecx, 72
DWS_TopH:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_TopH
    mov  al, UI_TOPRIGHT
    call WriteChar

    ; ── OBJECTIVE section header (row 3) ──────────────────────
    mov  eax, 0Dh
    call SetTextColor
    mov  dh, 3
    mov  dl, 2
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  eax, 0Eh            ; yellow header text
    call SetTextColor
    mov  edx, OFFSET wHdrObjective
    call WriteString
    mov  eax, 0Dh
    call SetTextColor
    mov  ecx, 61
DWS_ObjSep:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_ObjSep
    mov  al, UI_T_LEFT
    call WriteChar

    ; Objective lines (rows 4..6)
    mov  eax, 0Fh
    call SetTextColor
    mov  dh, 4
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wObj1
    call WriteString

    mov  dh, 5
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wObj2
    call WriteString

    mov  dh, 6
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wObj3
    call WriteString

    ; ── RULES section header (row 7) ─────────────────────────
    mov  eax, 0Dh
    call SetTextColor
    mov  dh, 7
    mov  dl, 2
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET wHdrRules
    call WriteString
    mov  eax, 0Dh
    call SetTextColor
    mov  ecx, 63
DWS_RulSep:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_RulSep
    mov  al, UI_T_LEFT
    call WriteChar

    ; Rule lines (rows 8..13)
    mov  eax, 0Fh
    call SetTextColor
    mov  dh, 8
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule1
    call WriteString

    mov  dh, 9
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule2
    call WriteString

    mov  dh, 10
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule3
    call WriteString

    mov  dh, 11
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule4
    call WriteString

    mov  dh, 12
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule5
    call WriteString

    mov  dh, 13
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wRule6
    call WriteString

    ; ── MAP KEY section header (row 14) ──────────────────────
    mov  eax, 0Dh
    call SetTextColor
    mov  dh, 14
    mov  dl, 2
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET wHdrCells
    call WriteString
    mov  eax, 0Dh
    call SetTextColor
    mov  ecx, 63
DWS_CellSep:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_CellSep
    mov  al, UI_T_LEFT
    call WriteChar

    ; Cell lines (rows 15..22) with coloured symbols
    mov  dh, 15
    mov  dl, 4
    call Gotoxy
    mov  eax, 07h
    call SetTextColor
    mov  al, CHAR_WALL_U
    call WriteChar
    mov  eax, 0Fh
    call SetTextColor
    mov  edx, OFFSET wCell1 + 1
    call WriteString

    mov  dh, 16
    mov  dl, 4
    call Gotoxy
    mov  eax, COLOR_BUILDING
    call SetTextColor
    mov  al, CHAR_BUILD_U
    call WriteChar
    mov  eax, 0Fh
    call SetTextColor
    mov  edx, OFFSET wCell2 + 1
    call WriteString

    mov  dh, 17
    mov  dl, 4
    call Gotoxy
    mov  eax, 09h
    call SetTextColor
    mov  al, CHAR_LAKE_U
    call WriteChar
    mov  eax, 0Fh
    call SetTextColor
    mov  edx, OFFSET wCell3 + 1
    call WriteString

    mov  dh, 18
    mov  dl, 4
    call Gotoxy
    mov  eax, 0Ch
    call SetTextColor
    mov  al, CHAR_PIT_U
    call WriteChar
    mov  eax, 0Ch
    call SetTextColor
    mov  edx, OFFSET wCell4 + 1
    call WriteString

    mov  dh, 19
    mov  dl, 4
    call Gotoxy
    mov  eax, COLOR_COIN
    call SetTextColor
    mov  al, CHAR_COIN_U
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET wCell5 + 1
    call WriteString

    mov  dh, 20
    mov  dl, 4
    call Gotoxy
    mov  eax, COLOR_GEM
    call SetTextColor
    mov  al, CHAR_GEM_U
    call WriteChar
    mov  eax, 0Dh
    call SetTextColor
    mov  edx, OFFSET wCell6 + 1
    call WriteString

    mov  dh, 21
    mov  dl, 4
    call Gotoxy
    mov  eax, COLOR_DEST
    call SetTextColor
    mov  al, CHAR_DEST_U
    call WriteChar
    mov  eax, 0Ah
    call SetTextColor
    mov  edx, OFFSET wCell7 + 1
    call WriteString

    mov  dh, 22
    mov  dl, 4
    call Gotoxy
    mov  eax, COLOR_PROF
    call SetTextColor
    mov  al, CHAR_PROF_U
    call WriteChar
    mov  eax, 0Bh
    call SetTextColor
    mov  edx, OFFSET wCell8 + 1
    call WriteString

    ; ── CONTROLS section header (row 23) ─────────────────────
    mov  eax, 0Dh
    call SetTextColor
    mov  dh, 23
    mov  dl, 2
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET wHdrControls
    call WriteString
    mov  eax, 0Dh
    call SetTextColor
    mov  ecx, 63
DWS_CtrlSep:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_CtrlSep
    mov  al, UI_T_LEFT
    call WriteChar

    mov  eax, 0Fh
    call SetTextColor
    mov  dh, 24
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wCtrl1
    call WriteString

    mov  eax, 0Ah
    call SetTextColor
    mov  dh, 25
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wCtrl2
    call WriteString

    mov  dh, 26
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wCtrl3
    call WriteString

    mov  eax, 0Ch
    call SetTextColor
    mov  dh, 27
    mov  dl, 4
    call Gotoxy
    mov  edx, OFFSET wCtrl4
    call WriteString

    ; ── Box bottom border (row 28) ────────────────────────────
    mov  eax, 0Dh
    call SetTextColor
    mov  dh, 28
    mov  dl, 2
    call Gotoxy
    mov  al, UI_BOTLEFT
    call WriteChar
    mov  ecx, 72
DWS_BotH:
    mov  al, UI_HLINE
    call WriteChar
    loop DWS_BotH
    mov  al, UI_BOTRIGHT
    call WriteChar

    ; ── Prompt ────────────────────────────────────────────────
    mov  eax, 0Eh
    call SetTextColor
    mov  dh, 29
    mov  dl, 20
    call Gotoxy
    mov  edx, OFFSET msgPressKey
    call WriteString

    mov  eax, COLOR_EMPTY
    call SetTextColor

    call WaitMsg

    ret
DrawWelcomeScreen ENDP

; ============================================================
; Procedure : GameLoop
; ============================================================
GameLoop PROC USES eax

GL_Top:
    mov  eax, prof.stepCount
    cmp  eax, stepLimit
    jl   GL_StepOK

    push esi
    lea  esi, msgMaxSteps
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi

    mov  endReason, 3
    jmp  GL_End

GL_StepOK:
    cmp  gameOver, TRUE
    je   GL_End

    mov  al, prof.moveMode
    cmp  al, MODE_RANDOM
    je   GL_Random

    call HandleKeyboardInput
    call HandlePostMove
    call AnimateStep
    jmp  GL_Top

GL_Random:
    mov  eax, prof.stepCount
    mov  ecx, 2
    xor  edx, edx
    div  ecx              ; edx = stepCount mod 20
    cmp  edx, 0
    jne  GL_RndNoEscCheck

    ; Check if a key is queued -- use Irvine32 ReadKey with a trick:
    ; We call WaitMsg-style via a raw Win32 approach.
    ; Since we can't do non-blocking easily, we only check every 20 steps
    ; and only if the user already pressed a key (rely on console buffer).
    ; Use: call ReadKey, check if AL == ESC, else ignore.
    ; To avoid full block, we skip this on step 0 (initial spawn).
    cmp  prof.stepCount, 0
    je   GL_RndNoEscCheck

    ; ReadKey is blocking BUT the random mode runs fast (50ms per step)
    ; so we accept a brief pause every 20 steps (1 second) for ESC check.
    ; Players can press ESC and it will be caught at the next 20-step mark.
    call ReadKey
    cmp  al, KEY_ESC
    jne  GL_RndNoEscCheck

    ; ESC pressed
    push esi
    lea  esi, msgEscQuit
    mov  eax, COL_PANEL_LWRN
    call AddEventLog
    pop  esi
    mov  endReason, 4
    mov  gameOver, TRUE
    jmp  GL_End

GL_RndNoEscCheck:
    call GetRandomDirection
    call HandlePostMove
    call AnimateStep
    DELAY_MS  10
    jmp  GL_Top

GL_End:
    ; ── Show result in side panel (reuse the stats area) ─────
    call DrawSidePanel

    ; Display result message in the event log area prominently
    cmp  endReason, 1
    je   GL_ShowSuccess

    ; Game over (pit/no-key/max steps/quit)
    push esi
    lea  esi, msgVisGameOver
    mov  eax, COL_PANEL_BAD
    call AddEventLog
    pop  esi

    jmp  GL_FinalWait

GL_ShowSuccess:
    push esi
    lea  esi, msgVisSuccess
    mov  eax, COL_PANEL_OK
    call AddEventLog
    pop  esi

GL_FinalWait:
    ; Move cursor safely below maze/panel area
    mov  dh, PANEL_ROW_BOT
    mov  dl, 0
    call Gotoxy

    mov  eax, COLOR_EMPTY
    call SetTextColor

    call WaitMsg

    call Clrscr
    call WriteAdventureLog

    ret
GameLoop ENDP


; ============================================================
; Procedure : DrawMenuBoxH
; Purpose   : Helper -- draws a horizontal line of UI_HLINE
;             chars, ECX = count. Caller sets cursor + color.
; ============================================================
DrawMenuBoxH PROC USES eax ecx
DMB_Loop:
    mov  al, UI_HLINE
    call WriteChar
    loop DMB_Loop
    ret
DrawMenuBoxH ENDP

; ============================================================
; Procedure : DrawMainMenu
; Purpose   : Displays the main menu screen with ASCII art
;             title, tagline, and 6 mode-selection options.
;             Theme: dark magenta/gold on black.
; Returns   : AL = character typed ('1'..'6')
; ============================================================
DrawMainMenu PROC USES ebx ecx edx

    call Clrscr

    ; ── ASCII art banner (bright magenta) ─────────────────────
    mov  eax, 0Dh            ; bright magenta
    call SetTextColor

    mov  dh, 2
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban1
    call WriteString

    mov  dh, 3
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban2
    call WriteString

    mov  dh, 4
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban3
    call WriteString

    mov  dh, 5
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban4
    call WriteString

    mov  dh, 6
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban5
    call WriteString

    ; ── Game title line (bright yellow) ───────────────────────
    mov  eax, 0Eh            ; bright yellow
    call SetTextColor

    mov  dh, 8
    mov  dl, 24
    call Gotoxy
    mov  edx, OFFSET mnInfo1
    call WriteString

    ; ── Maze size line (bright cyan) ──────────────────────────
    mov  eax, 0Bh
    call SetTextColor
    mov  dh, 9
    mov  dl, 30
    call Gotoxy
    mov  edx, OFFSET mnMazeInfo
    call WriteString

    ; ── Description lines (bright white) ──────────────────────
    mov  eax, 0Fh
    call SetTextColor
    mov  dh, 11
    mov  dl, 7
    call Gotoxy
    mov  edx, OFFSET mnDesc1
    call WriteString

    mov  dh, 12
    mov  dl, 12
    call Gotoxy
    mov  edx, OFFSET mnDesc2
    call WriteString

    ; ── Menu options box (bright magenta border) ───────────────
    mov  eax, 0Dh            ; bright magenta border
    call SetTextColor

    ; Top border -- col 18, width 58
    mov  dh, 14
    mov  dl, 18
    call Gotoxy
    mov  al, UI_TOPLEFT
    call WriteChar
    mov  ecx, 56
    call DrawMenuBoxH
    mov  al, UI_TOPRIGHT
    call WriteChar

    ; ── Row 1: Option 1 and Option 5 ──────────────────────────
    mov  dh, 15
    mov  dl, 18
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  eax, 0Ah            ; bright green options
    call SetTextColor
    mov  edx, OFFSET mnOpt1
    call WriteString
    ; pad between opts (opt1=34chars, opt5=15chars, total inner=56-2=54)
    ; "1. Start Manual Mode - Fixed Steps" = 34, "5. Instructions" = 15
    ; spaces needed: 54 - 2 - 34 - 15 = 3
    mov  ecx, 3
DMM_P1:
    mov  al, ' '
    call WriteChar
    loop DMM_P1
    mov  edx, OFFSET mnOpt5
    call WriteString
    mov  ecx, 2
DMM_P1b:
    mov  al, ' '
    call WriteChar
    loop DMM_P1b
    mov  eax, 0Dh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Row 2: Option 2 and Option 6 ──────────────────────────
    mov  dh, 16
    mov  dl, 18
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  eax, 0Ah
    call SetTextColor
    mov  edx, OFFSET mnOpt2
    call WriteString
    ; "2. Start Manual Mode - Endless" = 30, "6. Exit" = 7
    ; 54 - 2 - 30 - 7 = 15
    mov  ecx, 15
DMM_P2:
    mov  al, ' '
    call WriteChar
    loop DMM_P2
    mov  edx, OFFSET mnOpt6
    call WriteString
    mov  ecx, 2
DMM_P2b:
    mov  al, ' '
    call WriteChar
    loop DMM_P2b
    mov  eax, 0Dh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Separator ─────────────────────────────────────────────
    mov  dh, 17
    mov  dl, 18
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  ecx, 56
    call DrawMenuBoxH
    mov  al, UI_T_LEFT
    call WriteChar

    ; ── Row 3: Option 3 ───────────────────────────────────────
    mov  dh, 18
    mov  dl, 18
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  eax, 0Eh            ; yellow for random mode
    call SetTextColor
    mov  edx, OFFSET mnOpt3
    call WriteString
    ; "3. Start Random Mode - Fixed Steps" = 34, pad = 54-2-34 = 18
    mov  ecx, 18
DMM_P3:
    mov  al, ' '
    call WriteChar
    loop DMM_P3
    mov  eax, 0Dh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Row 4: Option 4 ───────────────────────────────────────
    mov  dh, 19
    mov  dl, 18
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET mnOpt4
    call WriteString
    ; "4. Start Random Mode - Endless" = 30, pad = 54-2-30 = 22
    mov  ecx, 22
DMM_P4:
    mov  al, ' '
    call WriteChar
    loop DMM_P4
    mov  eax, 0Dh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Bottom border ─────────────────────────────────────────
    mov  dh, 20
    mov  dl, 18
    call Gotoxy
    mov  al, UI_BOTLEFT
    call WriteChar
    mov  ecx, 56
    call DrawMenuBoxH
    mov  al, UI_BOTRIGHT
    call WriteChar

    ; ── Prompt ────────────────────────────────────────────────
    mov  eax, 0Eh            ; bright yellow
    call SetTextColor
    mov  dh, 22
    mov  dl, 26
    call Gotoxy
    mov  edx, OFFSET mnPrompt
    call WriteString

    mov  eax, 0Fh            ; bright white for input
    call SetTextColor

    ; Play menu beep
    INVOKE Beep, SND_MENU, SND_DUR_SHORT

    ; Read user choice
    call ReadChar
    push eax
    call WriteChar

    ; Reset color
    mov  eax, COLOR_EMPTY
    call SetTextColor

    pop  eax
    ret
DrawMainMenu ENDP

; ============================================================
; Procedure : DrawResultsScreen
; Purpose   : Displays a bordered results screen after game ends.
;             Fixed-width box — all rows pad to column 62
;             before printing the right border.
; ============================================================
DrawResultsScreen PROC USES eax ebx ecx edx

    call Clrscr

    ; ── ASCII art banner (yellow) ─────────────────────────────
    mov  eax, 0Eh
    call SetTextColor

    mov  dh, 1
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban1
    call WriteString

    mov  dh, 2
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban2
    call WriteString

    mov  dh, 3
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban3
    call WriteString

    mov  dh, 4
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban4
    call WriteString

    mov  dh, 5
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban5
    call WriteString

    ; ── Box top border ────────────────────────────────────────
    mov  eax, 0Bh
    call SetTextColor
    mov  dh, 7
    mov  dl, 12
    call Gotoxy
    mov  al, UI_TOPLEFT
    call WriteChar
    mov  ecx, 50
    call DrawMenuBoxH
    mov  al, UI_TOPRIGHT
    call WriteChar

    ; ── Title row ─────────────────────────────────────────────
    mov  dh, 8
    mov  dl, 12
    call Gotoxy
    mov  al, UI_VLINE
    call WriteChar
    mov  eax, 0Eh
    call SetTextColor
    mov  dh, 8
    mov  dl, 13
    call Gotoxy
    mov  edx, OFFSET rsTitle
    call WriteString
    ; pad to col 62 then draw right border
    mov  dh, 8
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Separator ─────────────────────────────────────────────
    mov  dh, 9
    mov  dl, 12
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  ecx, 50
    call DrawMenuBoxH
    mov  al, UI_T_LEFT
    call WriteChar

    ; ── Professor name row ────────────────────────────────────
    mov  dh, 10
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsNameLbl
    call WriteString
    mov  eax, 0Fh
    call SetTextColor
    lea  edx, prof.profName
    call WriteString
    ; jump to fixed col for right border
    mov  dh, 10
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Mode row ──────────────────────────────────────────────
    mov  dh, 11
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsModeLbl
    call WriteString
    mov  eax, 0Fh
    call SetTextColor
    movzx eax, gameMode
    cmp  eax, 1
    je   DRS_M1
    cmp  eax, 2
    je   DRS_M2
    cmp  eax, 3
    je   DRS_M3
    mov  edx, OFFSET rsRndEndl
    jmp  DRS_MA
DRS_M1:
    mov  edx, OFFSET rsManFixed
    jmp  DRS_MA
DRS_M2:
    mov  edx, OFFSET rsManEndl
    jmp  DRS_MA
DRS_M3:
    mov  edx, OFFSET rsRndFixed
DRS_MA:
    call WriteString
    mov  dh, 11
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Result reason row ─────────────────────────────────────
    mov  dh, 13
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsReason
    call WriteString

    movzx eax, endReason
    cmp  eax, 0
    je   DRS_R0
    cmp  eax, 1
    je   DRS_R1
    cmp  eax, 2
    je   DRS_R2
    cmp  eax, 3
    je   DRS_R3
    mov  eax, 0Ch
    call SetTextColor
    mov  edx, OFFSET rsQuit
    jmp  DRS_RA
DRS_R0:
    mov  eax, 0Ch
    call SetTextColor
    mov  edx, OFFSET rsPit
    jmp  DRS_RA
DRS_R1:
    mov  eax, 0Ah
    call SetTextColor
    mov  edx, OFFSET rsSuccess
    jmp  DRS_RA
DRS_R2:
    mov  eax, 0Ch
    call SetTextColor
    mov  edx, OFFSET rsNoKey
    jmp  DRS_RA
DRS_R3:
    mov  eax, 0Eh
    call SetTextColor
    mov  edx, OFFSET rsMaxStep
DRS_RA:
    call WriteString
    mov  dh, 13
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Separator ─────────────────────────────────────────────
    mov  dh, 14
    mov  dl, 12
    call Gotoxy
    mov  al, UI_T_RIGHT
    call WriteChar
    mov  ecx, 50
    call DrawMenuBoxH
    mov  al, UI_T_LEFT
    call WriteChar

    ; ── Steps row ─────────────────────────────────────────────
    mov  dh, 15
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsSteps
    call WriteString
    mov  eax, 0Fh
    call SetTextColor
    mov  eax, prof.stepCount
    call WriteDec
    mov  dh, 15
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Coins row ─────────────────────────────────────────────
    mov  dh, 16
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsCoins
    call WriteString
    mov  eax, 0Eh
    call SetTextColor
    mov  eax, prof.wallet
    call WriteDec
    mov  dh, 16
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Key row ───────────────────────────────────────────────
    mov  dh, 17
    mov  dl, 12
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  edx, OFFSET rsKeyLbl
    call WriteString
    cmp  prof.hasKey, KEY_PRESENT
    je   DRS_KY
    mov  eax, 0Ch
    call SetTextColor
    mov  edx, OFFSET rsLost
    jmp  DRS_KA
DRS_KY:
    mov  eax, 0Ah
    call SetTextColor
    mov  edx, OFFSET rsHeld
DRS_KA:
    call WriteString
    mov  dh, 17
    mov  dl, 62
    call Gotoxy
    mov  eax, 0Bh
    call SetTextColor
    mov  al, UI_VLINE
    call WriteChar

    ; ── Bottom border ─────────────────────────────────────────
    mov  dh, 18
    mov  dl, 12
    call Gotoxy
    mov  al, UI_BOTLEFT
    call WriteChar
    mov  ecx, 50
    call DrawMenuBoxH
    mov  al, UI_BOTRIGHT
    call WriteChar

    ; ── Press any key prompt ──────────────────────────────────
    mov  eax, 0Eh
    call SetTextColor
    mov  dh, 20
    mov  dl, 16
    call Gotoxy
    mov  edx, OFFSET rsRetMenu
    call WriteString

    ; Reset color and wait — use ReadChar not WaitMsg
    ; WaitMsg prints its own "Press any key" which causes double line
    mov  eax, COLOR_EMPTY
    call SetTextColor
    call ReadChar               ; silent wait — no extra message printed

    ret
DrawResultsScreen ENDP

; ============================================================
; main PROC -- Menu loop
; ============================================================
main PROC

    call Randomize

MainMenuLoop:
    call DrawMainMenu
    ; AL = character typed

    cmp  al, '6'
    je   MN_Exit
    cmp  al, '5'
    je   MN_Instructions
    cmp  al, '1'
    je   MN_Mode1
    cmp  al, '2'
    je   MN_Mode2
    cmp  al, '3'
    je   MN_Mode3
    cmp  al, '4'
    je   MN_Mode4
    ; Invalid option -- redisplay menu
    jmp  MainMenuLoop

MN_Instructions:
    call DrawWelcomeScreen
    jmp  MainMenuLoop

MN_Mode1:
    mov  prof.moveMode, MODE_KEYBOARD
    mov  gameMode, 1
    mov  stepLimit, FIXED_STEP_LIM
    jmp  MN_StartGame

MN_Mode2:
    mov  prof.moveMode, MODE_KEYBOARD
    mov  gameMode, 2
    mov  stepLimit, MAX_STEPS
    jmp  MN_StartGame

MN_Mode3:
    mov  prof.moveMode, MODE_RANDOM
    mov  gameMode, 3
    mov  stepLimit, FIXED_STEP_LIM
    jmp  MN_StartGame

MN_Mode4:
    mov  prof.moveMode, MODE_RANDOM
    mov  gameMode, 4
    mov  stepLimit, MAX_STEPS
    jmp  MN_StartGame

MN_StartGame:
    ; ── Ask for professor name ────────────────────────────────
    call Clrscr

    mov  eax, 0Eh
    call SetTextColor
    mov  dh, 1
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban1
    call WriteString

    mov  dh, 2
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban2
    call WriteString

    mov  dh, 3
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban3
    call WriteString

    mov  dh, 4
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban4
    call WriteString

    mov  dh, 5
    mov  dl, 10
    call Gotoxy
    mov  edx, OFFSET ban5
    call WriteString

    mov  eax, 0Bh
    call SetTextColor
    mov  dh, 8
    mov  dl, 15
    call Gotoxy
    PRINT_MSG msgEnterName

    mov  eax, 0Fh
    call SetTextColor
    mov  edx, OFFSET nameBuffer
    mov  ecx, NAME_LEN - 1
    call ReadString

    ; ── Reset game state and start ────────────────────────────
    mov  gameOver, FALSE
    mov  endReason, 0
    mov  pathCount, 0
    mov  treasureCount, 0

    call InitProfessor
    call InitMaze
    call PlaceMazeObjects
    call InitVisual
    call GameLoop

    ; ── Show results screen ───────────────────────────────────
    call DrawResultsScreen

    ; Return to main menu
    jmp  MainMenuLoop

MN_Exit:
    mov  eax, COLOR_EMPTY
    call SetTextColor
    call Clrscr
    exit
main ENDP
END main