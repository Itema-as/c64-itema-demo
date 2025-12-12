/*
    Bouncing ball demo

    Copyright (c) 2020-2025 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
*/

// Include .prg file assembly segments (ordered by runtime address)
.file [name="itema.prg", segments="Basic,AnimationTable,Music,Sprites,Code,Variables,Charset,Levels,TitleScreen,TitleBitmap,TitleColors"]

.var music = LoadSid("./music/Calypso_Bar.sid")
.var titleScreenBinary = LoadBinary("title.koa", BF_KOALA)


.segmentdef Basic [start=$0801];
.segmentdef AnimationTable [startAfter="Basic"]
.segmentdef Music [start=music.location];
.segmentdef Sprites [start=$2000, align=$40];
.segmentdef Variables [startAfter="Sprites"];
.segmentdef Charset [startAfter="Variables", align=$800];
.segmentdef Levels [startAfter="Charset"];
.segmentdef Code [startAfter="Levels"];
.segmentdef TitleColors [start=$1c00];
.segmentdef TitleScreen [start=$8c00];
.segmentdef TitleBitmap [start=$a000];

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
.const MODE_INTRO_IMAGE = $03 // Show Koala image before the intro screen

/*
$DD00 bit 0–1:

00 → Bank 3: $C000–$FFFF
01 → Bank 2: $8000–$BFFF
10 → Bank 1: $4000–$7FFF
11 → Bank 0: $0000–$3FFF

bank_base    = $8000
screen_index = (TITLE_SCREEN_ADDR - bank_base) / $0400
char_index   = (TITLE_BITMAP_ADDR - bank_base) / $0800

	$d018 = (screen_index << 4) | (char_index << 1)
	      = (3 << 4) | (4 << 1)
	      = $30 | $08
	      = $38
	*/
.const TITLE_BITMAP_ADDR   = $a000
.const TITLE_SCREEN_ADDR   = $8c00
.const TITLE_DURATION      = 250 // 5 seconds at 50Hz IRQ
.const TITLE_BANK_VALUE    = $01 // CI2PRA bank bits for VIC bank 2 ($8000-$bfff)
.const TITLE_VMCSB_VALUE   = $38 // Screen at $8c00 (screen index 3), bitmap at $a000 (bitmap index 4) in bank 2
.const TITLE_SCROLY_VALUE  = $3b // Bitmap mode, 25 rows, no v-scroll
.const TITLE_SCROLX_VALUE  = $18 // Multicolor bitmap, 40 cols, no h-scroll
.const TITLE_BITMAP_SIZE   = titleScreenBinary.getBitmapSize()
.const TITLE_SCREEN_SIZE   = titleScreenBinary.getScreenRamSize()
.const TITLE_COLOR_SIZE    = titleScreenBinary.getColorRamSize()
.const TITLE_COLOR_PAGES   = 4                     // Koala color RAM is 1000 bytes
.const TITLE_COLOR_REMAINDER = TITLE_COLOR_SIZE - (TITLE_COLOR_PAGES-1)*$100

 // When launching the ball from the paddle
.const LAUNCH_VELOCITY = $60

// The number of frames to show timed text. The IRQ updates at 50Hz
.const TEXT_TIMER = 150
 
// Offset from the left edge of the sprite to the left edge of the ball
.const BallOffset = 6
// The width of the ball
.const BallWidth = 12
.const BallCenterOffset = BallOffset + ( BallWidth / 2 )
// The width of the Paddle
.const PaddleWidthNormal       = 32
.const PaddleWidthWide         = PaddleWidthNormal + 16
.const PaddleCenterNormal      = PaddleWidthNormal / 2
.const PaddleCenterWide        = PaddleWidthWide / 2
.const PaddleReachLeftNormal   = PaddleCenterNormal + ( BallWidth / 2 )
.const PaddleReachRightNormal  = PaddleCenterNormal + ( BallWidth / 2 )
.const PaddleReachLeftWide     = PaddleCenterWide + ( BallWidth / 2 )
.const PaddleReachRightWide    = PaddleCenterWide + ( BallWidth / 2 )
// The angle to use when alternating in intro
.const PaddleAngleDemo  = 8
// The number of lives to start with (BCD)
.const NumberOfLives = 2    // XXX: Revert back to 6
// See at the bottom of the file for the actual levels loaded
.const NumberOfLevels = 1   // XXX: Revert back to 7
 
