/*
    Sprite handling library
    
    Copyright (c) 2020-2025 Itema AS

    Written by:
    - Øystein Steimler, ofs@itema.no
    - Torkild U. Resheim, tur@itema.no
*/

#importonce
#import "libSpriteData.asm"
#import "libScreen.asm"
#import "libMath.asm"
#import "libGame.asm"

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

BallSpriteMask:
    .byte %00000001
    .byte %00000010
    .byte %00000100
    .byte %00001000

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

.const ScreenTopEdge    = 47
.const ScreenBottomEdge = 243
.const ScreenRightEdge  = 213
.const ScreenLeftEdge   = 20
.const Gravity          = 2
.const VelocityLoss     = 2
.const MaxBallCount     = 3
.const ExtraBallStartX  = ScreenLeftEdge + BallOffset
.const ExtraBallStartY  = ScreenTopEdge + BallOffset
.const ExtraBallStartXV = $20
.const ExtraBallStartYV = $00
/*
    Adjust these values for the sensitivity when detecting whether or not the
    balls have collided. Smaller value means balls will practically overlap.
*/
.const BallCollisionThresholdX = $0c  // Max horizontal distance for collision
.const BallCollisionThresholdY = $0c  // Max vertical distance for collision

.const PaddleStateWide         = %00000001

paddleStateFlags:
    .byte %00000000
paddleWidthCurrent:
    .byte PaddleWidthNormal
paddleRightBoundCurrent:
    .byte PaddleRightBoundsNormal
paddleReachLeftCurrent:
    .byte PaddleReachLeftNormal
paddleReachRightCurrent:
    .byte PaddleReachRightNormal
paddleCenterCurrent:
    .byte PaddleCenterNormal

paddle_update_geometry:
    lda paddleStateFlags
    and #PaddleStateWide
    bne paddle_apply_wide

paddle_apply_normal:
    lda #PaddleWidthNormal
    sta paddleWidthCurrent
    lda #PaddleRightBoundsNormal
    sta paddleRightBoundCurrent
    lda #PaddleReachLeftNormal
    sta paddleReachLeftCurrent
    lda #PaddleReachRightNormal
    sta paddleReachRightCurrent
    lda #PaddleCenterNormal
    sta paddleCenterCurrent
    lda #paddleSpriteData/64
    sta SPRITE0PTR
    rts

paddle_apply_wide:
    lda #PaddleWidthWide
    sta paddleWidthCurrent
    lda #PaddleRightBoundsWide
    sta paddleRightBoundCurrent
    lda #PaddleReachLeftWide
    sta paddleReachLeftCurrent
    lda #PaddleReachRightWide
    sta paddleReachRightCurrent
    lda #PaddleCenterWide
    sta paddleCenterCurrent
    lda #widePaddleSpriteData/64
    sta SPRITE0PTR
    rts

paddle_enable_wide:
    lda paddleStateFlags
    and #PaddleStateWide
    bne paddle_enable_wide_no_change
    jsr paddle_enable_wide_silent
    jsr sfx_play_paddle_grow
    rts

paddle_enable_wide_no_change:
    jsr paddle_update_geometry
    rts

paddle_enable_wide_silent:
    lda paddleStateFlags
    ora #PaddleStateWide
    sta paddleStateFlags
    jsr paddle_update_geometry
    rts

paddle_disable_wide:
    lda paddleStateFlags
    and #PaddleStateWide
    beq paddle_disable_wide_no_change
    jsr paddle_disable_wide_silent
    jsr sfx_play_paddle_shrink
    rts

paddle_disable_wide_no_change:
    jsr paddle_update_geometry
    rts

paddle_disable_wide_silent:
    lda paddleStateFlags
    and #%11111110
    sta paddleStateFlags
    jsr paddle_update_geometry
    rts

/*
    Sprite geometry offsets used when determining paddle collisions. The values
    specify the first and last rows of visible pixels within each sprite so
    that we can calculate overlaps based on the actual graphics instead of
    hardcoded screen positions.
*/
.const TopOfPaddle          = 226
.const BrickCollisionAxisVertical   = %00000001
.const BrickCollisionAxisHorizontal = %00000010

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

tempXp:
    .byte %00000000
tempYp:
    .byte %00000000
