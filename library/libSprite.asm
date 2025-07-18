/*
    Sprite handling library
    Copyright (c) 2020-2022 Itema AS

    This will simply bounce sprites between the four walls of the screen. Load
    the current sprite number in to the A register and call the following
    functions:

    horizontal
        to move horizontally

    vertical
        to move vertically

    draw_sprite
        to draw the sprite on it's new location

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
    - Morten Moen, mmo@itema.no
    - Arve Moen, amo@itema.no
    - Bjørn Leithe Karlsen, bka@itema.no
*/

#importonce
#import "libSpriteData.asm"
#import "libScreen.asm"
#import "libMath.asm"
#import "libGame.asm"

.macro FRAME_COLOR(color)
{
    lda #color
    sta $d020
}

SetTable:
    .byte %00000001
    .byte %00000010
    .byte %00000100
    .byte %00001000
    .byte %00010000
    .byte %00100000
    .byte %01000000
    .byte %10000000

ClearTable:
    .byte %11111110
    .byte %11111101
    .byte %11111011
    .byte %11110111
    .byte %11101111
    .byte %11011111
    .byte %10111111
    .byte %01111111

/*
    Screen memory lookup tables. Each corresponds to the address of the first
    colum in each row.
*/
ScreenMemLowByte:
    .byte $00,$28,$50,$78,$a0,$c8,$f0,$18
    .byte $40,$68,$90,$b8,$e0,$08,$30,$58
    .byte $80,$A8,$D0,$f8,$20,$48,$70,$98
    .byte $c0
ScreenMemHighByte:
    .byte $04,$04,$04,$04,$04,$04,$04,$05
    .byte $05,$05,$05,$05,$05,$06,$06,$06
    .byte $06,$06,$06,$06,$07,$07,$07,$07
    .byte $07

/*
    Sprite box
*/
.const ScreenTopEdge    = $2f
.const ScreenBottomEdge = $f3
.const ScreenRightEdge  = $d5
.const ScreenLeftEdge   = $14
.const Gravity          = 2
.const VelocityLoss     = 2

/* The y position of the ball for it to be exactly touching the top of the paddle */
.const TopOfPaddle      = $e3 // 224 (bottom) - 3 (paddle hight) + 6 (margin)

fire:
    .byte $0

/*
    A helper "variable" we will need on occasion
*/
temp:
    .byte %00000000
temp1:
    .byte %00000000
temp2:
    .byte %00000000

column:
    .byte %00000000
row:
    .byte %00000000

/*
	Used to determine whether or not to place the bat to the left or
	to the right of the ball.
*/
demoInputToggle:
	.byte 1
/*
    Keep track of these two variables while debugging
    Press CMD/CTRL+W to see the actual values in the C64 Debugger.
*/
//.watch column
//.watch row

reslo:
    .byte %00000000
reshi:
    .byte %00000000

balllo:
    .byte %00000000
ballhi:
    .byte %00000000

/*
    Determine the offset of the sprite x-position address
*/
get_sprite_offset:
    ldx SpriteIndex
    lda #$00

    get_sprite_offset_loop:
        cpx #$00
        beq got_sprite_offset
        clc
        adc #$2
        dex
        jmp get_sprite_offset_loop

    got_sprite_offset:
        rts

draw_sprite:
    // set vertical position
    jsr get_sprite_offset
    tay
    jsr get_yl
    sta $d001,y

    // set horizontal position
    jsr get_sprite_offset
    tay
    jsr get_xl
    sta $d000,y
rts

set_msb:
    ldx SpriteIndex
    lda $d010
    ora SetTable,x
    sta $d010
rts

clear_msb:
    ldx SpriteIndex
    lda $d010
    and ClearTable,x
    sta $d010
rts

////////////////////////////////////////////////////////////////////////////////

/*
    Perform horizontal movement
*/
move_horizontally:
    jsr h_acceleration      // Apply horizontal acceleration
    jsr get_xv
    clc
    cmp #$00                // Compare with signed integer
    bmi move_left           // Move left if value is negative
    bpl move_right          // Move right if value is positive
rts
/*
    Move current sprite left
*/
move_left:
    jsr get_xv              // Get the X-velocity (which is negative)
    eor #$ff                // Flip the sign so that we get a positive number
    clc
    adc #$01                // fix after flip
    jsr shift_right         // Apply only the 5 MSB of velocity
    sta temp                // Store the new value in a variable
    jsr get_xl
    sec
    sbc temp                // Move left by the amount of velocity
    jsr store_xl
    jsr left_edge