// Minumum and maximum x-values for the paddle to stay within the game arena
.const PaddleLeftBounds = 26
.const PaddleRightBoundsNormal = 230 - PaddleWidthNormal
.const PaddleRightBoundsWide   = 230 - PaddleWidthWide
 

get_ready_text:
    .text "get ready"
    .byte $ff

game_over_text:
    .text "game over"
    .byte $ff

well_done_text:
    .text "well done"
    .byte $ff

.const LEVEL_PENDING_NONE          = $00
.const LEVEL_PENDING_SHOW_MESSAGE  = $01
.const LEVEL_PENDING_ADVANCE       = $02

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

LevelCompletePending:       // Indicates a level completion delay is active
    .byte 0

CurrentLevel:
    .byte 0

StartingXPosition:
    .byte 0

StartingYPosition:
    .byte 0

introImageTimer:
    .byte 0

titleScreenBinaryVicBankBackup:
    .byte 0
titleScreenBinaryVmcsbBackup:
    .byte 0
titleScreenBinaryScrolxBackup:
    .byte 0
titleScreenBinaryScrolyBackup:
    .byte 0
titleScreenBinaryCi2ddraBackup:
    .byte 0
/*******************************************************************************
 INITIALIZE THE THINGS
*******************************************************************************/
initialize:

    lda MODE_INTRO_IMAGE        // Start by showing the Koala intro image
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

    jsr paddle_disable_wide_silent // Ensure the paddle uses the default geometry
    
    lda #$03
    asl
    tay
    lda BallFramePtr,y
    sta SPRITE0PTR+1            // Sprite #1 - ball #1
    sta SPRITE0PTR+2            // Sprite #2 - ball #2
    sta SPRITE0PTR+3            // Sprite #3 - ball #3

/*
    Itema Logo Sprites
*/
    lda #itemaLogoSwoosh/64
    sta SPRITE0PTR+6            // Sprite #6
    lda #itemaLogoBall/64
    sta SPRITE0PTR+7            // Sprite #7

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
    and #%11110001              // Mask the three charset location bits (1-3)
    ora #charSlotBits           // Set chars location to 5 * $0800 = $2800 for displaying the custom font
    sta VMCSB                   // Bits 1-3 ($0400 + 512 .bytes * low nibble value) of $D018 sets char location
                                // $400 + $200*$0E = $3800
    lda SCROLX                  // Turn off multicolor for characters
    and #%11101111              // by clearing bit #4 of $D016
    sta SCROLX

    jsr start_intro_sequence    // Show Koala screen before intro

    jsr init_irq                // Initialize the IRQ
    jmp loop                    // Go go the endless main loop

/*******************************************************************************
 MAIN LOOP
*******************************************************************************/
loop:
jmp loop

/*******************************************************************************
 INTRO SEQUENCE
*******************************************************************************/
start_intro_sequence:
    sei                         // Avoid KERNAL IRQs while setting up the picture
    lda #TITLE_DURATION
    sta introImageTimer

    jsr sfx_disable

    lda CI2PRA
    sta titleScreenBinaryVicBankBackup
    lda VMCSB
    sta titleScreenBinaryVmcsbBackup
    lda SCROLX
    sta titleScreenBinaryScrolxBackup
    lda SCROLY
    sta titleScreenBinaryScrolyBackup
    lda CI2DDRA
    sta titleScreenBinaryCi2ddraBackup

    lda #$00
    sta SPENA                   // Hide sprites while showing the picture

    lda titleScreenBinaryCi2ddraBackup
    ora #%00000011              // Ensure CIA2 port A low bits are outputs for VIC bank select
    sta CI2DDRA

    lda titleScreenBinaryVicBankBackup
    and #%11111100
    ora #TITLE_BANK_VALUE
    sta CI2PRA

    lda #TITLE_SCROLY_VALUE
    sta SCROLY

    lda #TITLE_SCROLX_VALUE
    sta SCROLX

    lda #TITLE_VMCSB_VALUE
    sta VMCSB

    lda titleScreenBinaryBackgroundColor
    sta EXTCOL
    sta BGCOL0
    lda #$01                    // Default
    sta BGCOL1
    lda #$02                    // Default
    sta BGCOL2

    jsr intro_copy_koala_colors

    lda MODE_INTRO_IMAGE
    sta mode
