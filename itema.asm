/*
    Bouncing ball demo

    Copyright (c) 2020-2025 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
*/

// Include .prg file assembly segments (ordered by runtime address)
.file [name="itema.prg", segments="Basic,AnimationTable,Music,Sprites,Code,Variables,Charset,Levels"]

.var music = LoadSid("./music/Calypso_Bar.sid")


.segmentdef Basic [start=$0801];
.segmentdef AnimationTable [startAfter="Basic"]
.segmentdef Music [start=music.location];
.segmentdef Sprites [start=$2000, align=$40];
.segmentdef Code [startAfter="Sprites"];
.segmentdef Variables [startAfter="Code"];
.segmentdef Charset [startAfter="Variables", align=$800];
.segmentdef Levels [startAfter="Charset"];

// TODO: Pack music and write memcpy to move it to music.location
.segment Music "Music"
.fill music.size, music.getData(i)

/*******************************************************************************
 BASIC UPSTART CODE
*******************************************************************************/
.segment Basic "Basic Upstart"
BasicUpstart2(initialize)

#import "library/libDefines.asm"
#import "library/font.asm"
#import "library/sprites.asm"
#import "library/sfx.asm"

/*******************************************************************************
 GRAPHICS
*******************************************************************************/
.segment AnimationTable "Ball frame number pointer table"
BallFramePtr:
.for (var f = 0; f < 12; f++)
    .word (ballSpriteStart + f*64) / 64


.segment Code "Main program"
/*******************************************************************************
 GAMEPLAY CONSTANTS
*******************************************************************************/
.const MODE_GAME  = $00     // Actually play the game
.const MODE_INTRO = $01     // Show intro screen and demo mode
.const MODE_END   = $02     // Game has just ended

 // When launching the ball from the paddle
.const LAUNCH_VELOCITY = $60
 
// Offset from the left edge of the sprite to the left edge of the ball
.const BallOffset = 6
// The width of the ball
.const BallWidth = 12
// The width of the Paddle
.const PaddleWidth = 32
// The centre of the paddle
.const PaddleCenter = 16
// Center of the paddle + 1/2 the width of the ball
.const PaddleReach= PaddleCenter + ( BallWidth / 2 )
// The angle to use when alternating in intro
.const PaddleAngleDemo  = 8
// The number of lives to start with
.const NumberOfLives = 3
 
// Minumum and maximum x-values for the paddle to stay within the game arena
.const PaddleLeftBounds = 26
.const PaddleRightBounds = 230 - PaddleWidth
 

get_ready_text:
    .text "get ready!"
    .byte $ff

game_over_text:
    .text "game over!"
    .byte $ff

/*******************************************************************************
 IMPORTS
*******************************************************************************/
#import "library/libSprite.asm"
#import "library/libInput.asm"
#import "library/libScreen.asm"

.segment Code "Contd."
/*******************************************************************************
 GAMEPLAY VARIABLES
*******************************************************************************/
mode:
    .byte $00

bFireButtonPressed:
    .byte %00000000

BallCount:
    .byte 3

BrickCount:                 // The number of bricks left at this level
    .byte 0
    
CurrentLevel:
    .byte 0

StartingXPosition:
    .byte 0

StartingYPosition:
    .byte 0
/*******************************************************************************
 INITIALIZE THE THINGS
*******************************************************************************/
initialize:

    lda MODE_INTRO              // Start in the intro mode
    sta mode

    jsr KERNAL_CLRSCR           // Clear screen

    lda #$00                    // Set the background color for the game area
    sta BGCOL0
    lda #$00                    // Set the background color for the border
    sta EXTCOL

    lda #%11001111              // Enable sprites
    sta SPENA

    lda #%00111110              // Specify multicolor for the ball sprites
    sta SPMC
    lda #$01                    // Color light gray
    sta SPMC0                   // Set shared multicolor #1
    lda #$0b                    // Color dark gray
    sta SPMC1                   // Set shared multicolor #2

    lda #$00                    // Disable xpand-y
    sta SPRYEXP

    lda #%00000001              // Expand horizontally for wider paddle
    sta SPRXEXP

    lda #$00                    // Set sprite/background priority
    sta SPBGPR

    lda #$00
    sta SPSPCL                  // Init sprite collision
    sta SPBGCL                  // Init sprite collision


    lda #$01                    // Set sprite #0 - the paddle individual color
    sta SP0COL
    lda #$0c                    // Set sprite #1 - ball individual color (medium gray)
    sta SP0COL+1
    lda #$05                    // Set sprite #2 - ball individual color
    sta SP0COL+2
    lda #$06                    // Set sprite #3 -ball individual color
    sta SP0COL+3

    lda #paddleSpriteData/64
    sta SPRITE0PTR              // Sprite #0 – the paddle
    
    lda #$03
    asl
    tay
    lda BallFramePtr,y
    sta SPRITE0PTR+1        // Sprite #1 - ball #1
    sta SPRITE0PTR+2        // Sprite #2 - ball #2
    sta SPRITE0PTR+3        // Sprite #3 - ball #3

