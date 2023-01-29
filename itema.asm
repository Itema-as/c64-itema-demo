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
#import "libSprite.asm"
#import "libInput.asm"
#import "libScreen.asm"
#import "screens.asm"

BasicUpstart2(initialize)

.var music = LoadSid("music/Nightshift.sid")      //<- Here we load the sid file

// Initialize
initialize:
    jsr $e544               // Clear screen

    lda #$06                // Set the background color
    sta $d021
    sta $d020

    //lda #$17                // Activate character set 2
    //sta $d018

    lda #%00000011          // Enable sprites
    sta $d015

    lda #$00                // Disable xpand-y
    sta $d017

    lda #$00                // Set sprite/background priority
    sta $d01b
    
//  lda #$ff                // enable multicolor
//  sta $d01c
    
    lda #$00                // Disable xpand-x
    sta $d01d
    
//  lda #$0f                // set sprite multicolor 1
//  sta $d025
//  lda #$0c                // set sprite multicolor 2
//  sta $d026
    lda #$0a                // Set sprite individual color
    sta $d027
    lda #$0a                // Set sprite individual color
    sta $d028
    
    lda #paddleSpriteData/64
    sta $07f8
    lda #ballSpriteData/64  // Sprite #1
    sta $07f9

//    sta $07fa               // Sprite #3
//    sta $07fb               // Sprite #4
//    sta $07fc               // Sprite #5
//    sta $07fd               // Sprite #6
//    sta $07fe               // Sprite #7
//    sta $07ff               // Sprite #8

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
    Print the first level from the second line from the top
*/
MEMCOPY(background, $0400)
MEMCOPY(colormap, $d800)
//PRINT_SCREEN(level_1, $04f0)
//PRINT_SCREEN(title, $0400)

// Initialize SID-chip
lda #$FF  // maximum frequency value
sta $D40E // voice 3 frequency low byte
sta $D40F // voice 3 frequency high byte
lda #$80  // noise waveform, gate bit off
sta $D412 // voice 3 control register

/*
    Initialize IRQ
*/
jsr init_irq

loop:
jmp loop

/*
    The player sprite is a bit special. It is pretty much uncontrollable when
    having to be controlled by acceleration, it is just to slow to change
    direction with low acceleration, and unwieldy with high acceleration, so
    instead we control the velocity directly.
*/
player_input:
    // Reset velocity on both axis
    lda #$00
    jsr store_xv
    jsr store_yv

    // Set acceleration according to joystick input
    LIBINPUT_GET(GameportLeftMask)
        bne inputRight
//        jsr get_xm
//        cmp #$01
//        beq inputLeft_cont
        jsr get_xl
        cmp #$20
        bcc inputRight
        inputLeft_cont:
        lda #$bf
        //lda #$ef
        jsr store_xv
    inputRight:
        LIBINPUT_GET(GameportRightMask)
        bne inputUp
//        jsr get_xm
//        cmp #$01
//        bne inputRight_cont
        jsr get_xl
        cmp #ScreenRightEdge-14
        bcs inputUp
        inputRight_cont:
        lda #$60
        jsr store_xv
    inputUp:
        LIBINPUT_GET(GameportUpMask)
        bne inputDown  
        lda #$00
        jsr store_yv
    inputDown:
        LIBINPUT_GET(GameportDownMask)
        bne inputFire
        lda #$00
        jsr store_yv
    inputFire:
        lda #$00
        sta fire
        LIBINPUT_GET(GameportFireMask)
        bne inputEnd
        lda #$80
        sta fire
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
    lda #$00
    sta SpriteIndex
    jsr player_input
    animation_loop:
        /*
        lda #$00            // since we don't want the paddle to be controlled
        jsr store_xa        // by accelleration of any kind, including gravity,
        jsr store_ya        // we reset the accelleration here
        */
        lda SpriteIndex
        cmp #$00
        beq move_ball        
        lda fire
        jsr store_ya
        jsr move_vertically

        move_ball:
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
    asl $d019
///    inc $d020
//    jsr music.play
//    dec $d020
//    dec $d020
    jmp $ea81 // set flag and end

*=music.location "Music"
.fill music.size, music.getData(i)              // <- Here we put the music in memory

// -- Sprite Data --------------------------------------------------------------
// Created using https://www.spritemate.com
* = $2140 "Ball Sprite Data"
ballSpriteData:
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

title:
.text "itema hackathon  -  fr[ya 2023"
.byte $ff

/*
level_1:
.text "                                        "
.text "  <><><><><><><><><>  <><><><><><><><>  "
.text "  <><><><><><><><><>  <><><><><><><><>  "
.text "                                        "
.text "  <><><><>  <><><><>  <><><>  <><><><>  "
.text "  <><><><>  <><><><>  <><><>  <><><><>  "
.byte $ff
*/

// Import character set. Use https://petscii.krissz.hu to edit
//* = $3800 "Custom Character Set"
//.import c64 "itema.64c"