tempXv:
    .byte %00000000
tempYv:
    .byte %00000000
tempXa:
    .byte %00000000
tempYa:
    .byte %00000000

column:
    .byte %00000000
row:
    .byte %00000000
/*
    Indicates which axis the latest brick collision touched.
*/
brickCollisionAxis:
    .byte %00000000

/*
	Used to determine whether or not to place the bat to the left or
	to the right of the ball when in input mode.
*/
demoInputToggle:
    .byte 1

ballCollisionIndex:
    .byte $00
ballCollisionOtherIndex:
    .byte $00
ballCollisionX:
    .byte $00
ballCollisionY:
    .byte $00
ballCollisionXV:
    .byte $00
ballCollisionYV:
    .byte $00
ballCollisionOtherX:
    .byte $00
ballCollisionOtherY:
    .byte $00
ballCollisionOtherXV:
    .byte $00
ballCollisionOtherYV:
    .byte $00
ballCollisionOffset:
    .byte $00
ballCollisionOtherOffset:
    .byte $00
ballCollisionSavedIndex:
    .byte $00

/*
    Indicates that the current sprite was removed during processing so the
    rest of the per-frame pipeline can be skipped.
*/
spriteRemoved:
    .byte $00
/*
    Keep track of these two variables while debugging
    Press CMD/CTRL+W to see the actual values in the C64 Debugger.
*/
//.watch column
//.watch row

reslo:
    .byte %00000000
balllo:
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
    
    /*
        Animate the sprite
    */
    lda SpriteIndex
    beq draw_sprite_end         // Only animate the balls
    
    jsr get_frame               // Load the current animation frame into A
    sta temp                    // Keep current frame in temp

    jsr get_xv                  // Get horizontal velocity
    sta temp1                   // Preserve value for later
    cmp #$00
    bmi rotate_left             // Negative velocity rotates left

    // Velocity is zero or positive -- rotate right
    jsr shift_right             // step = velocity >> 4
    clc
    ror                         // Divide by two again -> velocity >> 5
    sta temp2
    lda temp
    clc
    adc temp2
    jmp continue_animation

    rotate_left:
        lda temp1
        eor #$ff                // step = abs(velocity)
        clc
        ror                     // Divide by two again -> velocity >> 5
        adc #$01
        jsr shift_right
        sta temp2
        lda temp
        sec
        sbc temp2

    continue_animation:
    bmi wrap_negative           // Handle values < 0 by adding 12 until positive
wrap_positive:
    cmp #$0c
    bcc frame_wrapped
    sec
    sbc #$0c
    jmp wrap_positive

wrap_negative:
    clc
    adc #$0c
    bmi wrap_negative
    jmp wrap_positive

frame_wrapped:
    sta temp                    // Store updated frame within [0,11]
    jsr store_frame
    asl                         // Multiply by two to index word table
    tay
    lda SpriteIndex
    tax                         // Put the sprite number in X
    lda BallFramePtr,y          // Load sprite pointer value
    sta $07f8,x
    lda temp
    jsr store_frame
    draw_sprite_end:
    
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
    jsr h_acceleration          // Apply horizontal acceleration
    jsr get_xv
    clc
    cmp #$00                    // Compare with signed integer
    bmi move_left               // Move left if value is negative
    bpl move_right              // Move right if value is positive
rts
/*
    Move current sprite left
*/
move_left:
    jsr get_xv                  // Get the X-velocity (which is negative)
    eor #$ff                    // Flip the sign so that we get a positive number
    clc
    adc #$01                    // fix after flip
    jsr shift_right             // Apply only the 5 MSB of velocity
    sta temp                    // Store the new value in a variable
    jsr get_xl
    sec
    sbc temp                    // Move left by the amount of velocity
    jsr store_xl
    jsr left_edge
rts

/*
    Move current sprite right
*/
move_right:
    jsr get_xv                  // Get the X-velocity (a positive number)
    jsr shift_right             // Apply only the 5 MSB of velocity
    sta temp                    // Store the value in a temporary variable
    jsr get_xl
    clc
    adc temp                    // Move right by the amount of velocity
    jsr store_xl
    jsr right_edge
rts

