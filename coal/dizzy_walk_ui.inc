; ============================================================
; File    : dizzy_walk_ui.inc
; Author  : Daud, Maidah, Hani | Roll: i240045, i242116, i242113
; Course  : Cyber Security - COAL Spring 2026, FAST NU
; Purpose : UI constants, colors, layout, and Unicode character
;           definitions for Dizzy Walk visual simulation.
; ============================================================

; ============================================================
; ─── UNICODE / CP437 DISPLAY CHARACTERS ─────────────────────
; ============================================================

; ─── Cell display chars (used in CellTypeToChar) ────────────

CHAR_WALL_U     EQU  0DBh   ; █  full block   — wall
CHAR_BUILD_U    EQU  0B2h   ; ▓  dark shade   — building
CHAR_LAKE_U     EQU  0F7h   ; ≈  approx       — lake/water
CHAR_PIT_U      EQU  0D7h   ; ×  multiply     — pit (danger)
CHAR_COIN_U     EQU  0F8h   ; °  degree       — coin
CHAR_DEST_U     EQU  0CEh   ; ╬  double cross — home/dest
CHAR_GEM_U      EQU  04h    ; ♦  diamond      — gem
CHAR_PROF_U     EQU  02h    ; ☺  smiley       — professor

; ─── Box-drawing chars (used in DrawPanelBorder, DrawWelcomeScreen) ──
UI_TOPLEFT      EQU  0DAh   ; ┌
UI_TOPRIGHT     EQU  0BFh   ; ┐
UI_BOTLEFT      EQU  0C0h   ; └
UI_BOTRIGHT     EQU  0D9h   ; ┘
UI_HLINE        EQU  0C4h   ; ─
UI_VLINE        EQU  0B3h   ; │
UI_T_RIGHT      EQU  0C3h   ; ├  tee pointing right (left wall junction)
UI_T_LEFT       EQU  0B4h   ; ┤  tee pointing left  (right wall junction)




; ─── Shading / block chars ───────────────────────────────────







; ─── Arrow chars ─────────────────────────────────────────────




; ============================================================
; ─── PANEL COLOR CONSTANTS ──────────────────────────────────
; Irvine32 color byte: high nibble = background, low = foreground
; ============================================================

; Side panel chrome
COL_PANEL_BOX   EQU  1Fh    ; bright white  on blue   — border lines
COL_PANEL_HDR   EQU  1Eh    ; bright yellow on blue   — section headers
COL_PANEL_BG    EQU  10h    ; black         on blue   — interior bg fill
COL_PANEL_LBL   EQU  1Bh    ; bright cyan   on blue   — field labels
COL_PANEL_VAL   EQU  1Fh    ; bright white  on blue   — field values
COL_PANEL_POS   EQU  1Bh    ; bright cyan   on blue   — position values
COL_PANEL_LOG   EQU  17h    ; bright white  on black  — old event lines
COL_PANEL_LCOIN EQU  0Eh    ; bright yellow on black  — coin event
COL_PANEL_LGEM  EQU  0Dh    ; bright magenta on black — gem event
COL_PANEL_LWRN  EQU  0Ch    ; bright red    on black  — warning event
COL_PANEL_OK    EQU  0Ah    ; bright green  on black  — success event
COL_PANEL_BAD   EQU  0Ch    ; bright red    on black  — game over

; Welcome screen colors
COL_TITLE_BG    EQU  1Eh    ; bright yellow on blue   — title banner
COL_BOX         EQU  1Bh    ; bright cyan   on blue   — box borders
COL_RULE_HDR    EQU  1Fh    ; bright white  on blue   — section headers
COL_RULE_TEXT   EQU  1Fh    ; bright white  on blue   — rule text
COL_RULE_KEY    EQU  1Ah    ; bright green  on blue   — key hints
COL_RULE_WARN   EQU  1Ch    ; bright red    on blue   — warning rules
COL_RULE_COIN   EQU  1Eh    ; bright yellow on blue   — coin/gem lines
COL_RULE_DEST   EQU  1Ah    ; bright green  on blue   — destination line
COL_PROMPT      EQU  0Bh    ; bright cyan   on black  — input prompts

; ============================================================
; ─── SIDE PANEL LAYOUT CONSTANTS ────────────────────────────
; The maze viewport occupies cols 0..77 (39 cells × 2 chars).
; The side panel occupies cols 80..99 (20 chars wide).
; Screen rows 0..21 hold the maze; the panel spans rows 0..N.
; ============================================================

PANEL_LEFT      EQU  80     ; leftmost column of panel box
PANEL_WIDTH     EQU  20     ; total width including borders
PANEL_TOP       EQU  0      ; top row of panel box
PANEL_HEIGHT    EQU  32     ; total height of panel box

; ── Row positions inside the panel (absolute screen rows) ───
PANEL_ROW_TITLE EQU  0      ; "DIZZY WALK" title
PANEL_ROW_NAME  EQU  1      ; Prof: <name>
PANEL_ROW_POS   EQU  2      ; Pos : R,C
PANEL_ROW_STEPS EQU  3      ; Step: N
PANEL_ROW_COINS EQU  4      ; Coin: N
PANEL_ROW_KEY   EQU  5      ; Key : YES/NO
PANEL_ROW_MODE  EQU  6      ; Mode: RND/KBD
PANEL_ROW_DEST  EQU  7      ; Dest: R,C  (optional, for info)

PANEL_ROW_LGND  EQU  9      ; "  LEGEND  " header
PANEL_ROW_L1    EQU  10     ; █ Wall    BLOCK
PANEL_ROW_L2    EQU  11     ; ▓ Building BLK
PANEL_ROW_L3    EQU  12     ; ≈ Lake    BLOCK
PANEL_ROW_L4    EQU  13     ; × Pit     FATAL
PANEL_ROW_L5    EQU  14     ; ° Coin    +1
PANEL_ROW_L6    EQU  15     ; ♦ Gem     +5
PANEL_ROW_L7    EQU  16     ; ╬ Home    GOAL

PANEL_ROW_DIV2  EQU  17     ; ├──────────────────┤  separator

PANEL_ROW_EVHDR EQU  18     ; "  EVENTS  " header
PANEL_ROW_EV0   EQU  19     ; newest event line
; PANEL_ROW_EV1 = 20, EV2 = 21 ... EV9 = 28

PANEL_ROW_BOT   EQU  30     ; safe row below panel for cursor park

; ── Event log dimensions ─────────────────────────────────────
EVLOG_MAX       EQU  10     ; number of event lines displayed
EVLOG_BUF_LEN   EQU  17     ; max chars per event line (fits panel)

; ============================================================
; ─── OBJECT DENSITY CONSTANTS ───────────────────────────────
; These override the values in dizzy_walk_structs.inc.
; Higher counts make the maze denser and more interesting.
; ============================================================
EXTRA_WALLS     EQU  30      ; additional random wall segments
