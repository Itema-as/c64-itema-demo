/*
    Sprite data library
    Copyright (c) 2020 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
    - Morten Moen, mmo@itema.no
    - Arve Moen, amo@itema.no
    - Bjørn Leithe Karlsen, bka@itema.no
*/

#importonce

SpriteIndex:
    .byte $00

Static:
    .byte $00

SpriteMem:
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
          |    |    |    |    |    |    |    +- Animation frame
          |    |    |    |    |    |    |    |    
          xl   yl   xv   yv   xa   ya   f    frame
*/
    .byte $73, $e0, $00, $00, $00, $00, $00, $00    // Paddle (the player)
    .byte $74, $60, $00, $00, $00, $00, $00, $00    // Ball 1
    .byte $48, $35, $00, $00, $00, $00, $00, $00    // Ball 2
    .byte $60, $3a, $00, $00, $00, $00, $00, $00    // Ball 3
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00

.const  xl = 0              // Y-location LSB
.const  yl = 1              // Y-location LSB
.const  xv = 2              // X-velocity
.const  yv = 3              // Y-velocity
.const  xa = 4              // X-acceleration
.const  ya = 5              // Y-acceleration
.const  f  = 6              // Flags
.const  frame = 7           // Current animation frame
.const spritelen = 8

.var motionless = %00000000 // whether or not the sprite is allowed to move

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
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #xv                 // Add index to get fieldaddr
    jmp store_val

store_yv:
    php
    pha
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