/*
    Apply the acceleration to the velocity, moving up. Once passing $FF (-1) the
    direction will change to moving downwards. This transition causes some
    velocity to be lost.
*/
bounce_up:
    jsr get_yv
    clc
    adc #Gravity                // Simulate gravity
    jsr store_yv
    bounce_up_end:
rts

/*
    Apply the acceleration to the velocity, moving down. Make sure that the
    maximum value of #$7f is not exceeded because that would mean moving up.
*/
fall_down:
    jsr get_yv
    clc
    adc #Gravity                // Simulate gravity
    cmp #$80                    // Never go negative
    bpl fall_down_end
    jsr store_yv
    fall_down_end:
rts

/*
    Apply horizontal acceleration from input
*/
h_acceleration:
    jsr get_xa
    sta temp                    // Store the new value in a variable
    jsr get_xv
    clc
    adc temp                    // Add acceleration to velocity
    clv                         // Clear the overflow flag
    bvs h_acceleration_end      // Do not store the value if the sign was flipped
    jsr store_xv
    h_acceleration_end:
rts

/*
    Perform vertical movement
*/
move_vertically:
    jsr get_flags               // Se if the "resting on paddle bit" is set
    and #%00000010
    bne resting_on_paddle

    jsr v_acceleration          // Apply vertical acceleration
    jsr get_yv
    clc
    cmp #$00                    // Compare with signed integer
    bmi up                      // Move up if value is negative
    bpl move_down               // Move down if value is positive

resting_on_paddle:
    lda #TopOfPaddle            // Keep resting balls aligned with the paddle surface
    jsr store_yl
dont_move_vertically:
rts

/*
    Apply vertical acceleration from input along with gravity
*/
v_acceleration:
    jsr get_ya
    sta temp                    // Store the new value in a variable
    jsr get_yv
    clv                         // Clear the overflow flag
    adc temp                    // Add Y to A
    bvs v_acceleration_end      // Do not store the value if the sign was flipped
    jsr store_yv
    // -- Apply gravity
    cmp #$00                    // Compare with signed integer
    bpl fall_down               // Move down if value is positive
    bmi bounce_up               // Move up if value is negative
    v_acceleration_end:
rts

/*
    Move current sprite upwards
*/
up:
    jsr get_yv                  // Get the Y-velocity (a negative number)
    eor #$ff                    // Flip the sign so that we get a positive number
    clc
    jsr shift_right             // Apply only the 5 MSB of velocity
    sta temp                    // Store the new value in a variable
    jsr get_yl
    sec                         // Set the carry flag
    sbc temp                    // Move up by the amount of velocity
    jsr store_yl
    cmp #ScreenTopEdge          // Is top of screen hit?
    bcs up_done
    lda #ScreenTopEdge
    jsr store_yl
    jsr change_to_move_down
    rts

up_done:
rts


/*
    Flip the sign on the vertical velocity and acceleration
*/
change_to_move_up:
    jsr get_yv                  // Change the direction of the velocity
    clc
    sbc #VelocityLoss           // Reduce velocity
    eor #$ff                    // Flip the sign
    jsr store_yv
rts

change_to_move_down:
    jsr get_yv                  // Change the direction of the velocity
    clc
    adc #VelocityLoss           // Reduce velocity
    eor #$ff                    // Flip the sign
    jsr store_yv
rts

/*
    Move current sprite downwards
*/
move_down:
    lda SpriteIndex
    cmp #$00
    beq move_down_end           // Don' continue if we're working on the paddle

    // Make sure we don't move below the bottom of the screen, so do not
    // apply the velocity if the edge has already been hit.
    jsr get_yl
    cmp #ScreenBottomEdge       // Is bottom of screen hit?
    bcs move_down_end

    // OK go on and move the sprite
    jsr get_yv                  // Get the Y-velocity (a positive number)
    jsr shift_right             // Apply only the 5 MSB of velocity
    sta temp                    // Store the value in a temporary variable

    jsr get_yl
    clc
    adc temp                    // Move down by the amount of velocity
    sta temp

    // Only actually move down if the ball has not already collided with the
    // paddle
    jsr get_flags
    and #%00000001
    bne store_position

    store_position:
      lda temp
      jsr store_yl
      cmp #ScreenBottomEdge     // Is bottom of screen hit?
      /*
          We don't want a normal bouncing effect, but rather loose a life and
          start again with a new ball.
      */
      bcs ball_lost
    move_down_end:
