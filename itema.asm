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
 
.var music = LoadSid("../music/Calypso_Bar.sid")

* = $c000 "Main Program"

// import our sprite library
#import "library/libSprite.asm"
#import "library/libInput.asm"
#import "library/libScreen.asm"
#import "library/font.asm"
//#import "library/libMusic.asm"

// .watch wHudScore,,"store" 
//.watch ball_speed_up,,"store" 

BasicUpstart2(initialize)

.var BALLS = 1              // It gets slow at 4

.var demo_mode_movement_timer = $0


demo_mode:
    .byte %00000001
    
start_velocity:
    .byte $00
start_accelleration:
    .byte $00
start_x_position:
    .byte $74
start_y_position:
    .byte $60
ball_speed_up:
    .byte %00000000

 
/*******************************************************************************
 INITIALIZE THE THINGS
*******************************************************************************/
initialize:


    jsr $e544               // Clear screen

    lda #$00                // Set the background color for the game area
    sta $d021
    lda #$00                // Set the background color for the border
    sta $d020

    lda #%11001111          // Enable sprites
    sta $d015

    lda #%00111110          // Specify multicolor for the ball sprites
    sta $d01c
    lda #$01                // Color light gray
    sta $d025               // Set shared multicolor #1
    lda #$0b                // Color dark gray
    sta $d026               // Set shared multicolor #2

    lda #$00                // Disable xpand-y
    sta $d017

    lda #$00                // Disable xpand-x
    sta $d01d

    lda #$00                // Set sprite/background priority
    sta $d01b

    lda #$00
    sta $d01e               // Init sprite collision
    sta $d01f               // Init sprite collision


    lda #$01                // Set sprite #0 - the paddle individual color
    sta $d027
    lda #$0c                // Set sprite #1 - ball individual color (medium gray)
    sta $d028
    lda #$05                // Set sprite #2 - ball individual color
    sta $d029
    lda #$06                // Set sprite #3 -ball individual color
    sta $d02a

    lda #paddleSpriteData/64
    sta $07f8               // Sprite #0 – the paddle
    lda #ballSpriteData/64
    sta $07f9               // Sprite #1 - ball #1
    sta $07fa               // Sprite #2 - ball #2
    sta $07fb               // Sprite #3 - ball #3

/*
    Itema Logo Sprites
*/
    lda #itemaLogoSwoosh/64
    sta $07fe               // Sprite #6
    lda #itemaLogoBall/64
    sta $07ff               // Sprite #7

    // Set MSB for sprite 6 and 7
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

    // Set colors for the sprites in the Itema logo
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
	    Load the initial screen
	    $4500 - intro screen
	    $4d00 - level 1
	*/
	
	lda #$45
	sta $ff
	lda #$00
	sta $fe
	jsr load_screen

    //lda #music.startSong-1
    //jsr music.init  


// Initialize the IRQ
jsr init_irq


/*******************************************************************************
 MAIN LOOP
*******************************************************************************/
loop:
jmp loop

start_game:
    // quit demo mode
    lda #%0000000
    sta demo_mode
    lda #0
    // Silence the SID
    ldx #$18
    clear_sid:
    sta $d400,x   // Clear each SID register from $D400-$D418
    dex
    bpl clear_sid
    // reset ball position
    jsr reset_ball_position
    // load the first level
    lda #$4d
    sta $ff
    lda #$00
    sta $fe    
    jsr load_screen
    lda #$00
    sta wHudScore
    sta wHudScore+1
    lda #$03
    sta wHudLives
    jsr gameUpdateScore
    jsr gameUpdateHighScore
    jsr gameUpdateLives
    //LIBSOUND_PLAYSFX_AA(music,SFX_Fail1)
rts


