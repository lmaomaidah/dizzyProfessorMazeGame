; ============================================================
; File    : dizzy_walk_macros.inc
; Purpose : Reusable macros to reduce boilerplate throughout
;           the Dizzy Walk project. Requires Irvine32.inc.
; ============================================================

; ------------------------------------------------------------
; PRINT_MSG  msg
; Prints a null-terminated string stored in .data
; Usage: PRINT_MSG myString
; ------------------------------------------------------------
PRINT_MSG MACRO msg
    push edx
    mov  edx, OFFSET msg
    call WriteString
    pop  edx
ENDM

; ------------------------------------------------------------
; PRINT_STR  reg
; Prints a null-terminated string whose address is in a register
; Usage: PRINT_STR edx  (edx already holds address)
; ------------------------------------------------------------

; ------------------------------------------------------------
; PRINT_NUM  reg
; Prints an unsigned 32-bit integer from a register
; Usage: PRINT_NUM eax
; ------------------------------------------------------------
PRINT_NUM MACRO reg
    push eax
    mov  eax, reg
    call WriteDec
    pop  eax
ENDM

; ------------------------------------------------------------
; PRINT_CHAR  ch
; Prints a single ASCII character (immediate or AL)
; Usage: PRINT_CHAR '$'
; ------------------------------------------------------------

; ------------------------------------------------------------
; NEWLINE
; Prints carriage return + line feed
; ------------------------------------------------------------
NEWLINE MACRO
    push edx
    push eax
    mov  al, 0Dh
    call WriteChar
    mov  al, 0Ah
    call WriteChar
    pop  eax
    pop  edx
ENDM

; ------------------------------------------------------------
; GOTO_XY  col, row
; Positions console cursor. col=X, row=Y (Irvine convention)
; Both arguments must be BYTE-sized immediates or memory bytes
; Usage: GOTO_XY 10, 5
; ------------------------------------------------------------

; ------------------------------------------------------------
; SET_COLOR  color
; Sets Irvine console text+background color
; Usage: SET_COLOR COLOR_COIN
; ------------------------------------------------------------

; ------------------------------------------------------------
; DELAY_MS  ms
; Pauses execution for given milliseconds
; Usage: DELAY_MS 200
; ------------------------------------------------------------
DELAY_MS MACRO ms
    push eax
    mov  eax, ms
    call Delay
    pop  eax
ENDM

; ------------------------------------------------------------
; BEEP_SOUND  freq, dur
; Plays a beep (freq in Hz, dur in ms)
; Usage: BEEP_SOUND 800, 150
; ------------------------------------------------------------

; ------------------------------------------------------------
; MAZE_INDEX  row, col, dest
; Computes flat index: dest = row * MAZE_COLS + col
; Places result in dest register (typically ESI or EDI)
; Clobbers: EAX, EDX (saved internally)
; Usage: MAZE_INDEX ebx, ecx, esi
; ------------------------------------------------------------
MAZE_INDEX MACRO row, col, dest
    push eax
    push edx
    mov  eax, row
    mov  edx, MAZE_COLS
    imul edx
    add  eax, col
    mov  dest, eax
    pop  edx
    pop  eax
ENDM

; ------------------------------------------------------------
; SAVE_REGS / RESTORE_REGS
; Convenience wrappers for saving common caller-saved registers
; Usage: SAVE_REGS at start of proc body, RESTORE_REGS before ret
; ------------------------------------------------------------

; ------------------------------------------------------------
; WRITE_FILE_STR  handle_var, str_label
; Writes a null-terminated string to an open file.
; Computes length via SCASB scan. Clobbers EAX,ECX,EDI.
; Usage: WRITE_FILE_STR fileHandle, fName
; ------------------------------------------------------------
WRITE_FILE_STR MACRO handle_var, str_label
    push eax
    push ecx
    push edx
    push edi

    ; Compute string length (scan for null terminator)
    lea  edi, str_label
    mov  ecx, 256
    mov  al,  0
    repne scasb
    sub  edi, OFFSET str_label
    dec  edi                    ; EDI = length (excluding null)

    ; Write to file
    mov  eax, handle_var
    lea  edx, str_label
    mov  ecx, edi
    call WriteToFile

    pop  edi
    pop  edx
    pop  ecx
    pop  eax
ENDM