rts
/*
    Initialize sprite data – positions, velocity and accelleration.
    Balls that are not to be shown are placed at 0,0 to keep them out of
    the way.
*/
reset_sprite_data:
    sei
    ldx #0
@lp: 
    lda BackupMem,x
    sta SpriteMem,x
    inx
    cpx #SpriteDataSize
    bne @lp
    lda BallCount
    clc
    adc #$01
    tay
    tya
    asl
    asl
    asl
    tax
    lda #$00
@zero:
    sta SpriteMem,x
    inx
    cpx #SpriteDataSize
    bne @zero
    cli
rts

ball_lost:
    jsr sfx_play_ball_lost

    lda #$00
    sta spriteRemoved

    lda SpriteIndex
    cmp #$02
    bcc ball_lost_primary
    jmp ball_lost_extra

ball_lost_primary:
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

    
    lda MODE_END
    sta mode                    // Change to end of game mode
    jsr sfx_disable

    // Show the end game text
    LIBSCREEN_TIMED_TEXT(game_over_text)

    // update the high score (if requred)
    jsr gameUpdateHighScore
reset_game_not_finished:
    jsr reset_sprite_data
    // But override the ball #1 position as this has been set by the level
    // designer.
    lda StartingXPosition
    sta SpriteMem+8
    lda StartingYPosition
    sta SpriteMem+9
    // Cue the player before the next launch, unless the game just ended
    lda wHudLives
    beq @skip_ready_text
    LIBSCREEN_TIMED_TEXT(get_ready_text)
@skip_ready_text:
rts

ball_lost_extra_highest:
    lda temp
    tax
    lda SPENA
    and ClearTable,x
    sta SPENA

    lda temp
    sta SpriteIndex
    jsr clear_msb
    jsr clear_sprite_slot

    dec BallCount
    lda BallCount
    sta SpriteIndex
    lda #$01
    sta spriteRemoved
rts

ball_lost_extra:
    lda SpriteIndex
    sta temp                    // Keep the index that triggered the loss

    lda BallCount
    sta temp1                   // Highest active ball index
    cmp temp
    beq ball_lost_extra_highest

    // Copy sprite state from the highest active ball into the current slot
    lda temp1
    sta SpriteIndex
    jsr get_xl                  // X-position
    sta tempXp
    jsr get_yl
    sta tempYp                  // Y-position

    jsr get_xa                  // X-accelleration
    sta tempXa
    jsr get_ya
    sta tempYa                  // Y-accelleration

    jsr get_xv                  // X-velocity
    sta tempXv
    jsr get_yv
    sta tempYv                  // Y-velocity

    lda temp
    sta SpriteIndex
    lda tempXp
    jsr store_xl
    lda tempYp
    jsr store_yl
    lda tempXa
    jsr store_xa
    lda tempYa
    jsr store_ya
    lda tempXv
    jsr store_xv
    lda tempYv
    jsr store_yv

    // Move the MSB state from the highest ball into the new slot
    lda temp1
    tax
    lda MSIGX
    and SetTable,x
    beq ball_lost_extra_clear_dest_msb

    lda temp
    tax
    lda MSIGX
    ora SetTable,x
    sta MSIGX
    jmp ball_lost_extra_msb_done

ball_lost_extra_clear_dest_msb:
    lda temp
    tax
    lda MSIGX
    and ClearTable,x
    sta MSIGX

ball_lost_extra_msb_done:
    // Disable and clear the former highest ball slot
    lda temp1
    tax
    lda SPENA
    and ClearTable,x
    sta SPENA

    lda temp1
    sta SpriteIndex
    jsr clear_msb
    jsr clear_sprite_slot

    lda temp
    sta SpriteIndex

    dec BallCount
rts

clear_sprite_slot:
    jsr getspritebase
    tax
    stx temp1

    lda temp1
    clc
    adc #spritelen
    sta temp2

    lda #$00

clear_sprite_slot_loop:
    sta SpriteMem,x
    inx
    cpx temp2
    bne clear_sprite_slot_loop
rts

