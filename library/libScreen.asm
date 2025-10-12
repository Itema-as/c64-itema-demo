/*
     24px                                                     343px
     ←------------------------------------------------------------→
┌────────────────────────────────────────────────────────────────────────┐ 0
│                                 Border                                 │ |
│   ┌──────────────────────────────────────────────────────────────┐     │ 23px
│   │                                                              │     │
│   │   **** COMMODORE 64 BASIC V2 ****                            │     │
│   │   64K RAM SYSTEM  38911 BASIC BYTES FREE                     │     │
│   │   READY.                                                     │     │
│   │                                                              │     │
│   │                                                              │     │
│   │                                                              │     │
│   │                                                              │     │
│   │                                                              │     │
│   └──────────────────────────────────────────────────────────────┘     │ 230
│                                                                        │ |
└────────────────────────────────────────────────────────────────────────┘ 255px
0---23px                                                           344---511px

*/

#importonce
#import "libDefines.asm"
#import "libGame.asm"

wScreenRAMRowStart: // SCREENRAM + 40*0, 40*1, 40*2, 40*3, 40*4 ... 40*24
    .word SCREENRAM,     SCREENRAM+40,  SCREENRAM+80,  SCREENRAM+120, SCREENRAM+160
    .word SCREENRAM+200, SCREENRAM+240, SCREENRAM+280, SCREENRAM+320, SCREENRAM+360
    .word SCREENRAM+400, SCREENRAM+440, SCREENRAM+480, SCREENRAM+520, SCREENRAM+560
    .word SCREENRAM+600, SCREENRAM+640, SCREENRAM+680, SCREENRAM+720, SCREENRAM+760
    .word SCREENRAM+800, SCREENRAM+840, SCREENRAM+880, SCREENRAM+920, SCREENRAM+960

wColorRAMRowStart: // COLORRAM + 40*0, 40*1, 40*2, 40*3, 40*4 ... 40*24
    .word COLORRAM,     COLORRAM+40,  COLORRAM+80,  COLORRAM+120, COLORRAM+160
    .word COLORRAM+200, COLORRAM+240, COLORRAM+280, COLORRAM+320, COLORRAM+360
    .word COLORRAM+400, COLORRAM+440, COLORRAM+480, COLORRAM+520, COLORRAM+560
    .word COLORRAM+600, COLORRAM+640, COLORRAM+680, COLORRAM+720, COLORRAM+760
    .word COLORRAM+800, COLORRAM+840, COLORRAM+880, COLORRAM+920, COLORRAM+960

.const HUDScoreColumn0              = 35
.const HUDScoreColumn1              = 36
.const HUDScoreColumn2              = 37
.const HUDScoreColumn3              = 38
.const HUDRow                       = 5
.const TIMED_TEXT_START             = SCREENRAM + (40*12) + 8
.const TIMED_TEXT_COLOR_START       = COLORRAM + (40*12) + 8
.const TIMED_TEXT_WIDTH             = 9
.const TIMED_TEXT_PATTERN_COUNT     = 16

.const MEMCP_SRCVECT = $f7
.const MEMCP_DSTVECT = MEMCP_SRCVECT + 2
.const MEMCP_CNTVECT = MEMCP_DSTVECT + 2
.macro MEMCOPY(src, dst)
{
// NB! The vector for index indirect addressing is little-endian

    lda #<src                   // Store src address to src vector in zero-page
    sta MEMCP_SRCVECT
    lda #>src
    sta MEMCP_SRCVECT + 1

    lda #<dst                   // Store dst address to dst vector in zero-page
    sta MEMCP_DSTVECT           // The vector for index indirect addressing is
    lda #>dst                   // little-endian
    sta MEMCP_DSTVECT + 1

    ldx #$00
    ldy #$00
memcp_loop:
    lda (MEMCP_SRCVECT),y
    cmp #$ff
    beq memcp_out
    sta (MEMCP_DSTVECT),y
    iny
    cpy #$00                    // If Y has wrapped, go to next page
    beq memcp_nextpage
    jmp memcp_loop
memcp_nextpage:
    inc MEMCP_SRCVECT + 1
    inc MEMCP_DSTVECT + 1
    jmp memcp_loop
memcp_out:
}

/*
    Load a screen from the address prepared in  in zeropage
    $fe – lowest byte
    $ff - highest byte
 */
load_screen:
    sei                         // Deactive the interrupt of become confused
    // Start with the characters
    lda #$00
    sta MEMCP_DSTVECT
    lda $fe 
    sta MEMCP_SRCVECT
    lda #$04
    sta MEMCP_DSTVECT+1
    lda $ff 
    sta MEMCP_SRCVECT+1
    lda #$00
    sta MEMCP_CNTVECT           // Initialize low byte of counter
    sta MEMCP_CNTVECT+1         // Initialize high byte of counter

    jsr copy_loop

    // Now do the colours
    lda $fe                     // Load the low byte of the pointer
    clc                         // Clear carry flag before addition
    adc #$e8                    // Add the LSB for modification
    sta MEMCP_SRCVECT

    lda $ff                     // Load the high byte of the pointer
    adc #$03                    // Add the MSB for modification
    bcc noCarry                 // Branch if no carry from the first addition
    adc #$01                    // Add the carry from the first addition
    
    noCarry:
        sta MEMCP_SRCVECT+1

    // Set the destination to colour memory at $d800
    lda #$00
    sta MEMCP_DSTVECT
    lda #$d8
    sta MEMCP_DSTVECT+1
    lda #$00
    sta MEMCP_CNTVECT           // Initialize low byte of counter
    sta MEMCP_CNTVECT+1         // Initialize high byte of counter

