/*
	Sprite handling library
	Copyright (c) 2020 Itema AS

	This will simply bounce sprites between the four walls of the screen. Load
	the current sprite number in to the A register and call the following
	functions:

	horizontal to
		move horizontally

	vertical to
		move vertically

	draw_sprite to
		draw the sprite on it's new location

	Written by:
	- Øystein Steimler, ofs@itema.no
	- Torkild U. Resheim, tur@itema.no
	- Morten Moen, mmo@itema.no
	- Arve Moen, amo@itema.no
	- Bjørn Leithe Karlsen, bka@itema.no
*/

set_table:
	.byte %00000001
	.byte %00000010
	.byte %00000100
	.byte %00001000
	.byte %00010000
	.byte %00100000
	.byte %01000000
	.byte %10000000

clear_table:
	.byte %11111110
	.byte %11111101
	.byte %11111011
	.byte %11110111
	.byte %11101111
	.byte %11011111
	.byte %10111111
	.byte %01111111

/*
	A helper "variable" we will need on occasion
*/
temp:
	.byte %00000000

/*
	Determine the offset of the sprite x-position address
*/
get_sprite_offset:
	ldx spriteindex
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
	ldx spriteindex
	lda $d010
	ora set_table,x
	sta $d010
rts

clear_msb:
	ldx spriteindex
	lda $d010
	and clear_table,x
	sta $d010
rts

////////////////////////////////////////////////////////////////////////////////

/*
	Perform horizontal movement
*/
horizontal:
	jsr get_xv
	cmp #$00				// Compare with signed integer
	bmi left				// Move left if value is negative
	bpl right				// Move right if value is positive
rts

/*
	Perform vertical movement
*/
vertical:
	jsr get_yv
	cmp #$00				// Compare with signed integer
	bmi up					// Move up if value is negative
	bpl down				// Move down if value is positive
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
	jsr get_yv				// Get the Y-velocity (which is negative)
	eor #$ff				// Flip the sign so that we get a positive number
	clc
	adc #$01
	sta temp				// Store the new value in a variable
	jsr get_yl
	sec
	sbc temp				// Move up by the amount of velocity
	jsr store_yl
	cmp #$31				// Is top of screen hit?
	bcc change_vertical		// Jump if less than $31
rts

/*
	Move current sprite downwards
*/
down:	
	jsr get_yv				// Get the Y-velocity (a positive number)
	sed						// Enable decimal mode
	sta temp				// Store the value in a temporary variable
	cld						// Disable decimal mode
	jsr get_yl
	clc
	adc temp				// Move down by the amount of velocity
	jsr store_yl
	cmp #$e9				// Is bottom of screen hit?
	bcs change_vertical		// Jump if more than $e9
rts

/*
	Flip the sign on the horizontal velocity
*/
change_horizontal:
	jsr get_xv
	eor #$ff
	clc
	adc #$01
	jsr store_xv
rts

/*
	Flip the sign on the vertical velocity
*/
change_vertical:
	jsr get_yv
	eor #$ff
	clc
	adc #$01
	jsr store_yv
rts

/*
	Determine whether or not the current sprite is at the right edge
*/
right_edge:
	jsr get_xm
	cmp #$01				// Compare with #01 (over fold)
	beq at_right_edge
rts

/*
	Change direction and start moving leftwards
*/
at_right_edge:
	jsr get_xl
	cmp #$40
	bcs change_horizontal
rts

/*
	Determine whether or not the current sprite is at the left edge
*/
left_edge:
	jsr get_xm
	cmp #$01				// Compare with #01 (at fold)
	bne at_left_edge
rts

/*
	Change direction and start moving rightwards
*/
at_left_edge:
	jsr get_xl
	cmp #$17
	bcc change_horizontal
rts
