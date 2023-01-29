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
          |    +------------------------------- X-location most significant bits
          |    |    +-------------------------- Y-location least significant bits
          |    |    |    +--------------------- Y-location most significant bits
          |    |    |    |    +---------------- X-velocity (signed integer)
          |    |    |    |    |    +----------- Y-velocity (signed integer)
          |    |    |    |    |    |    +------ X-acceleration (signed integer)
          |    |    |    |    |    |    |    +- Y-acceleration (signed integer)
          |    |    |    |    |    |    |    |    +- Various flags
          xl   xm   yl   ym   xv   yv   xa   ya   f
*/
    .byte $70, $00, $e0, $00, $00, $00, $00, $00, $00    // Paddle (bottom of screen)
    .byte $70, $00, $70, $00, $00, $00, $00, $00, $00    // Ball
    .byte $58, $00, $82, $00, $00, $00, $00, $00, $00
    .byte $18, $00, $62, $00, $00, $00, $00, $00, $00
    .byte $18, $00, $72, $00, $00, $00, $00, $00, $00
    .byte $18, $00, $82, $00, $00, $00, $00, $00, $00
    .byte $18, $00, $92, $00, $00, $00, $00, $00, $00
    .byte $18, $00, $a2, $00, $00, $00, $00, $00, $00

.var xl = 0                 // Y-location LSB
.var xm = 1                 // X-location MSB
.var yl = 2                 // Y-location LSB
.var ym = 3                 // X-location MSB
.var xv = 4                 // X-velocity
.var yv = 5                 // Y-velocity
.var xa = 6                 // X-acceleration
.var ya = 7                 // Y-acceleration
.var f  = 8                 // Flags
.var spritelen = 9

.var motionless = %00000000 // whether or not the sprite is allowed to move

ldx #0
stx SpriteIndex
jsr get_xm                  // xm for 0 in a

get_flags:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #f                  // Add index to get fieldaddr
    jmp get_val


get_xm:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xm                 // Add index to get fieldaddr
    jmp get_val

get_xl:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xl                 // Add index to get fieldaddr
    jmp get_val

get_ym:
    php
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #ym                 // Add index to get fieldaddr
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

store_xm:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc                     // Clear the carry flag
    adc #xm                 // Add index to get fieldaddr
    jmp store_val

store_xl:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #xl                 // Add index to get fieldaddr
    jmp store_val

store_ym:
    php
    pha
    jsr getspritebase       // Get spritebase in .A
    clc
    adc #ym                 // Add index to get fieldaddr
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

