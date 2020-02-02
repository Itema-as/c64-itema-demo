/*
	Simple sprite handling library
	Copyright (c) 2020 Torkild U. Resheim and others 
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

draw_sprites:
	// x ==> 0	Sprite 0 X MSB
	//       1  Sprite 0 X LSB
	//       2  Sprite 0 Y MSB
	//       3  Sprite 0 Y LSB
	//       4  Sprite 0 X Accelleration
	//       5  Sprite 0 Y Accelleration

	
	// handle vertical position
	jsr get_yl
	ldx #$00
	sta $d001,x	

	// handle horizontal position
	jsr get_xl
	ldx #$00
	sta $d000,x

	// handle horizontal position msb
	jsr get_xm
	cmp #$01
	beq set_msb
	
	jsr get_xm
	cmp #$00
	beq clear_msb
	
rts

set_msb:
	ldx #0
	lda $d010
	ora set_table,x
	sta $d010
rts

clear_msb:
	ldx #0
	lda $d010
	and clear_table,x
	sta $d010
rts

////////////////////////////////////////////////////////////////////////////////

horizontal:
	jsr get_xa
	cmp #$00
	beq right			// move right if value = 0
	cmp #$01
	beq left			// move left if value = 1
rts

left:
	jsr get_xl
	sec					// Clear the borrow flag
	sbc #$01			// move left
	jsr store_xl
	cmp #$ff
	beq left_dec_msb	// Increment MSB	
	jsr left_edge
rts	

left_dec_msb:
	jsr get_xm
	sec					// Clear the borrow flagg
	sbc #$01			// add 1 to MSB
	jsr store_xm
rts

vertical:
	jsr get_ya
	cmp #$00
	beq down
	cmp #$01
	beq up
rts

right:
	jsr get_xl
	clc							// Clear the carry flag
	adc #$01
	jsr store_xl
	cmp #$00
	beq right_inc_msb	
	jsr right_edge
rts	

up:
	jsr get_yl
	sec
	sbc #$1				// move up
	jsr store_yl
	cmp #$31			// is top of screen hit?
	beq change_to_down
rts

down:
	jsr get_yl
	clc
	adc #$1
	jsr store_yl
	cmp #$e9			// is bottom of screen hit?
	beq change_to_up
rts

change_to_left:
	lda #$01			// switch direction
	jsr store_xa
rts

change_to_up:
	lda #$01			// switch direction
	jsr store_ya
rts

change_to_down:
	lda #$00			// switch direction
	jsr store_ya
rts


right_inc_msb:
	jsr get_xm
	clc					// clear the carry register
	adc #$1				// add 1 to MSB
	jsr store_xm
rts

right_edge:
	jsr get_xm
	cmp #$01			// compare with #01 (over fold)
	beq at_right_edge
rts

at_right_edge:
	jsr get_xl
	cmp #$40
	beq change_to_left
rts

left_edge:
	jsr get_xm
	cmp #$01			// compare with #00 (at fold)
	bne at_left_edge
rts

at_left_edge:
	jsr get_xl
	cmp #$17
	beq change_to_right
rts

change_to_right:
	lda #$00			// switch direction
	jsr store_xa
rts