/*
    Itema Logo Sprites
*/
    lda #itemaLogoSwoosh/64
    sta SPRITE0PTR+6        // Sprite #6
    lda #itemaLogoBall/64
    sta SPRITE0PTR+7        // Sprite #7

    // Set MSB for sprite 6 and 7
    lda MSIGX
    ora #%11000000
    sta MSIGX

    // Position both sprites overlapping
    lda #$02
    sta SP0X+$0C
    sta SP0X+$0E
    lda #$d7
    sta SP0Y+$0C
    sta SP0Y+$0E

    // Set colors for the sprites in the Itema logo
    lda #$0f
    sta SP0COL+6
    lda #$0a
    sta SP0COL+7

	/*
	    Set character set pointer to our custom set, turn off
	    multicolor for characters

        The character set pointer is three bits (1-3) in $d018, indicating which $0800 (2048)
        block is used.

        $d018:  %----XXX-

        To calculate: character set vector / $800 rotated/shifted left one bit

        $d018 needs the bits masked, some of them are set at startup (default $1000 -> block 2 -> %----010-)

	*/
    .var charSlotBits = charset / $0800 << 1
	
	lda VMCSB
    and #%11110001         // Mask the three charset location bits (1-3)
    ora #charSlotBits      // Set chars location to 5 * $0800 = $2800 for displaying the custom font
	sta VMCSB              // Bits 1-3 ($0400 + 512 .bytes * low nibble value) of $D018 sets char location
	                       // $400 + $200*$0E = $3800
	lda SCROLX             // Turn off multicolor for characters
	and #%11101111         // by clearing bit #4 of $D016
	sta SCROLX
	
	LOAD_SCREEN(0)         // Load the introduction screen

    jsr init_irq           // Initialize the IRQ
    jmp loop               // Go go the endless main loop

/*******************************************************************************
 MAIN LOOP
*******************************************************************************/
loop:
jmp loop

/*
    Initialie the variables so that they are correct for starting a new game
*/
initialize_game_variables:
    lda #$01
    sta BallCount               // We start with only one ball
    lda #%11000011              // Disable the balls we are not using
    sta SPENA
    jsr reset_sprite_data
rts

start_game:
    lda MODE_GAME               // Quit demo mode
    sta mode
    jsr initialize_game_variables

    // Silence the SID
    ldx #$18
    clear_sid:
    sta SIDBASE,x               // Clear each SID register from $D400-$D418
    dex
    bpl clear_sid

    jsr sfx_init                // Reset the effect channel after silencing SID
    jsr sfx_enable

    // Load the first level
    lda #$01
    sta CurrentLevel
    lda #$00
    sta wHudScore
    sta wHudScore+1
    lda #NumberOfLives
    sta wHudLives
    
    jsr load_level

rts

/*******************************************************************************
 DEMO INPUT

 - Determine which ball is lowest (having the highest YL value)
 - Use that ball's x-position to determine paddle position
 - Use the Y position of the selected ball to determine whether to toggle the
   paddle offset to get a bit of an angle.
*******************************************************************************/
demo_input:
    // test if the fire button on paddle 2 is pressed,
    // if so start the game instead of doing demo mode input
    lda CIAPRB
    and #%00000100              // left stick mask
    bne demo_input_continue
    jmp start_game