/*
    When the current ball is motionless, place it on top of the paddle and
    align the horizontal position with the paddle.
*/
follow_paddle:
    lda SpriteIndex
    beq follow_paddle_end       // Ignore the paddle

    jsr get_flags               // Se if the resting on paddle bit is set
    and #%00000010
    beq follow_paddle_end       // If not we don't follow the paddle

    // Center the ball based on the current paddle width
    lda SpriteMem               // Paddle X position
    clc
    adc paddleCenterCurrent
    sec
    sbc #BallCenterOffset
    jsr store_xl

    follow_paddle_end:
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

reverse_vertical_velocity:
    jsr get_yv
    eor #$ff
    clc
    adc #$01
    jsr store_yv
rts

reverse_horizontal_velocity:
    jsr get_xv
    eor #$ff
    clc
    adc #$01
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

/*******************************************************************************
 BRICK COLLISION HANDLING
*******************************************************************************/
check_brick_collision:
//    lda #$00
//    sta brickCollisionAxis      // Reset the collision indicator

/*
    See docs/ball.png

    Pt = (6+6, 5)       TOP
    Pb = (6+6, 5+10)    BOTTOM
    Pl = (6, 5+5)       LEFT
    Pr = (6+12, 5+5)    RIGHT
*/

    lda SpriteIndex
    cmp #$00                    // Do not bother for the paddle, it will never
                                // hit one of the bricks.
    bne continue_check
    rts

    continue_check:
        lda #BrickCollisionAxisVertical
        sta brickCollisionAxis
        // Test Pt – TOP
        LIBSPRITE_COLLISION(12, 5)
        lda #BrickCollisionAxisVertical
        sta brickCollisionAxis
        // Test Pb – BOTTOM
        LIBSPRITE_COLLISION(12, 15)
        lda #BrickCollisionAxisHorizontal
        sta brickCollisionAxis
        // Test Pl - LEFT
        LIBSPRITE_COLLISION(6, 10)
        lda #BrickCollisionAxisHorizontal
        sta brickCollisionAxis
        // Test Pr - RIGHT
        LIBSPRITE_COLLISION(18, 10)
    rts

    clear_brick:
        lda #$20                // Clear using space
        sta (ZeroPage_PtrLo),y
        iny
        sta (ZeroPage_PtrLo),y
        jsr brick_updates
    rts
    
    extra_ball_brick:
        jsr clear_brick
        jsr spawn_extra_ball
        jmp bounce_on_brick

    expand_paddle_brick:
        jsr clear_brick
        jsr paddle_enable_wide
        jmp bounce_on_brick
    
    /*
        The character under the sprite has the PETSCII code 128 or higher which
        means it is a game piece. So we detect exactly which and act
        accordingly.
    */
    character_hit:

        cmp #$f0                // simply bounce if a wall/hard brick
        bcs bounce_on_brick     // If A ≥ 240 → bounce

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

        // Brick that spawns an extra ball
        cmp #$82
        beq extra_ball_brick

        cmp #$83
        beq extra_ball_brick

        cmp #$86
        beq expand_paddle_brick

        cmp #$87
        beq expand_paddle_brick

        jsr clear_brick
        jmp bounce_on_brick

    bounce_on_brick:
        lda brickCollisionAxis
        bne bounce_on_brick_axis_ready
        lda #(BrickCollisionAxisVertical | BrickCollisionAxisHorizontal)
        sta brickCollisionAxis

    bounce_on_brick_axis_ready:
        lda brickCollisionAxis
        and #BrickCollisionAxisVertical
        beq bounce_on_brick_check_horizontal
        jsr reverse_vertical_velocity

    bounce_on_brick_check_horizontal:
        lda brickCollisionAxis
        and #BrickCollisionAxisHorizontal
        beq bounce_on_brick_end
        jsr get_xv
        bne bounce_on_brick_apply_horizontal
        lda brickCollisionAxis
        and #BrickCollisionAxisVertical
        bne bounce_on_brick_end
        jsr reverse_vertical_velocity
        jmp bounce_on_brick_end

    bounce_on_brick_apply_horizontal:
        jsr reverse_horizontal_velocity

    bounce_on_brick_end:
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
        lda #$00
        sta brickCollisionAxis
    // We're done with checking bricks, now do all the post check updates
rts

