/*
    Bouncing ball demo

    Copyright (c) 2020-2023 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
    - Morten Moen, mmo@itema.no
    - Arve Moen, amo@itema.no
    - Bjørn Leithe Karlsen, bka@itema.no
*/

* = $c000 "Main Program"

// import our sprite library
#import "library/libSprite.asm"
#import "library/libInput.asm"
#import "library/libScreen.asm"
#import "library/font.asm"

BasicUpstart2(initialize)


.var music = LoadSid("music/Nightshift.sid")      //<- Here we load the sid file
.var demo_mode_movement_timer = $0

// Initialize
initialize:
    jsr $e544               // Clear screen

    lda #$06                // Set the background color for the game area
    sta $d021
    lda #$00                // Set the background color for the border
    sta $d020

    lda #%11000011          // Enable sprites
    sta $d015

    lda #%00111110          // Specify multicolor for the ball sprites
    sta $d01c
    lda #$01                // Color white
    sta $d025               // Set shared multicolor #1
    lda #$00                // Color black
    sta $d026               // Set shared multicolor #2

    lda #$00                // Disable xpand-y
    sta $d017

    lda #$00                // Set sprite/background priority
    sta $d01b



    lda #$00                // Disable xpand-x
    sta $d01d

    lda #$0a                // Set sprite #1 individual color
    sta $d027
    lda #$0c                // Set sprite #2 individual color
    sta $d028

    lda #paddleSpriteData/64
    sta $07f8               // Sprite #0
    lda #ballSpriteData/64
    sta $07f9               // Sprite #1
    sta $07fa               // Sprite #2
    /*
    sta $07fb               // Sprite #3
    sta $07fc               // Sprite #4
    sta $07fd               // Sprite #5
    */

// Itema Logo Sprites //
    lda #itemaLogoSwoosh/64
    sta $07fe               // Sprite #6
    lda #itemaLogoBall/64
    sta $07ff               // Sprite #7

/*
    Draw Itema Logo
*/

    // Set MSB for sprite 7 and 7
    lda $d010
    ora #%11000000
    sta $d010

    // Position both sprites overlapping
    lda #$02
    sta $d00c
    sta $d00e
    lda #$d7
    sta $d00d
    sta $d00f

    // Set colors
    lda #$0f
    sta $d02d
    lda #$0a
    sta $d02e


/*
    Set character set pointer to our custom set, turn off
    multicolor for characters
*/

lda $d018
ora #%00001110 // Set chars location to $3800 for displaying the custom font
sta $d018      // Bits 1-3 ($0400 + 512 .bytes * low nibble value) of $D018 sets char location
               // $400 + $200*$0E = $3800
lda $d016      // turn off multicolor for characters
and #%11101111 // by clearing bit #4 of $D016
sta $d016

/*
    Initialize IRQ
*/
jsr init_irq

/*
    Load the initial screen
    $4500 - intro screen
    $4d00 - level 1
*/
lda #$4d
sta $ff
lda #$00
sta $fe
jsr load_screen

/*
    Main loop
*/
loop:
jmp loop

demo_input:
    lda $d012
    eor $dc04
    sbc $dc05       // Get a pseudo random number from CIA timers
    and #$0F
    cmp #$08
    bcc isSmaller
    sbc #$08
    isSmaller:
    sta temp
    lda SpriteMem+9
    sbc #$06        // Adjust for ball radius
    adc temp
    jsr store_xl    // Store the paddle x-position
    rts

paddle_input:
    lda $dc00       // Load value from CIA#1 Data Port A (pot lines are input)
    and #%11111110  // Set bit 0 to input for pot x (paddle 1)
    sta $dc00       // Store the result back to Data Port A

    lda $dc01       // Load value from CIA#1 Data Port B (keyboard lines)
    and #%11110111  // Clear bit 3 to low (selects pot x)
    sta $dc01       // Store the result back to Data Port B

    lda $d419       // Load value from Paddle X pot
    eor #$ff        // XOR with 255 to reverse the range

    // Update paddle position unless it is outside the playing area

    clc
    cmp #$1a        // Compare with the minimum value
    bcs piNotLess   // If carry is set (number >= minValue), branch to piNotLess
    lda #$1a        // If carry is clear (number < minValue), load the minimum value into the accumulator
    piNotLess:
    clc
    // Now check if the number is greater than the maximum value
    cmp #$ce        // Compare with the maximum value
    bcc piNotGreater// If carry is clear (number < maxValue), branch to piNotGreater
    lda #$ce        // If carry is set (number >= maxValue), load the maximum value into the accumulator
    piNotGreater:
    jsr store_xl    // Store the paddle x-position
    rts