/*******************************************************************************
 DEMO INPUT

 - Determine which ball is lowest (having the highest YL value)
 - Use that ball's x-position to determine paddle position
 - Use the Y position of the selected ball to determine whether to toggle the
   paddle offset to get a bit of an angle.
*******************************************************************************/
demo_input:
    // only play music while in demo mode
    jsr music.play

    // test if the fire button on paddle 2 is pressed,
    // if so start the game instead of doing demo mode input
	lda $dc01
    and #%00000100          // left stick mask
    beq start_game
	
    // figure out which ball is lowest
    lda SpriteMem+9			// ball 1 - xl
    sta SpriteMem

    lda SpriteMem+11		// ball 1 - yl
    clc
    sbc SpriteMem+20		// ball 2 - yl
    bcc ball_2_is_lower_than_ball_1

    lda SpriteMem+11		// ball 1 - yl
    clc
    sbc SpriteMem+29		// ball 3 - yl
    bcc ball_3_is_lower_than_ball_1

    // if we reach here, ball 1 is lowest
    lda SpriteMem+9			// ball 1 - xl
    sta SpriteMem
    jmp end_ball_comparison

	// determine whether ball 3 is lower than ball 2
    ball_2_is_lower_than_ball_1:
      lda SpriteMem+20		// ball 2 - yl
      clc
      sbc SpriteMem+29		// ball 3 - yl
      bcc ball_3_is_lower_than_ball_2

      // if we reach here, ball 2 is lowest
      lda SpriteMem+18		// ball 2 - xl
      sta SpriteMem
      lda SpriteMem+20		// ball 2 - yl
      jmp end_ball_comparison

    // ball 3 is lowest
    ball_3_is_lower_than_ball_1:
      lda SpriteMem+27		// ball 3 - xl
      sta SpriteMem
      lda SpriteMem+29		// ball 3 - yl
      jmp end_ball_comparison


    // ball 3 is lowest
    ball_3_is_lower_than_ball_2:
      lda SpriteMem+27		// ball 3 - xl
      sta SpriteMem
      lda SpriteMem+29		// ball 3 - yl

    end_ball_comparison:

    // Alternate between moving the ball to the left and to the right
    demo_input_toggle:
      lda demoInputToggle
      beq demo_input_right

    demo_input_left:
        clc
        lda SpriteMem
        sbc #$08
        sta SpriteMem
        jsr handle_paddle_bounds
        rts

    demo_input_right:
        lda SpriteMem
        adc #$08
        sta SpriteMem
        jsr handle_paddle_bounds // XXX: Move to separate (without store_xl)
        rts

/*******************************************************************************
 PLAYER/PADDLE INPUT
*******************************************************************************/
paddle_input:

    lda demo_mode
    cmp #%00000001
    beq demo_input          // If we are in demo mode we do the demo input

    lda #$01                // Set sprite #0 - the paddle individual color
    sta $d027

    lda #%00000000
    sta ball_speed_up
                
    lda $dc00               // Load value from CIA#1 Data Port A (pot lines are input)
    and #%01111111          // Set bit 0 to input for pot x (paddle 1)
    sta $dc00               // Store the result back to Data Port A

    lda $dc01
    and #%00000100
    bne paddle_input_cont

    lda #$03                // Set sprite #0 - the paddle individual color
    sta $d027
    
    lda #%00000001
    sta ball_speed_up

    paddle_input_cont:

    lda $d419               // Load value from Paddle X pot
    eor #$ff                // XOR with 255 to reverse the range


    // Update paddle position unless it will end up outside the playing area
    handle_paddle_bounds:
    clc
    cmp #$1a                // Compare with the minimum value
    bcs piNotLess           // If carry is set (number >= minValue), branch to piNotLess
    lda #$1a                // If carry is clear (number < minValue), load the minimum value into the accumulator
    piNotLess:
    clc
    // Now check if the number is greater than the maximum value
    cmp #$ce                // Compare with the maximum value
    bcc piNotGreater        // If carry is clear (number < maxValue), branch to piNotGreater
    lda #$ce                // If carry is set (number >= maxValue), load the maximum value into the accumulator
    piNotGreater:
    jsr store_xl            // Store the paddle x-position
    
    rts

/*******************************************************************************
 INITIALIZE INTERRUPTS
*******************************************************************************/
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