demo_input_continue:

    // figure out which ball is lowest
    lda SpriteMem+8             // ball 1 - xl
    sta SpriteMem               // paddle - xl

    lda SpriteMem+9             // ball 1 - yl
    clc
    sbc SpriteMem+17            // ball 2 - yl
    bcc ball_2_is_lower_than_ball_1

    lda SpriteMem+9             // ball 1 - yl
    clc
    sbc SpriteMem+25            // ball 3 - yl
    bcc ball_3_is_lower_than_ball_1

    // if we reach here, ball 1 is lowest
    lda SpriteMem+8             // ball 1 - xl
    sta SpriteMem
    jmp end_ball_comparison

    // determine whether ball 3 is lower than ball 2
    ball_2_is_lower_than_ball_1:
      lda SpriteMem+17          // ball 2 - yl
      clc
      sbc SpriteMem+25          // ball 3 - yl
      bcc ball_3_is_lower_than_ball_2

      // if we reach here, ball 2 is lowest
      lda SpriteMem+16          // ball 2 - xl
      sta SpriteMem
      lda SpriteMem+17          // ball 2 - yl
      jmp end_ball_comparison

    // ball 3 is lowest
    ball_3_is_lower_than_ball_1:
      lda SpriteMem+24          // ball 3 - xl
      sta SpriteMem
      lda SpriteMem+25          // ball 3 - yl
      jmp end_ball_comparison

    // ball 3 is lowest
    ball_3_is_lower_than_ball_2:
      lda SpriteMem+24          // ball 3 - xl
      sta SpriteMem
      lda SpriteMem+25      // ball 3 - yl

    end_ball_comparison:
	    // Alternate between moving the ball to the left and to the right
	    lda demoInputToggle
	    beq demo_input_right

    demo_input_left:
        clc
        lda SpriteMem
        sbc #PaddleAngleDemo
        sta SpriteMem
        jsr handle_paddle_bounds
        rts

    demo_input_right:
        lda SpriteMem
        adc #PaddleAngleDemo
        sta SpriteMem
        jsr handle_paddle_bounds
        rts

decide_on_input:
    // Reset the fire button flag
    lda #%00000000
    sta bFireButtonPressed

    lda mode
    cmp MODE_INTRO
    beq demo_input              // If we are in demo mode we do the demo input
    jmp paddle_input            // Otherwise do paddle input
rts

/*******************************************************************************
 PLAYER/PADDLE INPUT
*******************************************************************************/
paddle_input:
    lda CIAPRA                  // Load value from CIA#1 Data Port A (pot lines are input)
    and #%01111111              // Set bit 0 to input for pot x (paddle 1)
    sta CIAPRA                  // Store the result back to Data Port A

    lda CIAPRB                  // Check whether the fire button is held
    and #%00000100
    bne paddle_input_cont       // If not we'll just continue

    lda #%00000001
    sta bFireButtonPressed

    paddle_input_cont:

    lda SIDPOTX                 // Load value from Paddle X pot
    eor #$ff                    // XOR with 255 to reverse the range

    // Update paddle position unless it will end up outside the playing area
    handle_paddle_bounds:
    clc
    cmp #PaddleLeftBounds       // Compare with the minimum value
    bcs piNotLess               // If carry is set (number >= minValue), branch to piNotLess
    lda #PaddleLeftBounds       // If carry is clear (number < minValue), load the minimum value into the accumulator
    piNotLess:
    clc
    // Now check if the number is greater than the maximum value
    cmp #PaddleRightBounds      // Compare with the maximum value
    bcc piNotGreater            // If carry is clear (number < maxValue), branch to piNotGreater
    lda #PaddleRightBounds      // If carry is set (number >= maxValue), load the maximum value into the accumulator
    piNotGreater:
    sta SpriteMem               // Store the paddle x-position
rts

/*******************************************************************************
 INITIALIZE INTERRUPTS
*******************************************************************************/
init_irq:
    sei
    lda #<irq_1
    ldx #>irq_1
    sta IRQRAMVECTOR
    stx IRQRAMVECTOR+1          // Set interrupt addr
    lda #$7f
    sta CIAICR                  // Timer A off on cia1/kb
    sta CI2ICR                  // Timer A off on cia2
    lda #$81
    sta IRQMSK                  // Raster interrupts on
    /*
    lda #$1b                    // Screen ctrl: default
    sta SCROLY
    */
    lda #$01
    sta RASTER                  // Interrupt at line 0

    lda CIAICR                  // Clrflg (cia1)
    lda CI2ICR                  // Clrflg (cia2)
    asl VICIRQ                  // Clr interrupt flag (just in case)
    cli
    rts

