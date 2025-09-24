/*
    Sprite data library
    Copyright (c) 2020-2025 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
*/

#importonce

SpriteIndex:
    .byte $00

Static:
    .byte $00

.macro EmitSpriteTable() {
/*
          +------------------------------------ X-location least significant bits
          |    
          |    +-------------------------- Y-location least significant bits
          |    |    
          |    |    +---------------- X-velocity (signed integer)
          |    |    |    +----------- Y-velocity (signed integer)
          |    |    |    |    +------ X-acceleration (signed integer)
          |    |    |    |    |    +- Y-acceleration (signed integer)
          |    |    |    |    |    |    +- Various flags
          |    |    |    |    |    |    |  0 - collision with paddle
          |    |    |    |    |    |    |  1 - resting on top of paddle
          |    |    |    |    |    |    |    +- Animation frame number
          |    |    |    |    |    |    |    |    
          xl   yl   xv   yv   xa   ya   f    frame
*/
    .byte $73, $e0, $00, $00, $00, $00, $00, $00 // The player
    .byte $74, $60, $00, $00, $00, $00, $00, $00 // Ball 1
    .byte $48, $35, $00, $00, $00, $00, $00, $00 // Ball 2
    .byte $60, $3a, $00, $00, $00, $00, $00, $00 // Ball 3
    .fill 8*4, 0
}


SpriteMem:
    EmitSpriteTable()
// Make a copy of SpriteMem which we will use to restor all positions when
// restarting the game or going into demo mode.
BackupMem:
    EmitSpriteTable()

.const SpriteDataSize = 64  // Data structure size
.const  xl = 0              // Y-location LSB
.const  yl = 1              // Y-location LSB
.const  xv = 2              // X-velocity
.const  yv = 3              // Y-velocity
.const  xa = 4              // X-acceleration
.const  ya = 5              // Y-acceleration
.const  f  = 6              // Flags
.const  frame = 7           // Current animation frame
.const spritelen = 8        // The total number of bytes in the structure

.const MaxHorizontalVelocity = $70
.const MaxVerticalVelocity   = $70

ldx #0
stx SpriteIndex

get_flags:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #f                  // Add index to get fieldaddr
    jmp get_val


get_frame:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #frame              // Add index to get fieldaddr
    jmp get_val

get_xl:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xl                 // Add index to get fieldaddr
    jmp get_val

get_yl:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #yl                 // Add index to get fieldaddr
    jmp get_val

get_ya:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #ya                 // Add index to get fieldaddr
    jmp get_val

get_xa:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xa                 // Add index to get fieldaddr
    jmp get_val

get_xv:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xv                 // Add index to get fieldaddr
    jmp get_val

get_yv:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #yv                 // Add index to get fieldaddr

    // jmp get_val // next instr

get_val:
    tax                     // .A -> .X
    lda SpriteMem,x         // load fieldaddr -> .A
    plp
    rts

store_flags:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #f                  // Add index to get fieldaddr
    jmp store_val

store_frame:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #frame              // Add index to get fieldaddr
    jmp store_val

store_xl:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #xl                 // Add index to get fieldaddr
    jmp store_val

store_yl:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #yl                 // Add index to get fieldaddr
    jmp store_val

store_xa:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #xa                 // Add index to get fieldaddr
    jmp store_val

store_ya:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #ya                 // Add index to get fieldaddr
    jmp store_val

store_xv:
    php
    pha
    jsr should_clamp
    beq store_xv_skip_clamp
    pla
    jsr clamp_horizontal_velocity
    pha
store_xv_skip_clamp:
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #xv                 // Add index to get fieldaddr
    jmp store_val

store_yv:
    php
    pha
    jsr should_clamp
    beq store_yv_skip_clamp
    pla
    jsr clamp_vertical_velocity
    pha
store_yv_skip_clamp:
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #yv                 // Add index to get fieldaddr
    // jmp store_val        // -> next instr

store_val:
    tax                     // .A -> .X
    pla
    plp
    sta SpriteMem,x         // load fieldaddr -> .A
    rts

clamp_horizontal_velocity:
    bmi clamp_h_neg
    cmp #MaxHorizontalVelocity+1
    bcc clamp_h_done
    lda #MaxHorizontalVelocity
    rts

clamp_h_neg:
    pha
    eor #$ff
    clc
    adc #$01
    cmp #MaxHorizontalVelocity+1
    bcc clamp_h_keep
    pla
    lda #MaxHorizontalVelocity
    eor #$ff
    clc
    adc #$01
    rts

clamp_h_keep:
    pla
clamp_h_done:
    rts

clamp_vertical_velocity:
    bmi clamp_v_neg
    cmp #MaxVerticalVelocity+1
    bcc clamp_v_done
    lda #MaxVerticalVelocity
    rts

clamp_v_neg:
    pha
    eor #$ff
    clc
    adc #$01
    cmp #MaxVerticalVelocity+1
    bcc clamp_v_keep
    pla
    lda #MaxVerticalVelocity
    eor #$ff
    clc
    adc #$01
    //FRAME_COLOR(5)
    rts

clamp_v_keep:
    pla
clamp_v_done:
    rts

should_clamp:
    ldx SpriteIndex
    cpx #$01
    beq should_clamp_yes
    cpx #$02
    beq should_clamp_yes
    cpx #$03
    beq should_clamp_yes
    lda #$00
    rts

should_clamp_yes:
    lda #$01
    rts

// getspritebase -> .A  -- uses .X
getspritebase:
    ldx SpriteIndex
    lda #$00

    getspritebase_loop:
        cpx #$00
        beq gotspritebase
        clc
        adc #spritelen
        dex
        jmp getspritebase_loop

    gotspritebase:
        rts