copy_loop:
    ldy MEMCP_CNTVECT           // Load low byte of counter into Y

    lda (MEMCP_SRCVECT),Y       // Load byte from source address + Y into A
    sta (MEMCP_DSTVECT),Y       // Store byte from A at target address + Y

    inc MEMCP_CNTVECT           // Increment low byte of counter
    bne check_counter
    inc MEMCP_CNTVECT+1         // If low byte overflowed, increment high byte

check_counter:
    lda MEMCP_CNTVECT
    cmp #$e8                    // Check if low byte of counter has reached 0xe8
    bne continue_loop

    lda MEMCP_CNTVECT+1
    cmp #$03                    // Check if high byte of counter has reached 0x03
    bne continue_loop

    jmp end_loop                // If we've copied 1000 bytes, end the loop

continue_loop:
    iny  // Increment Y
    bne copy_loop
    inc MEMCP_SRCVECT+1         // If Y overflowed, increment high byte of source address
    inc MEMCP_DSTVECT+1         // If Y overflowed, increment high byte of target address
    jmp copy_loop               // Jump back to the start of the loop

    end_loop:
    iny
    lda (MEMCP_SRCVECT),y       // The last byte is the number of bricks in the level (not always correct)
    sta BrickCount
    iny
    lda (MEMCP_SRCVECT),y
    sta StartingXPosition
    iny
    lda (MEMCP_SRCVECT),y
    sta StartingYPosition
    jsr calculate_brick_count
rts

calculate_brick_count:
    lda #$00
    sta MEMCP_CNTVECT
    sta MEMCP_CNTVECT+1
    lda #<SCREENRAM
    sta MEMCP_SRCVECT
    lda #>SCREENRAM+160         // Ignore the first four rows
    sta MEMCP_SRCVECT+1
    lda #$00
    sta BrickCount

calculate_brick_count_loop:
    ldy MEMCP_CNTVECT
    lda (MEMCP_SRCVECT),y
    cmp #$80                    // First normal game brick
    bcc calculate_brick_count_skip
    cmp #$e0                    // Last normal game brick is at $df
    bcs calculate_brick_count_skip
    and #%00000001
    bne calculate_brick_count_skip
    inc BrickCount

calculate_brick_count_skip:
    inc MEMCP_CNTVECT
    bne calculate_brick_count_check_end
    inc MEMCP_SRCVECT+1
    inc MEMCP_CNTVECT+1

calculate_brick_count_check_end:
    lda MEMCP_CNTVECT
    cmp #$80
    bne calculate_brick_count_loop
    lda MEMCP_CNTVECT+1
    cmp #$02                    // No need to do the last 6-rows
    bne calculate_brick_count_loop
rts

gameUpdateScore:
    // -------- 1st digit (thousands) --------
    lda wHudScore+1
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn0, HUDRow, ZeroPage9)
    // -------- 2nd digit (hundreds) --------
    lda wHudScore+1
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn1, HUDRow, ZeroPage9)
    // -------- 3rd digit (tens) --------
    lda wHudScore
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn2, HUDRow, ZeroPage9)
    // -------- 4th digit (units) --------
    lda wHudScore
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn3, HUDRow, ZeroPage9)
    rts

gameUpdateHighScore:
    // -------- 1st digit (thousands) --------
    lda wHudHiScore+1
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn0, HUDRow+2, ZeroPage9)
    // -------- 2nd digit (hundreds) --------
    lda wHudHiScore+1
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn1, HUDRow+2, ZeroPage9)
    // -------- 3rd digit (tens) --------
    lda wHudHiScore
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn2, HUDRow+2, ZeroPage9)
    // -------- 4th digit (units) --------
    lda wHudHiScore
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn3, HUDRow+2, ZeroPage9)
    rts

gameUpdateLives:
    // -------- 1st digit --------
    lda wHudLives+1
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn1, HUDRow+4, ZeroPage9)
    // -------- 2nd digit --------
    lda wHudLives
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn2, HUDRow+4, ZeroPage9)
    // -------- 3rd digit --------
    lda wHudLives
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn3, HUDRow+4, ZeroPage9)
    rts

gameUpdateBricks:
    LIBMATH_8BITTOBCD_AA(BrickCount,wHudBricks)
    // -------- 1st digit --------
    lda wHudBricks+1
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn1, 0, ZeroPage9)
    // -------- 2nd digit --------
    lda wHudBricks
    and #%11110000
    lsr
    lsr
    lsr
    lsr
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn2, 0, ZeroPage9)
    // -------- 3rd digit --------
    lda wHudBricks
    and #%00001111
    ora #$30 
    sta ZeroPage9
    LIBSCREEN_SETCHARACTER_S_VVA(HUDScoreColumn3, 0, ZeroPage9)
    rts

