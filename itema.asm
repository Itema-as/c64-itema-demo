/*
    Bouncing ball demo

    Copyright (c) 2020-2022 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
    - Morten Moen, mmo@itema.no
    - Arve Moen, amo@itema.no
    - Bjørn Leithe Karlsen, bka@itema.no
*/

* = $c000 "Main Program"

// import our sprite library
#import "libSprite.asm"
#import "libInput.asm"
#import "libScreen.asm"

BasicUpstart2(initialize)

.var music = LoadSid("music/Nightshift.sid")      //<- Here we load the sid file

// Initialize
initialize:
    jsr $e544               // Clear screen

    lda #$17                // Activate character set 2
    sta $d018

    lda #%00000001          // Enable sprites
    sta $d015

    lda #$00                // Disable xpand-y
    sta $d017

    lda #$00                // Set sprite/background priority
    sta $d01b
    
//  lda #$ff            // enable multicolor
//  sta $d01c
    
    lda #$00                // Disable xpand-x
    sta $d01d
    
//  lda #$0f            // set sprite multicolor 1
//  sta $d025
//  lda #$0c            // set sprite multicolor 2
//  sta $d026
    lda #$0a                // Set sprite individual color
    sta $d027
    
    lda #spriteData/64      // Set sprite data pointer
    sta $07f8               // Sprite #1
    sta $07f9               // Sprite #2
    sta $07fa               // Sprite #3
    sta $07fb               // Sprite #4
    sta $07fc               // Sprite #5
    sta $07fd               // Sprite #6
    sta $07fe               // Sprite #7
    sta $07ff               // Sprite #8

/*
    Print the first level from the second line from the top
*/
PRINT_SCREEN(level_1, $0428)

/*
    Initialize IRQ
*/
jsr init_irq

loop:
jmp loop

player_input:
    // Reset acceleration on both axis
    lda #$00
    jsr store_xa
    jsr store_ya
    
    // Set acelleration according to joystick input
    LIBINPUT_GET(GameportLeftMask)
        bne inputRight
        lda #$ff
        jsr store_xa
    inputRight:
        LIBINPUT_GET(GameportRightMask)
        bne inputUp
        lda #$01
        jsr store_xa
    inputUp:
        LIBINPUT_GET(GameportUpMask)
        bne inputDown  
        lda #$f8
        jsr store_ya
    inputDown:
        LIBINPUT_GET(GameportDownMask)
        bne inputEnd
        lda #$01
        jsr store_ya
    inputEnd:   
        rts 

init_irq:

    lda #$00
    ldx #0
    ldy #0
    lda #music.startSong-1
    jsr music.init

    sei
    lda #<irq_1
    ldx #>irq_1
    sta $0314
    stx $0315               // Set interrupt addr    
    lda #$7f
    sta $dc0d               // Timer A off on cia1/kb
    sta $dd0d               // Timer A off on cia2

    lda #$81
    sta $d01a               // Raster interrupts on
    lda #$1b                // Screen ctrl: default
    sta $d011

    lda #$01
    sta $d012               // Interrupt at line 0

    lda $dc0d               // Clrflg (cia1)
    lda $dd0d               // Clrflg (cia2)
    asl $d019               // Clr interrupt flag (just in case)
    cli
    rts



irq_1:
    inc $d020
    lda #$00
    sta SpriteIndex
    animation_loop:
        jsr player_input
        jsr move_horizontally
        jsr move_vertically
        jsr draw_sprite
        jsr check_collision
        inc SpriteIndex
        lda SpriteIndex
        cmp #$01
        beq done
        jmp animation_loop
    done:
    asl $d019
    inc $d020
//    jsr music.play
    dec $d020
    dec $d020
    jmp $ea81 //; set flag and end

*=music.location "Music"
.fill music.size, music.getData(i)              // <- Here we put the music in memory

// -- Sprite Data --------------------------------------------------------------
// Created using https://www.spritemate.com
* = $2140 "Sprite Data"
spriteData:
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00011000,%00000000
.byte %00000000,%01111110,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000001,%11111111,%10000000
.byte %00000001,%11111111,%10000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%01111110,%00000000
.byte %00000000,%00011000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000

level_1:
.text "                                        "
.text "  ####################################  "
.text "  ####################################  "
.text "                                        "
.text "  ########      ########      ########  "
.text "  ########      ########      ########  "
.byte $ff