/*******************************************************************************
 HANDLE INPUT AND SPRITE MOVEMENT DURING INTERRUPT
*******************************************************************************/
irq_1:

    // only play music when we are not in the game
    lda mode
    cmp MODE_GAME
    bne irq_play_music
    jsr sfx_update
    jmp irq_audio_done

irq_play_music:
    jsr music.play

irq_audio_done:

    jsr decide_on_input         // Decide whether or not to do the paddle or demo input

    lda textTimer
    beq start_loop              // Jump if there is not a timer running (textTimer == 0)
    dec textTimer               // Count down the display text timer
    bne start_loop              // If not yet "0" run the timed text loop
    jsr clear_timed_text        // Replace the text with the original background

    // The end game mode will show a timed text, allow the paddle to be moved
    // but will not animate the balls
    lda mode
    cmp MODE_END
    bne start_loop

    lda #$00
    ldx #<music.init
    ldy #>music.init
    jsr music.init

    // Load intro screen and enable demo mode
    LOAD_SCREEN(0)
    lda MODE_INTRO
    sta mode
    jsr sfx_disable
    lda #$03
    sta BallCount
    jsr reset_sprite_data
    lda #%11001111              // Enable all the three balls
    sta SPENA

    // Update the high score as it will have been overwritten
    jsr gameUpdateHighScore

    start_loop:

    lda #$00
    sta SpriteIndex

    // Allow the paddle to move while showing the text, but do not do normal ball movement
    animation_loop:
        lda textTimer
        beq normal_motion       // Jump if there is not a timer running (textTimer == 0)
        lda SpriteIndex         // Load the current sprite
        beq normal_motion       // If equals "0" (the paddle) we do normal motion
        jsr draw_sprite         // Draw the paddle sprite
        jmp next_sprite         // Move other sprites (balls)

    normal_motion:
        jsr follow_paddle       // in case the ball has been captured
        jsr move_vertically
        jsr move_horizontally
        jsr draw_sprite
        jsr check_brick_collision
        jsr check_paddle_collision

        // Indicate that the fire button is pressed. We do this by giving the
        // paddle a nice color.
	    lda #$01                // Set sprite #0 - the paddle individual color
	    sta SP0COL
        clc
        lda bFireButtonPressed
        cmp #%00000000
        beq next_sprite
        lda #$03                // Cyan is a pretty color
        sta SP0COL              // Set sprite #0 - the paddle individual color

    next_sprite:
        lda SpriteIndex
        cmp BallCount
        beq done
        inc SpriteIndex
        jmp animation_loop 

    done:
        // Check whether or not any balls are colliding _after_ all the 
        // calculations and movements have been done for this frame. 
        jsr check_ball_collisions
        asl VICIRQ              // Clear interrupt flag
        jmp IRQROMEXIT          // set flag and end

/*******************************************************************************
 LOAD DATA
*******************************************************************************/

.segment Levels "Level Data - Intro"
.var l0 = LoadBinary("petscii/intro.bin")
level0_chars:  .fill l0.getSize(), l0.get(i)

.segment Levels "Level Data - Level 0"
.var l1 = LoadBinary("petscii/level_0.bin")
level1_chars:  .fill l1.getSize(), l1.get(i)

.segment Levels "Level Data - Level 1"
.var l2 = LoadBinary("petscii/level_1.bin")
level2_chars:  .fill l2.getSize(), l2.get(i)

.segment Levels "Level Data - Level 2"
.var l3 = LoadBinary("petscii/level_2.bin")
level3_chars:  .fill l3.getSize(), l3.get(i)

.segment Levels "Level Data - Level 3"
.var l4 = LoadBinary("petscii/level_3.bin")
level4_chars:  .fill l4.getSize(), l4.get(i)

.segment Levels "Level Data - Level 4"
.var l5 = LoadBinary("petscii/level_4.bin")
level5_chars:  .fill l5.getSize(), l5.get(i)

// Use <> (low byte) and > (high byte) to extract addresses
level_chars_lo:  .byte <level0_chars, <level1_chars, <level2_chars, <level3_chars, <level4_chars, <level5_chars
level_chars_hi:  .byte >level0_chars, >level1_chars, >level2_chars, >level3_chars, >level4_chars, >level5_chars

.macro LOAD_SCREEN(index) {
    ldx #index
    lda level_chars_lo,x
    sta ZP_PTR_LO
    lda level_chars_hi,x
    sta ZP_PTR_HI
    jsr load_screen
}
