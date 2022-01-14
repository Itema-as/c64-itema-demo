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
.const ScreenTopEdge    = $2c
.const ScreenBottomEdge = $eb
.const ScreenRightEdge  = $47
.const ScreenLeftEdge   = $15

/*
	A helper "variable" we will need on occasion
*/
temp:
	.byte %00000000
temp2:
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
 	Apply the acceleration to the velocity, moving up. Once passing $FF (-1) the
	direction will change to moving downwards. This transition causes some
	velocity to be lost.
*/
bounce_up:
	jsr get_yv
	clc	
	adc #$04				// Simulate gravity
	jsr store_yv
rts

/*
	Apply the acceleration to the velocity, moving down. Make sure that the
	maximum value of #$7f is not exceeded because that would mean moving up.
*/
fall_down:
	jsr get_yv
	clc
	adc #$04				// Simulate gravity
	cmp #$80				// Never go negative
	bpl f_acc
	jsr store_yv
	f_acc:
rts

/*
	Perform horizontal movement
*/
horizontal:
	jsr h_acceleration		// Apply horizontal acceleration
	jsr get_xv
	clc
	cmp #$00				// Compare with signed integer
	bmi left				// Move left if value is negative
	bpl right				// Move right if value is positive
rts

/*
 Apply horizontal acceleration from input
*/
h_acceleration:
	jsr get_xa
	sta temp				// Store the new value in a variable
	jsr get_xv
	clc
	adc temp				// Add acceleration to velocity
	jsr store_xv
rts

/*
	Perform vertical movement
*/
vertical:
	jsr v_acceleration		// Apply vertical acceleration
	jsr get_yv
	clc
	cmp #$00				// Compare with signed integer
	bmi up					// Move up if value is negative
	bpl down				// Move down if value is positive
rts

/*
	Apply vertical acceleration from input along with gravity
*/
v_acceleration:
	jsr get_ya
	sta temp				// Store the new value in a variable
	jsr get_yv
	clc
	adc temp				// Add Y to A
	jsr store_yv
	// -- Apply gravity
	cmp #$00				// Compare with signed integer
	bpl fall_down			// Move down if value is positive
	bmi bounce_up			// Move up if value is negative
rts

/*
	Move current sprite left
*/
left:
	jsr get_xv				// Get the X-velocity (which is negative)
	eor #$ff				// Flip the sign so that we get a positive number
	clc
	adc #$01
	sta temp				// Store the new value in a variable
	jsr get_xl
	sec
	sbc temp				// Move left by the amount of velocity 
	jsr store_xl
	jsr get_xm
	sbc #$00				// Subtract zero and borrow from lsb subtraction
	jsr store_xm
	jsr left_edge
rts
/*
	Move current sprite right
*/
right:
	jsr get_xv				// Get the X-velocity (a positive number)
	sta temp				// Store the value in a temporary variable
	jsr get_xl
	clc
	adc temp				// Move right by the amount of velocity
	jsr store_xl
	jsr get_xm
	adc #$00				// Add zero and carry from lsb addition
	jsr store_xm
	jsr right_edge
rts	

/*
	Move current sprite upwards
*/
up:
	jsr get_yv				// Get the Y-velocity (a negative number)
	eor #$ff				// Flip the sign so that we get a positive number
	clc
	jsr shift_right			// Apply the 3 MSB of velocity
	sta temp				// Store the new value in a variable
	jsr get_yl
	sec
	sbc temp				// Move up by the amount of velocity
	jsr store_yl
	cmp #ScreenTopEdge		// Is top of screen hit?
	bcc change_vertical		// Jump if less than $31
rts

/*
	Move current sprite downwards
*/
down:
	jsr get_yv				// Get the Y-velocity (a positive number)
	jsr shift_right			// Apply only the 3 MSB of velocity
	sta temp				// Store the value in a temporary variable
	jsr get_yl
	clc
	adc temp				// Move down by the amount of velocity
	jsr store_yl
	cmp #ScreenBottomEdge	// Is bottom of screen hit?
	bcs change_vertical		// If so change direction
rts

/*
	Flip the sign on the vertical velocity and acceleration
*/
change_vertical:
	jsr get_yv				// Change the direction of the velocity
	eor #$ff
	clc
//	sbc #$01
	jsr store_yv
rts

/*
	Start moving from left to right.
*/
change_to_move_right:
	jsr get_xv				// Change the direction of the velocity
	clc
	adc #$03				// Reduce velocity
	eor #$ff				// Flip the sign
	jsr store_xv
rts

/*
	Start moving from right to left.
*/
change_to_move_left:
	jsr get_xv				// Change the direction of the velocity
	clc
	sbc #$03				// Reduce velocity
	eor #$ff
	jsr store_xv
rts

/*
	Determine whether or not the current sprite is at the right edge of the
	screen.
*/
right_edge:
	jsr get_xm
	clc
	cmp #$01				// Compare with #01 (over fold)
	beq over_fold
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
	cmp #$01				// Compare with #01 (at fold)
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
rts