rts

intro_image_tick:
    lda introImageTimer
    beq intro_image_done
    dec introImageTimer
    bne intro_image_return

intro_image_done:
    jsr finish_intro_sequence
intro_image_return:
rts

finish_intro_sequence:
    jsr paddle_disable_wide_silent

    LOAD_SCREEN(0)

    lda titleScreenBinaryVicBankBackup
    sta CI2PRA
    lda titleScreenBinaryVmcsbBackup
    sta VMCSB
    lda titleScreenBinaryCi2ddraBackup
    sta CI2DDRA
    lda titleScreenBinaryScrolxBackup
    sta SCROLX
    lda titleScreenBinaryScrolyBackup
    sta SCROLY

    lda #$00
    sta BGCOL0
    sta EXTCOL

    lda #$00
    ldx #<music.init
    ldy #>music.init
    jsr music.init

    lda MODE_INTRO
    sta mode
    jsr sfx_disable
    lda #$03                    // The number of balls in demo mode
    sta BallCount
    jsr reset_sprite_data
    lda #%11001111              // Enable all the three balls
    sta SPENA

    jsr gameUpdateHighScore
    jsr gameUpdateScore

    lda #$00
    sta introImageTimer
rts

intro_copy_koala_colors:
    ldx #$00
intro_copy_koala_colors_loop:
    .for (var i=0; i<TITLE_COLOR_PAGES; i++) {
        lda titleScreenBinaryColors + i*$100, x
        sta COLORRAM + i*$100, x
    }
    inx
    bne intro_copy_koala_colors_loop
rts

/*
    Initialie the variables so that they are correct for starting a new game
*/
initialize_game_variables:
    jsr paddle_disable_wide_silent
    //jsr paddle_enable_wide
    lda #$01
    sta BallCount               // We start with only one ball
    lda #%11000011              // Disable the balls we are not using
    sta SPENA
    jsr reset_sprite_data
    lda #LEVEL_PENDING_NONE
    sta LevelCompletePending
    jsr gameResetExtraLifeThreshold
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
    cmp paddleRightBoundCurrent // Compare with the maximum value
    bcc piNotGreater            // If carry is clear (number < maxValue), branch to piNotGreater
    lda paddleRightBoundCurrent // If carry is set (number >= maxValue), load the maximum value into the accumulator
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
    // Clear the raster interrupt flag in order to make sure that a new 
    // interrupt is not allowed to start while processing the current.
    asl VICIRQ

    lda mode
    cmp MODE_INTRO_IMAGE
    beq irq_intro_image
    cmp MODE_GAME
    bne irq_play_music          // Only play music when we are not in the game
    jsr sfx_update
    jmp irq_audio_done

irq_play_music:
    jsr music.play
    jmp irq_audio_done

irq_intro_image:
    jsr intro_image_tick
    jmp IRQROMEXIT

irq_audio_done:

    jsr decide_on_input         // Decide whether or not to do the paddle or demo input

    lda LevelCompletePending
    cmp #LEVEL_PENDING_SHOW_MESSAGE
    bne check_text_timer
    lda textTimer
    bne check_text_timer
    LIBSCREEN_TIMED_TEXT(well_done_text)
    lda #LEVEL_PENDING_ADVANCE
    sta LevelCompletePending

check_text_timer:
    lda textTimer
    beq start_loop              // Jump if there is not a timer running (textTimer == 0)
    dec textTimer               // Count down the display text timer
    beq timed_text_expired
    jsr timed_text_update_colors
    jmp start_loop

timed_text_expired:
    jsr clear_timed_text        // Replace the text with the original background

    lda LevelCompletePending
    cmp #LEVEL_PENDING_ADVANCE
    bne check_mode_end
    lda mode
    cmp MODE_GAME
    bne skip_level_advance
    lda #LEVEL_PENDING_NONE
    sta LevelCompletePending
    jsr advance_level
    jmp start_loop