/*******************************************************************************
 HANDLE INPUT AND SPRITE MOVEMENT
*******************************************************************************/
 
irq_1:
    
    lda #$00
    sta SpriteIndex
    jsr paddle_input

    animation_loop:
        FRAME_COLOR(0)
        clc
        lda SpriteIndex
        cmp #$00
        beq move_ball_normally

        // Check if we should move the ball faster
        move_ball_accellerated:
          // TODO: User flags to check for accellerated movement
          clc
          jsr get_flags
          and #%00000010
          bne flagit 

        move_ball_normally:
            jsr move_vertically
            jsr move_horizontally
            jsr draw_sprite
            jsr check_brick_collision
            jsr check_paddle_collision

        inc SpriteIndex
        lda SpriteIndex
        cmp #BALLS+1
        beq done
        jmp animation_loop
    done:
        asl $d019 // Clear interrupt flag
        jmp $ea81 // set flag and end

flagit:
    FRAME_COLOR(7)
    jsr get_flags
    and #%11111001
    jsr store_flags
    jmp move_ball_normally

/*
    Add a little upwards acceleration for a period of time. This typically happens
    when the ball hits the paddle.
*/
accelerated_movement:
    FRAME_COLOR(2)
    jsr get_flags
    and #%00000010
    beq end_accellerated_movement

    //
    lda #00
    jsr store_flags

    lda #$80                // -1
    jsr store_ya
    jmp move_ball_normally

    end_accellerated_movement:
        FRAME_COLOR(0)
        lda #$00
        jsr store_ya
    jmp move_ball_normally

/*******************************************************************************
 LOAD DATA
*******************************************************************************/
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
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00101000, %00000000
.byte %00000000, %10011010, %00000000
.byte %00000010, %01101010, %11000000
.byte %00000010, %10101010, %11000000
.byte %00000010, %10101010, %11000000
.byte %00000010, %10101010, %11000000
.byte %00000010, %10101011, %11000000
.byte %00000010, %10101011, %11000000
.byte %00000000, %10101111, %00000000
.byte %00000000, %00111100, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000

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

*=music.location "Music"
    .fill music.size, music.getData(i)

SFX_Crab:          .byte $0E,$EE,$00,$DC,$81,$DC,$DC,$DC,$B1,$31,$B0,$AF,$AE,$AF,$AE,$AD,$AC,$90,$11,$00
SFX_Fail1:         .byte $0E,$EE,$00,$98,$21,$98,$98,$98,$98,$98,$94,$94,$94,$94,$94,$92,$92,$92,$92,$92,$90,$11,$00
SFX_Fail2:         .byte $0E,$EE,$00,$AC,$81,$AC,$21,$AB,$81,$AB,$21,$AA,$81,$AA,$21,$A9,$81,$A9,$21,$A8,$81,$A8,$21,$A7,$81,$A7,$21,$A6,$81,$A6,$21,$A5,$81,$A5,$21,$A4,$81,$A4,$21,$A3,$81,$A3,$21,$A2,$81,$A2,$21,$A1,$81,$A1,$21,$90,$11,$00
SFX_Great:         .byte $0E,$00,$00,$B0,$21,$B0,$B0,$B4,$B4,$B4,$B7,$B7,$B7,$BC,$BC,$BC,$A0,$11,$00
SFX_NewCustomer:   .byte $0E,$EE,$00,$CC,$11,$CC,$CC,$CC,$C8,$C8,$C8,$C8,$90,$00
SFX_Tadaah:        .byte $0E,$00,$33,$B0,$21,$B4,$B7,$BC,$A0,$11,$A0,$B0,$21,$B4,$B7,$BC,$B0,$B4,$B7,$BC,$B0,$B4,$B7,$BC,$B0,$B4,$B7,$BC,$B0,$B4,$B7,$BC,$A0,$11,$00

.macro LIBSOUND_PLAYSFX_AA(wSidfile, wSound)   
{   
    lda #<wSound
    ldy #>wSound
    ldx #14
    jsr wSidfile+6
}
