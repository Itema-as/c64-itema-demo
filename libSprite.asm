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
    Sprite box
*/
.const ScreenTopEdge    = $2e // $2e
.const ScreenBottomEdge = $eb // 229+6
.const ScreenRightEdge  = $d7 // 231
.const ScreenLeftEdge   = $14
.const Gravity          = $02
.const VelocityLoss     = $01

.const TopOfPaddle      = $e3 // 224 (bottom) - 3 (paddle hight) + 6 (margin)

fire:
    .byte $0

.var accelerated_movement_timer = $2

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

    // set horizontal position msb
    jsr get_xm
    cmp #$01
    beq set_msb
    
    jsr get_xm
    cmp #$00
    beq clear_msb
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
    jsr get_xm
    sbc #$00                // Subtract zero and borrow from lsb subtraction
    jsr store_xm
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
    jsr get_xm
    adc #$00                // Add zero and carry from lsb addition
    jsr store_xm
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
    beq move_down_end

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

    // Only actually move if the ball has not collided with the paddle
    jsr get_flags
    cmp #$01                
    bne store_position

    lda temp
    cmp #TopOfPaddle
    bcc store_position
    lda #TopOfPaddle
    jsr store_yl
    jmp move_down_end

    store_position:
    lda temp
    jsr store_yl
    cmp #ScreenBottomEdge   // Is bottom of screen hit?
    /*
        We don't want a normal bouncing effect, but rather loose a life and
        start again with a new ball.
        bcs change_to_move_up
    */
    bcs stop
    move_down_end:
rts

/*
    Simply stops the ball and drops it again. This should be replaced with a
    more elaborate you are dead effect. Note that the paddle position is not
    changed, as this would be confusing to the player since an actual paddle
    controller is used.
*/
stop:
    lda #$00
    jsr store_xa
    jsr store_ya
    jsr store_xv
    jsr store_yv
    jsr store_xm
    jsr store_ym
    lda #$60
    jsr store_yl
    lda #$73
    jsr store_xl
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
/* Only when using fold
    jsr get_xm
    clc
    cmp #$01                // Compare with #01 (over fold)
    beq over_fold
*/
rts

/*
    Change direction and start moving leftwards
*/
over_fold:
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
    jsr get_xm
    clc
    cmp #$01                // Compare with #01 (at fold)
    bne at_left_edge
rts

/*
    Change direction and start moving rightwards
*/
at_left_edge:
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

check_collision:
    jsr get_xl
    sec                     // Set carry for borrow purpose
    sbc #$09                // Subtract for left offset
    sta temp                // Store the result
    jsr get_xm              // Load x-position MSB
    sbc #$00                // Subtract nothing, but make use of carry
    lsr                     // MSB -> C, divide by 2
    lda temp                // Get offset adjusted LSB
    ror                     // Rotate Carry into LSB 
    lsr                     // Divide by 2 again
    lsr                     // Divide by 2 again

    lsr                     // Truncate to first address in block
    asl

    sta column
    
    jsr get_yl              // Get y-position LSB
    sec                     // Set carry for borrow purpose
    sbc #$2b                // Subtract for bottom offset
    lsr                     // Divide by 2
    lsr                     // Divide by 2 again
    lsr                     // And divide by 2 a last time
    sta row                 // Store it for later

    ldx row
    lda ScreenMemLowByte,x
    sta $fd
    lda ScreenMemHighByte,x
    sta $fe

    ldy column
    lda ($fd),y

    cmp #$80                // Nothing should happenif the character is a space or lower
    bcc end_char


    cmp #%11110000
    bcs bounce_on_brick

    cmp #%11100000
    bcs speed_up_ball

    lda #$79                // Clear using space
    sta ($fd),y             // Store in both left..
    iny                     // ..and right half of block
    sta ($fd),y

    bounce_on_brick:
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

    speed_up_ball:
        //lda #$86
        //jsr store_ya
    end_char:
rts

check_sprite_collision:

    lda SpriteIndex
    cmp #$00
    beq end_check_sprite_collision

    lda #$0
    jsr store_flags
    
    jsr get_xl     // x-position LSB of ball
    sta balllo
    jsr get_xm     // x-position LSB of ball
    sta ballhi

    sec
    lda balllo
    sbc SpriteMem
    sta reslo
    lda ballhi
    sbc SpriteMem+1
    sta reshi

    sec
    lda reslo
    sbc #$11
    sta reslo
    lda reshi
    sbc #$00
    sta reshi

    bpl right_of_paddle

    clc
    lda balllo
    adc #$11
    sta balllo
    lda ballhi
    adc #$00
    sta ballhi
    sec
    lda balllo
    sbc SpriteMem
    sta reslo
    lda ballhi
    sbc SpriteMem+1
    sta reshi

    bmi left_of_paddle

    jsr bounce_off_paddle
    jsr end_check_sprite_collision
    rts

    left_of_paddle:
        //FRAME_COLOR(1) // white
        rts
    right_of_paddle:
        //FRAME_COLOR(2) // right
        rts
    end_check_sprite_collision:
        lda #$01
        jsr store_flags
rts

bounce_off_paddle:
    // Check if the ball is above the paddle. If so we can just return
    jsr get_yl
    cmp #TopOfPaddle
    bcc end_check_sprite_collision
    beq stop_ball
    
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

        // Set the accellerated movement timer. Hitting the ball with the
        // paddle will add some extra speed for a few cycles. Otherwise the
        // balls velocity will be reduced for each bounce, and it will 
        // eventually stop.
        lda #$02
        sta accelerated_movement_timer
    bounce_end:
rts
/*
    This function will stop the ball if the velocity is too low. This is used
    to make it rest on top of the paddle.
*/
stop_ball:
    jsr get_yv
    clc
    cmp #$2 
    bpl bounce
    lda #$08
    jsr store_yv
    jmp bounce