.macro LIBSCREEN_SETCHARACTER_S_VVA(bXPos, bYPos, bChar)
{
    lda #bXPos
    sta ZeroPage4
    lda #bYPos
    sta ZeroPage2
    lda bChar
    sta ZeroPage3
    jsr libScreenSetCharacter
}

libScreenSetCharacter:
    lda ZeroPage2               // load y position as index into list
    asl                         // X2 as table is in words
    tay                         // Copy A to Y
    lda wScreenRAMRowStart,Y    // load low address byte
    sta ZeroPage9
    lda wScreenRAMRowStart+1,Y  // load high address byte
    sta ZeroPage10
    ldy ZeroPage4               // load x position into Y register
    lda ZeroPage3
    sta (ZeroPage9),Y
    rts

/*******************************************************************************
 TIMED TEXT DISPLAY
*******************************************************************************/

textTimer:                 // Countdown timer for the temp text
    .byte $00
textColorPhase:            // Phase counter for the pulsing colour effect
    .byte $00
getReadyBackupChars:        // The original characters under the temp text
    .fill 25, $00
getReadyBackupColors:       // The original colours under the temp text
    .fill 25, $00

.macro LIBSCREEN_TIMED_TEXT(text){
    lda #TEXT_TIMER
    sta textTimer
    lda #$00
    sta textColorPhase
    ldx #$17
    jsr save_loop
    MEMCOPY(text, SCREENRAM + (40*12) + 8)
    jsr timed_text_apply_color
}

/*
    Save the characters and the colours for the area under the temporarily 
    displayed text. Only the actual game area is covered, excluding the frame
    (23 characters).
*/
save_loop:
    lda SCREENRAM + (40*12) + 1,x
    sta getReadyBackupChars,x
    lda COLORRAM + (40*12) + 1,x
    sta getReadyBackupColors,x
    dex
    bpl save_loop
    rts

clear_timed_text:
    ldx #$17

restore_loop:
    lda getReadyBackupChars,x
    sta SCREENRAM + (40*12) + 1,x
    lda getReadyBackupColors,x
    sta COLORRAM + (40*12) + 1,x
    dex
    bpl restore_loop
    lda #$00
    sta textColorPhase
    rts

timed_text_update_colors:
    lda textColorPhase
    clc
    adc #$01
    cmp #TIMED_TEXT_PATTERN_COUNT
    bcc timed_text_store_phase
    lda #$00
timed_text_store_phase:
    sta textColorPhase
timed_text_apply_color:
    lda textColorPhase
    tay
    lda timedTextPhaseOffsets,y
    tay
    ldx #$00
timed_text_color_loop:
    lda timedTextColorPatterns,y
    sta TIMED_TEXT_COLOR_START,x
    iny
    inx
    cpx #TIMED_TEXT_WIDTH
    bcc timed_text_color_loop
    rts

timedTextPhaseOffsets:
    .byte $00,$09,$12,$1b,$24,$2d,$36,$3f,$48,$51,$5a,$63,$6c,$75,$7e,$87

timedTextColorPatterns:
    // phase 0
    .byte $01,$0d,$0b,$0f,$0b,$0d,$01,$03,$0b
    // phase 1
    .byte $0d,$0b,$0f,$0b,$0d,$01,$03,$0b,$07
    // phase 2
    .byte $0b,$0f,$0b,$0d,$01,$03,$0b,$07,$0b
    // phase 3
    .byte $0f,$0b,$0d,$01,$03,$0b,$07,$0b,$03
    // phase 4
    .byte $0b,$0d,$01,$03,$0b,$07,$0b,$03,$01
    // phase 5
    .byte $0d,$01,$03,$0b,$07,$0b,$03,$01,$0d
    // phase 6
    .byte $01,$03,$0b,$07,$0b,$03,$01,$0d,$0b
    // phase 7
    .byte $03,$0b,$07,$0b,$03,$01,$0d,$0b,$0f
    // phase 8
    .byte $0b,$07,$0b,$03,$01,$0d,$0b,$0f,$01
    // phase 9
    .byte $07,$0b,$03,$01,$0d,$0b,$0f,$01,$0d
    // phase 10
    .byte $0b,$03,$01,$0d,$0b,$0f,$01,$0d,$0b
    // phase 11
    .byte $03,$01,$0d,$0b,$0f,$01,$0d,$0b,$0f
    // phase 12
    .byte $01,$0d,$0b,$0f,$01,$0d,$0b,$0f,$0b
    // phase 13
    .byte $0d,$0b,$0f,$01,$0d,$0b,$0f,$0b,$0d
    // phase 14
    .byte $0b,$0f,$01,$0d,$0b,$0f,$0b,$0d,$01
    // phase 15
    .byte $0f,$01,$0d,$0b,$0f,$0b,$0d,$01,$03