rts

/*
    Move current sprite right
*/
move_right:
    jsr get_xv              // Get the X-velocity (a positive number)
    jsr shift_right         // Apply only the 5 MSB of velocity
    sta temp                // Store the value in a temporary variable
    jsr get_xl
    clc
    adc temp                // Move right by the amount of velocity
    jsr store_xl
    jsr right_edge
rts

/*
    Apply the acceleration to the velocity, moving up. Once passing $FF (-1) the
    direction will change to moving downwards. This transition causes some
    velocity to be lost.
*/
bounce_up:
    /*
    lda motionless
    cmp #$0
    bne bounce_up_end
    */
    jsr get_yv
    clc
    adc #Gravity            // Simulate gravity
    jsr store_yv
    bounce_up_end:
rts

/*
    Apply the acceleration to the velocity, moving down. Make sure that the
    maximum value of #$7f is not exceeded because that would mean moving up.
*/
fall_down:
    /*
    lda motionless
    cmp #$0
    bne fall_down_end
    */

    jsr get_yv
    clc
    adc #Gravity            // Simulate gravity
    cmp #$80                // Never go negative
    bpl fall_down_end
    jsr store_yv
    fall_down_end:
rts

/*
    Apply horizontal acceleration from input
*/
h_acceleration:
    jsr get_xa
    sta temp                // Store the new value in a variable
    jsr get_xv
    clc
    adc temp                // Add acceleration to velocity
    clv                     // Clear the overflow flag
    bvs h_acceleration_end  // Do not store the value if the sign was flipped
    jsr store_xv
    h_acceleration_end:
rts

/*
    Perform vertical movement
*/
move_vertically:
    jsr v_acceleration      // Apply vertical acceleration
    jsr get_yv
    clc
    cmp #$00                // Compare with signed integer
    bmi up                  // Move up if value is negative
    bpl move_down           // Move down if value is positive
rts

/*
    Apply vertical acceleration from input along with gravity
*/
v_acceleration:
    jsr get_ya
    sta temp                // Store the new value in a variable
    jsr get_yv
    clv                     // Clear the overflow flag
    adc temp                // Add Y to A
    bvs v_acceleration_end  // Do not store the value if the sign was flipped
    jsr store_yv
    // -- Apply gravity
    cmp #$00                // Compare with signed integer
    bpl fall_down           // Move down if value is positive
    bmi bounce_up           // Move up if value is negative
    v_acceleration_end:
rts

/*
    Move current sprite upwards
*/
up:
    jsr get_yv              // Get the Y-velocity (a negative number)
    eor #$ff                // Flip the sign so that we get a positive number
    clc
    jsr shift_right         // Apply only the 5 MSB of velocity
    sta temp                // Store the new value in a variable
    jsr get_yl
    sec                     // Set the carry flag
    sbc temp                // Move up by the amount of velocity
    jsr store_yl
    cmp #ScreenTopEdge      // Is top of screen hit?
    bcc change_to_move_down // Jump if less than $31
rts


/*
    Flip the sign on the vertical velocity and acceleration
*/
change_to_move_up:
    jsr get_yv              // Change the direction of the velocity
    clc
    sbc #VelocityLoss       // Reduce velocity
    eor #$ff                // Flip the sign
    jsr store_yv
rts

change_to_move_down:
    jsr get_yv              // Change the direction of the velocity
    clc
    adc #VelocityLoss       // Reduce velocity
    eor #$ff                // Flip the sign
    jsr store_yv
rts

/*
    Move current sprite downwards
*/
move_down:
    lda SpriteIndex
    cmp #$00
    beq move_down_end       // Don' continue if we're working on the paddle

    // Make sure we don't move below the bottom of the screen, so do not
    // apply the velocity if the edge has already been hit.
    jsr get_yl
    cmp #ScreenBottomEdge   // Is bottom of screen hit?
    bcs move_down_end

    // OK go on and move the sprite
    jsr get_yv              // Get the Y-velocity (a positive number)
    jsr shift_right         // Apply only the 5 MSB of velocity
    sta temp                // Store the value in a temporary variable

    jsr get_yl
    clc
    adc temp                // Move down by the amount of velocity
    sta temp

    // Only actually move down if the ball has not already collided with the
    // paddle
    jsr get_flags
    and #%00000001
    bne store_position

    store_position:
      lda temp
      jsr store_yl
      cmp #ScreenBottomEdge   // Is bottom of screen hit?
      /*
          We don't want a normal bouncing effect, but rather loose a life and
          start again with a new ball.
          bcs change_to_move_up
      */
      bcs reset_game
    move_down_end:
rts

/*
    Simply stops the ball and drops it again. This should be replaced with a
    more elaborate you are dead effect. Note that the paddle position is not
    changed, as this would be confusing to the player since an actual paddle
    controller is used.
*/
reset_game:
    jsr reset_ball_position
    jsr gameDecreaseLives
    jsr gameUpdateLives
    
    lda wHudLives
    cmp #$00
    // We're not done yet, so continue the game
    bne reset_game_not_finished

    // We're done – play the end of game tune
    lda #1
    ldx #<music.init
    ldy #>music.init
    jsr music.init

    // Change to end of game mode
    lda MODE_END
    sta mode

    // Show the end game text
    LIBSCREEN_TIMED_TEXT(game_over_text)

    // update the high score (if requred)
    jsr gameUpdateHighScore
    reset_game_not_finished:
rts

reset_ball_position:
    ldx #$01
    stx SpriteIndex

    clc
    
    lda #$00
    jsr store_ya
    jsr store_xa
    jsr store_yv
    jsr store_xv

    lda start_x_position
    jsr store_xl
    
    lda start_y_position
    jsr store_yl
    
rts

/*
    Start moving from left to right.
*/
change_to_move_right:
    jsr get_xv              // Change the direction of the velocity
    clc
    adc #VelocityLoss       // Reduce velocity
    eor #$ff                // Flip the sign
    jsr store_xv
rts

/*
    Start moving from right to left.
*/
change_to_move_left:
    jsr get_xv              // Change the direction of the velocity
    clc
    sbc #VelocityLoss       // Reduce velocity
    eor #$ff                // Flip the sign
    jsr store_xv
rts

/*
    Determine whether or not the current sprite is at the right edge of the
    screen.
*/
right_edge:
    jsr get_xl
    clc
    cmp #ScreenRightEdge
    bcs change_to_move_left
rts

/*
    Determine whether or not the current sprite is at the left edge of the
    screen
*/
left_edge:
    jsr get_xl
    clc
    cmp #ScreenLeftEdge
    bcc change_to_move_right
rts

shift_right:
    clc
    ror
    clc
    ror
    clc
    ror
    clc
    ror
    clc
rts

/*
    Determine whether or not the ball has hit a game block
*/
check_brick_collision:

/*
    See docs/ball.png

    Pt = (6+6, 5)
    Pb = (6+6, 5+10)
    Pl = (6, 5+5)
    Pr = (6+12, 5+5)
*/

    lda SpriteIndex
    cmp #$00                    // Do not bother for the paddle, it will never
                                // hit one of the bricks.
    bne continue_check
    rts

    continue_check:
        // Test Pt
        LIBSPRITE_COLLISION(12, 6)
        // Test Pb
        LIBSPRITE_COLLISION(12, 14)
        // Test Pl
        LIBSPRITE_COLLISION(6, 10)
        // Test Pr
        LIBSPRITE_COLLISION(18, 10)
    rts

    /*
        The character under the sprite has the PETSCII code 128 or higher which
        means it is a game piece. So we detect exactly which and act
        accordingly.
    */
    character_hit:

        cmp #%11110000
        bcs bounce_on_brick

        // Brick that adds speed to the left
        cmp #$e0
        beq speed_left

        // Brick that adds speed to the right
        cmp #$e1
        beq speed_right

        // Brick that adds speed downwards
        cmp #$e2
        beq speed_down

        // Brick that adds speed upwards
        cmp #$e3
        beq speed_up

        lda #$20                    // Clear using space
        sta ($f7),y                 // Store in both left..
        iny                         // ..and right half of block
        sta ($f7),y

    bounce_on_brick:
        jsr gameIncreaseScore   // Increment he score
        jsr gameUpdateScore
        jsr gameUpdateHighScore
        jsr get_yv
        eor #$ff                // Flip the sign so that we get a positive number
        clc
        adc #$01                // fix after flip
        jsr store_yv

        jsr get_xv
        eor #$ff                // Flip the sign so that we get a positive number
        clc
        adc #$01                // fix after flip
        jsr store_xv
        jmp end_char

    // Accelerates the ball leftwards
    speed_left:
        jsr get_xv
        sbc #$10
        jsr store_xv
        jmp end_char

    // Accelerates the ball rightwards
    speed_right:
        jsr get_xv
        adc #$10
        jsr store_xv
        jmp end_char

    // Accelerates the ball upwards
    speed_up:
        jsr get_yv
        sbc #$20
        jsr store_yv
        jmp end_char

    // Accelerates the ball downwards
    speed_down:
        jsr get_yv
        adc #$10
        jsr store_yv
        jmp end_char

    end_char:
        rts