spawn_extra_ball:
    txa
    pha
    tya
    pha

    lda BallCount
    cmp #MaxBallCount
    bcs spawn_extra_ball_restore

    inc BallCount
    lda BallCount
    tax

    lda SPENA
    ora BallSpriteMask,x
    sta SPENA

    lda SpriteIndex
    pha
    lda BallCount
    sta SpriteIndex

    lda #ExtraBallStartX
    jsr store_xl
    lda #ExtraBallStartY
    jsr store_yl
    lda #$00
    jsr store_xa
    lda #$00
    jsr store_ya
    lda #ExtraBallStartXV
    jsr store_xv
    lda #ExtraBallStartYV
    jsr store_yv
    lda #$00
    jsr store_flags
    lda #$00
    jsr store_frame

    pla
    sta SpriteIndex

spawn_extra_ball_restore:
    pla
    tay
    pla
    tax
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

    jsr get_xl                  // x-position LSB of ball
    sta balllo

    lda balllo
    clc
    adc #BallOffset
    sta temp1                   // Ball left edge (visible pixels)

    lda temp1
    clc
    adc #BallWidth
    sta temp2                   // Ball right edge (visible pixels)

    lda SpriteMem
    sta temp                    // Paddle left edge

    lda temp
    clc
    adc paddleWidthCurrent
    sta reslo                   // Paddle right edge

    lda temp2
    cmp temp
    bcc left_of_paddle          // Ball entirely left of the paddle

    lda temp1
    cmp reslo
    bcs right_of_paddle         // Ball entirely right of the paddle

    jsr bounce_off_paddle
    jsr end_check_paddle_collision
    rts

    left_of_paddle:
        rts
    right_of_paddle:
        rts
    end_check_paddle_collision:
        // store collision flag
        jsr get_flags
        ora #%00000001
        jsr store_flags
    rts

/*
    Test if any balls have been colliding and if so do the proper changes in
    direction. Velocity is not changed. Let's pretend the balls are made out
    of really hard steel.
*/
check_ball_collisions:
    lda BallCount
    cmp #$02
    bcs cbc_start
rts

cbc_start:
    lda SpriteIndex
    sta ballCollisionSavedIndex
    lda #$01
    sta ballCollisionIndex

cbc_outer_loop:
    lda ballCollisionIndex
    cmp BallCount
    bcc cbc_outer_prepare
    jmp cbc_restore

cbc_outer_prepare:

    asl                         // index * 2
    asl                         // index * 4
    asl                         // index * 8
    sta ballCollisionOffset
    tax
    lda SpriteMem,x
    sta ballCollisionX
    lda SpriteMem+1,x
    sta ballCollisionY
    lda SpriteMem+2,x
    sta ballCollisionXV
    lda SpriteMem+3,x
    sta ballCollisionYV

    lda ballCollisionIndex
    clc
    adc #$01
    sta ballCollisionOtherIndex

cbc_inner_loop:
    lda ballCollisionOtherIndex
    cmp BallCount
    bcc cbc_process_pair
    beq cbc_process_pair
    jmp cbc_next_outer

cbc_process_pair:
    lda ballCollisionOtherIndex
    cmp ballCollisionIndex
    beq cbc_inner_advance

    asl
    asl
    asl
    sta ballCollisionOtherOffset
    tax
    lda SpriteMem,x
    sta ballCollisionOtherX
    lda SpriteMem+1,x
    sta ballCollisionOtherY

    lda ballCollisionX
    sec
    sbc ballCollisionOtherX
    bpl cbc_dx_positive
    eor #$ff
    clc
    adc #$01

cbc_dx_positive:
    cmp #BallCollisionThresholdX
    bcs cbc_inner_advance

    lda ballCollisionY
    sec
    sbc ballCollisionOtherY
    bpl cbc_dy_positive
    eor #$ff
    clc
    adc #$01