init_irq:
    sei
    lda #<irq_1
    ldx #>irq_1
    sta $0314
    stx $0315       // Set interrupt addr
    lda #$7f
    sta $dc0d       // Timer A off on cia1/kb
    sta $dd0d       // Timer A off on cia2
    lda #$81
    sta $d01a       // Raster interrupts on
    /*
    lda #$1b        // Screen ctrl: default
    sta $d011
    */
    lda #$01
    sta $d012       // Interrupt at line 0

    lda $dc0d       // Clrflg (cia1)
    lda $dd0d       // Clrflg (cia2)
    asl $d019       // Clr interrupt flag (just in case)
    cli
    rts

irq_1:
    lda #$01
    sta SpriteIndex
    jsr paddle_input

    animation_loop:

        clc
        lda SpriteIndex
        cmp #$00
        beq move_paddle

        // Check if we should move the ball faster
        move_ball_accellerated:
            clc
            lda accelerated_movement_timer
            cmp #$1
            bcs accelerated_movement

        move_ball_normally:
            jsr move_vertically

        move_paddle:
            jsr move_horizontally
            jsr draw_sprite
            jsr check_collision
            jsr check_sprite_collision
            inc SpriteIndex
            lda SpriteIndex

        cmp #$02
        beq done
        jmp animation_loop
    done:
        asl $d019 // Clear interrupt flag
        jmp $ea81 // set flag and end

/*
    Add a little upwards acceleration for a period of time. This typically happens
    when the ball hits the paddle.
*/
accelerated_movement:
    dec accelerated_movement_timer
    lda accelerated_movement_timer
    cmp #$0
    beq end_accellerated_movement
    FRAME_COLOR(4)

    lda #$80                // -1
    jsr store_ya
    jmp move_ball_normally

    end_accellerated_movement:
        FRAME_COLOR(0)
        lda #$00
        jsr store_ya
    jmp move_ball_normally

// Intro screen
.var intro_background = LoadBinary("petscii/intro.bin")
*=$4500 "Intro"
.fill intro_background.getSize(), intro_background.get(i)
// Level 1
.var lvl1_background = LoadBinary("petscii/level_1.bin")
*=$4d00 "Level 1"
.fill lvl1_background.getSize(), lvl1_background.get(i)

// -- Sprite Data --------------------------------------------------------------
// Created using https://www.spritemate.com
* = $2140 "Ball Sprite Data"
ballSpriteData:
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,  40,   0
.byte   0, 154,   0
.byte   2, 106, 192
.byte   2, 170, 192
.byte   2, 170, 192
.byte   2, 170, 192
.byte   2, 171, 192
.byte   2, 171, 192
.byte   0, 175,   0
.byte   0,  60,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0
.byte   0,   0,   0

* = $2180 "Paddle Sprite Data"
paddleSpriteData:
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %11111111,%11111111,%11111111
.byte %11111111,%11111111,%11111111
.byte %11111111,%11111111,%11111111

* = $21c0 "itemaLogo"
itemaLogo:
.byte $00, $1C, $00
.byte $01, $BE, $C0
.byte $07, $BE, $70
.byte $0E, $1C, $38
.byte $1C, $00, $1C
.byte $38, $7C, $0C
.byte $38, $7C, $0E
.byte $70, $1C, $0E
.byte $70, $1C, $0E
.byte $70, $1C, $0E
.byte $F0, $1C, $0E
.byte $F0, $1C, $0E
.byte $70, $1C, $1C
.byte $70, $1C, $3C
.byte $78, $1C, $78
.byte $78, $1F, $E0
.byte $3C, $1F, $C0
.byte $1E, $1E, $00
.byte $0F, $00, $00
.byte $07, $C2, $00
.byte $00, $FC, $00

* = $2200 "itemaLogoSwoosh"
itemaLogoSwoosh:
.byte $00, $00, $00
.byte $01, $C1, $C0
.byte $07, $80, $70
.byte $0E, $00, $38
.byte $1C, $00, $1C
.byte $38, $7C, $0C
.byte $38, $7C, $0E
.byte $70, $1C, $0E
.byte $70, $1C, $0E
.byte $70, $1C, $0E
.byte $F0, $1C, $0E
.byte $F0, $1C, $0E
.byte $70, $1C, $1C
.byte $70, $1C, $3C
.byte $78, $1C, $78
.byte $78, $1F, $E0
.byte $3C, $1F, $C0
.byte $1E, $1E, $00
.byte $0F, $00, $00
.byte $07, $C2, $00
.byte $00, $FC, $00

* = $2240 "itemaLogoSwoosh"
itemaLogoBall:
.byte $00, $1C, $00
.byte $00, $3E, $00
.byte $00, $3E, $00
.byte $00, $1C, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
.byte $00, $00, $00