check_paddle_collision:

    // Do not perform the check if the paddle is the current sprite
    lda SpriteIndex
    cmp #$00
    beq end_check_paddle_collision

    // Reset the collision with paddle flag
    jsr get_flags
    and #%11111110
    jsr store_flags

    jsr get_xl              // x-position LSB of ball
    sta balllo

    sec
    lda balllo
    sbc SpriteMem           // x-position LSB of paddle
    sta reslo

    sec
    lda reslo
    sbc #$11
    sta reslo

    bpl right_of_paddle     // The ball is on the right side of the padde

    clc
    lda balllo
    adc #$11
    sta balllo

    sec
    lda balllo
    sbc SpriteMem           // x-position LSB of paddle
    sta reslo

    bmi left_of_paddle      // The ball is on the left side of the paddle

    jsr bounce_off_paddle
    jsr end_check_paddle_collision
    rts

    left_of_paddle:
        //FRAME_COLOR(1) // white
        rts
    right_of_paddle:
        //FRAME_COLOR(2) // right
        rts
    end_check_paddle_collision:
        // store collision flag
        jsr get_flags
        ora #%00000001
        jsr store_flags
rts

bounce_off_paddle:
    // Check if the ball is above the paddle. If so we can just return
    jsr get_yl
    cmp #TopOfPaddle
    bcc end_check_paddle_collision // less than
    beq stop_ball               // Make it rest on the paddle if velocity is low
    //cmp #TopOfPaddle+4          // If already below the paddle, just go through
    //bcs bounce_end

    bounce:
        jsr get_yv              // Change the direction of the velocity
        clc
        eor #$ff                // Flip the sign
        clc
        adc #VelocityLoss
        jsr store_yv

        // Add effect of a slightly tilted paddle in order to control exit angle
        jsr get_xl
        sbc SpriteMem
        rol
        rol
        jsr store_xv

		// Toggle the left/right position of the bat
        lda demoInputToggle		
        eor #$01
        sta demoInputToggle

        // The paddle button is pressed, so we're going to negate the effect
        // of the velocity loss when the ball hits the bat
        clc
        lda ball_speed_up
        cmp #%00000000
        beq bounce_end

        jsr get_yv              // Change the direction of the velocity
        sbc #VelocityLoss+3
        jsr store_yv

    bounce_end:    
rts
/*
    This function will stop the ball if the velocity is too low. This is used
    to make it rest on top of the paddle.
*/
stop_ball:
    jsr get_yv
    clc
    cmp #Gravity
    bpl bounce
    lda #$08    // (Gravity + Velocityloss) times two?
    jsr store_yv
    jmp bounce

.macro LIBSPRITE_COLLISION(xOffset, yOffset) {
    jsr get_xl
    clc
    sbc #VIS_SCREEN_LEFT
    adc #xOffset
    sta ZeroPage10
    jsr get_yl
    clc
    sbc #VIS_SCREEN_TOP
    adc #yOffset
    sta ZeroPage11
    jsr get_brick_at_xy
    cmp #$80
    bcs character_hit
}

get_brick_at_xy:
    lda ZeroPage10
    lsr                     // MSB -> C, divide by 2
    lsr                     // Divide by 2 again
    lsr                     // Divide by 2 again
    lsr                     // Deal with having double witdh blocks
    asl
    sta column

    lda ZeroPage11
    lsr                     // Divide by 2
    lsr                     // Divide by 2 again
    lsr                     // And divide by 2 a last time
    sta row                 // Store it for later

    ldx row
    lda ScreenMemLowByte,x
    sta $f7
    lda ScreenMemHighByte,x
    sta $f8

    ldy column
    lda ($f7),y
    rts