cbc_dy_positive:
    cmp #BallCollisionThresholdY
    bcs cbc_inner_advance

    ldx ballCollisionOtherOffset
    lda SpriteMem+2,x
    sta ballCollisionOtherXV
    lda SpriteMem+3,x
    sta ballCollisionOtherYV

    ldx ballCollisionOffset
    lda ballCollisionOtherXV
    sta SpriteMem+2,x
    lda ballCollisionOtherYV
    sta SpriteMem+3,x

    ldx ballCollisionOtherOffset
    lda ballCollisionXV
    sta SpriteMem+2,x
    lda ballCollisionYV
    sta SpriteMem+3,x

    lda ballCollisionOtherXV
    sta ballCollisionXV
    lda ballCollisionOtherYV
    sta ballCollisionYV

cbc_inner_advance:
    lda ballCollisionOtherIndex
    clc
    adc #$01
    sta ballCollisionOtherIndex
    jmp cbc_inner_loop

cbc_next_outer:
    lda ballCollisionIndex
    clc
    adc #$01
    sta ballCollisionIndex
    jmp cbc_outer_loop

cbc_restore:
    lda ballCollisionSavedIndex
    sta SpriteIndex
rts

/*
    Determine whether or not the fire button should be virtually pressed in
    order for the paddle to launch the ball. 
*/
demo_input_should_fire:
    // We only care about this in demo mode
    lda mode
    cmp MODE_INTRO
    bne demo_input_should_fire_end

    // We only care about the balls
    lda SpriteIndex
    beq demo_input_should_fire_end

    clc
    jsr get_flags               // Se if the resting on paddle bit is set
    and #%00000010
    beq demo_input_should_fire_end
    lda #$01
    sta bFireButtonPressed
    
    demo_input_should_fire_end:
rts

bounce_off_paddle:
    // See if the fire-button should be virtually pressed
    jsr demo_input_should_fire


    // Check if the ball is above the paddle. If so we can just return
    jsr get_yl
    cmp #TopOfPaddle
    bcs bounce_off_paddle_check_fire
    jsr end_check_paddle_collision
rts

    // Is the fire button pressed?
bounce_off_paddle_check_fire:
    lda #TopOfPaddle            // Clamp captured balls to the paddle top before handling input
    jsr store_yl

    lda bFireButtonPressed
    cmp #%00000000
    beq bounce_off_paddle_cont
    // Launch the ball
    jsr launch_ball
    
    bounce_off_paddle_cont:

    /*
        Stop the ball if the velocity is too low. This is used to make it rest
        on top of the paddle so that it can be be launched.
    */
    jsr get_yv
    cmp #Gravity                // Compare with gravity, which is always present
    bpl bounce                  // We still have movement

    lda #$00
    jsr store_yv
    jsr store_xv
    jsr store_ya
    jsr store_xa
    
    jsr get_flags               // Set the resting on paddle flag
    sta temp
    and #%00000010
    bne bounce_flag_already_set
    jsr sfx_play_paddle_hit
bounce_flag_already_set:
    lda temp
    ora #%00000010
    jsr store_flags
    FRAME_COLOR(3)              // Use the pretty color to indicate the state
    jmp bounce_end              // No bounce for you

    bounce:
        FRAME_COLOR(0)          // Normal bounce
        jsr get_yv              // Change the direction of the velocity
        clc
        eor #$ff                // Flip the sign
        clc
        adc #VelocityLoss
        jsr store_yv

        // Add effect of a slightly tilted paddle in order to control exit angle
        jsr get_xl
        clc
        adc #BallOffset
        sta temp1
        lda #BallWidth
        lsr                     // use half the ball width to find the centre
        clc
        adc temp1
        sta temp1
        lda SpriteMem
        clc
        adc paddleCenterCurrent
        sta temp2
        lda temp1
        sec
        sbc temp2
        rol
        rol
        jsr store_xv

        // Toggle the left/right position of the bat
        lda demoInputToggle
        eor #$01
        sta demoInputToggle

        // The paddle button is pressed, so we're going to negate the effect
        // of the velocity loss when the ball hits the bat
        lda bFireButtonPressed
        cmp #%00000000
        beq bounce_play_normal

        // Add some extra velocity to the ball
        jsr get_yv          // Change the direction of the velocity
        sbc #VelocityLoss+8
        jsr store_yv
        jsr sfx_play_paddle_power
        jmp bounce_end

    bounce_play_normal:
        jsr sfx_play_paddle_hit

    bounce_end:
rts