skip_level_advance:
    lda #LEVEL_PENDING_NONE
    sta LevelCompletePending
    jmp check_mode_end

check_mode_end:
    // The end game mode will show a timed text, allow the paddle to be moved
    // but will not animate the balls
    lda mode
    cmp MODE_END
    bne start_loop

    jsr start_intro_sequence
    jmp IRQROMEXIT

    start_loop:

    lda bFireButtonPressed
    beq paddle_default_color
    lda #$03                // Cyan is a pretty color
    bne paddle_color_apply
paddle_default_color:
    lda #$01                // Paddle default color
paddle_color_apply:
    sta SP0COL

    lda #$00
    sta SpriteIndex

    // Allow the paddle to move while showing the text, but do not do normal ball movement
    animation_loop:
        lda #$00
        sta spriteRemoved

        lda textTimer
        beq normal_motion       // Jump if there is not a timer running (textTimer == 0)
        lda SpriteIndex         // Load the current sprite
        beq normal_motion       // If equals "0" (the paddle) we do normal motion
        jsr draw_sprite         // Draw the paddle sprite
        jmp next_sprite         // Move other sprites (balls)

    normal_motion:
        jsr apply_paddle_magnetism
        jsr follow_paddle       // in case the ball has been captured
        jsr move_vertically
        lda spriteRemoved
        beq normal_motion_continue
        lda BallCount
        sta SpriteIndex
        jmp next_sprite

    normal_motion_continue:
        jsr move_horizontally
        jsr draw_sprite
        jsr check_brick_collision
        jsr check_paddle_collision

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

.segment Levels "Level Data - Level 1"
.var l1 = LoadBinary("petscii/level_0.bin")
level1_chars:  .fill l1.getSize(), l1.get(i)

.segment Levels "Level Data - Level 2"
.var l2 = LoadBinary("petscii/level_1.bin")
level2_chars:  .fill l2.getSize(), l2.get(i)

.segment Levels "Level Data - Level 3"
.var l3 = LoadBinary("petscii/level_2.bin")
level3_chars:  .fill l3.getSize(), l3.get(i)

.segment Levels "Level Data - Level 4"
.var l4 = LoadBinary("petscii/level_3.bin")
level4_chars:  .fill l4.getSize(), l4.get(i)

.segment Levels "Level Data - Level 5"
.var l5 = LoadBinary("petscii/level_4.bin")
level5_chars:  .fill l5.getSize(), l5.get(i)

.segment Levels "Level Data - Level 6"
.var l6 = LoadBinary("petscii/level_5.bin")
level6_chars:  .fill l6.getSize(), l6.get(i)

.segment Levels "Level Data - Level 7"
.var l7 = LoadBinary("petscii/level_6.bin")
level7_chars:  .fill l7.getSize(), l7.get(i)

// Use <> (low byte) and > (high byte) to extract addresses
level_chars_lo:  .byte <level0_chars, <level1_chars, <level2_chars, <level3_chars, <level4_chars, <level5_chars, <level6_chars, <level7_chars
level_chars_hi:  .byte >level0_chars, >level1_chars, >level2_chars, >level3_chars, >level4_chars, >level5_chars, >level6_chars, >level7_chars

.macro LOAD_SCREEN(index) {
    ldx #index
    lda level_chars_lo,x
    sta ZeroPage_PtrLo
    lda level_chars_hi,x
    sta ZeroPage_PtrHi
    jsr load_screen
}

/*******************************************************************************
 INTRO KOALA DATA
*******************************************************************************/

.segment TitleBitmap "Title Koala bitmap"
titleScreenBinaryBitmap:
    .fill TITLE_BITMAP_SIZE, titleScreenBinary.getBitmap(i)

.segment TitleScreen "Title Koala screen"
titleScreenBinaryScreen:
    .fill TITLE_SCREEN_SIZE, titleScreenBinary.getScreenRam(i)

.segment TitleColors "Title Koala colours"
titleScreenBinaryColors:
    .fill TITLE_COLOR_SIZE, titleScreenBinary.getColorRam(i)
titleScreenBinaryBackgroundColor:
    .byte titleScreenBinary.getBackgroundColor()