launch_ball:
    clc
    jsr get_flags               // Se if the resting on paddle bit is set
    and #%00000010
    beq end_launch_ball

    lda #$0
    jsr store_flags
    
    lda #LAUNCH_VELOCITY        // Give the ball a decent downwward velovity, note
    jsr store_yv                // that this will immediately switch to upward
                                // movement in the code labeled "bounce". Which is
                                // why this value is positive instead of negative.

    jsr sfx_play_launch

    end_launch_ball:
rts

advance_level:
    // Always start with a normal paddle
    jsr paddle_disable_wide_silent
    // Move forward to next level
    inc CurrentLevel
    lda CurrentLevel
    cmp #NumberOfLevels+1
    bne load_level
        // Start with Level #1 again
        lda #$01
        sta CurrentLevel
        // Get an extra life for finishing
        jsr gameIncreaseLives
        // XXX: Play a nice tune when rounding the game
load_level:
    ldx CurrentLevel
    lda level_chars_lo,x
    sta $fe
    lda level_chars_hi,x
    sta $ff
    jsr load_screen
    jsr gameUpdateScore
    jsr gameUpdateHighScore
    jsr gameUpdateLives
    // Reset to a single ball when starting the next level
    lda #$01
    sta BallCount
    lda #%11000011
    sta SPENA
    // Put the sprites in the correct position
    jsr reset_sprite_data
    // But override the ball #1 position as this has been set by the level
    // designer.
    lda StartingXPosition
    sta SpriteMem+8
    lda StartingYPosition
    sta SpriteMem+9
    LIBSCREEN_TIMED_TEXT(get_ready_text)
    jsr sfx_play_level_start
rts

/*
    All the stuff that happens after a brick is removed:
    - Update score with one point
    - Potentially update high score
    - Add an extra life if another 50 points has been reached
    - Load next level if done with all the bricks
*/
brick_updates:
    dec BrickCount
    //jsr calculate_brick_count
    // We have scored one more point
    jsr gameIncreaseScore
    jsr gameUpdateScore
    //jsr gameUpdateBricks        // XXX: For debugging
    jsr gameUpdateHighScore
    jsr gameCheckExtraLife
    bcc no_extra_life_award
    jsr gameIncreaseLives
    jsr gameUpdateLives
    jsr sfx_play_extra_life
    jmp brick_score_sound_done

no_extra_life_award:
    jsr sfx_play_brick_score

brick_score_sound_done:
    lda BrickCount
    // Advance level if we have hit all the bricks
    bne end_brick_updates
    lda LevelCompletePending
    bne end_brick_updates
    lda #LEVEL_PENDING_SHOW_MESSAGE
    sta LevelCompletePending
    end_brick_updates:
rts

/*
    Used to determine whether or not a character is hit by a ball
*/
.macro LIBSPRITE_COLLISION(xOffset, yOffset) {
    jsr get_xl
    sec
    sbc #VIS_SCREEN_LEFT
    adc #xOffset
    sta ZeroPage10
    jsr get_yl
    sec
    sbc #VIS_SCREEN_TOP
    adc #yOffset
    sta ZeroPage11
    jsr get_brick_at_xy
    cmp #$80
    bcs character_hit           // If A ≥ 128 (first brick character)
}

get_brick_at_xy:
    lda ZeroPage10
    cmp #$d0                    // Discard values outside the playfield (>= 208)
    bcs no_brick
    lsr                         // MSB -> C, divide by 2
    lsr                         // Divide by 2 again
    lsr                         // Divide by 2 again
    lsr                         // Deal with having double witdh blocks
    asl
    cmp #23                      // Bail out if the column would be outside the playfield
    bcs no_brick
    sta column

    lda ZeroPage11
    cmp #$d1                    // Ignore rows outside the playable area (>= 209)
    bcs no_brick
    lsr                         // Divide by 2
    lsr                         // Divide by 2 again
    lsr                         // And divide by 2 a last time
    cmp #24                     // Bail out if the row would exceed 24
    bcs no_brick
    sta row                     // Store it for later

    ldx row
    lda ScreenMemLowByte,x
    sta ZeroPage_PtrLo
    lda ScreenMemHighByte,x
    sta ZeroPage_PtrHi

    ldy column
    lda (ZeroPage_PtrLo),y
    rts

no_brick:
    lda #$00
    rts
