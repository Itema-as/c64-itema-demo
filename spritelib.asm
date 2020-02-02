/*
	Simple sprite handling library
	Copyright (c) 2020 Torkild U. Resheim and others 
*/

.var base=$0010

init_spritelib:
	lda #$0
	.for (var i=0;i<48;i++) {		
		sta base+i
	}
rts

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

.var sprite = 0
.var xaddr = sprite*2

draw_sprites:
	// x ==> 0	Sprite 0 X MSB
	//       1  Sprite 0 X LSB
	//       2  Sprite 0 Y MSB
	//       3  Sprite 0 Y LSB
	//       4  Sprite 0 X Accelleration
	//       5  Sprite 0 Y Accelleration

	// handle vertical position
	ldx #xaddr
	ldy $cf00			// load address offset 
	iny
	iny
	iny
	lda base,y
	sta $d001,x	

	// handle horizontal position
	ldx #xaddr			// load sprite offset
	ldy $cf00			// load address offset
	iny					// point to the LSB x position
	lda base,y
	sta $d000,x			// store the LSB x position

	// handle horizontal position msb
	dey					// point to the MSB x position

	lda base,y
	cmp #$01
	beq set_msb

	lda base,y
	cmp #$00
	beq clear_msb
	
rts

set_msb:
	ldx #sprite			// put the sprite number in x
	ldy set_table,x
	lda $d010
	ora set_table,x
	sta $d010
rts

clear_msb:
	ldx #sprite			// put the sprite number in x
	lda $d010
	and clear_table,x
	sta $d010
rts

////////////////////////////////////////////////////////////////////////////////

horizontal:
	ldy $cf00
	iny
	iny
	iny
	iny
	lda base,y
	cmp #$00
	beq right			// move right if value = 0
	cmp #$01
	beq left			// move left if value = 1
rts

left:
	ldy $cf00			// X MSB
	iny					// X LSB
	lda base,y			// get value of LSB to A
	sec
	sbc #$1
	sta base,y
	bcc left_dec_msb	// Increment MSB	
	jsr left_edge
rts	

left_dec_msb:
	ldy $cf00			// get X MSB
	lda base,y			// get value of MSB to A
	sec					// clear the carry register
	sbc #$1				// add 1 to MSB
	sta base,y			// and store the result
	sta $0401
rts

vertical:
	ldy $cf00			// X MSB
	iny					// X LSB
	iny					// Y MSB
	iny					// Y LSB
	iny					// X Accelleration
	iny					// Y Accelleration
	lda base,y
	cmp #$00
	beq down			// move down if value = 0
	cmp #$01
	beq up				// move up if value = 1
rts

right:
	ldy $cf00			// X MSB
	iny					// X LSB
	lda base,y
	clc
	adc #$1
	sta base,y
	bcs right_inc_msb	// Increment MSB	
	jsr right_edge
rts	

up:
	ldy $cf00			// X MSB
	iny					// X LSB
	iny					// Y MSB
	iny					// Y LSB
	lda base,y
	sec
	sbc #$1
	sta base,y
	cmp #$31			// is top of screen hit?
	beq change_to_down
rts

down:
	ldy $cf00			// X MSB
	iny					// X LSB
	iny					// Y MSB
	iny					// Y LSB
	lda base,y
	clc
	adc #$1
	sta base,y
	cmp #$e9			// is bottom of screen hit?
	beq change_to_up
rts

change_to_left:
	ldy $cf00
	iny
	iny
	iny
	iny	
	lda #$01			// switch direction
	sta base,y
rts

change_to_up:
	ldy $cf00
	iny
	iny
	iny
	iny
	iny	
	lda #$01			// switch direction
	sta base,y
rts

change_to_down:
	ldy $cf00
	iny
	iny
	iny
	iny
	iny	
	lda #$00			// switch direction
	sta base,y
rts


right_inc_msb:
	ldy $cf00			// X MSB
	lda base,y			// get value of MSB to A
	clc					// clear the carry register
	adc #$1				// add 1 to MSB
	sta base,y			// and store the result
rts

right_edge:
	ldy $cf00			// X MSB
	lda base,y			// get value of MSB to A
	cmp #$01			// compare with #01 (over fold)
	beq at_right_edge
rts

at_right_edge:
	ldy $cf00			// X MSB
	iny					// X LSB
	lda base,y
	cmp #$40
	beq change_to_left
rts

left_edge:
	ldy $cf00			// Get X MSB
	lda base,y			// get value of MSB to A
	cmp #$01			// compare with #00 (at fold)
	bne at_left_edge
rts

at_left_edge:
	ldy $cf00			// Get X MSB
	iny					// X LSB
	lda base,y
	cmp #$17
	beq change_to_right
rts

change_to_right:
	ldy $cf00
	iny
	iny
	iny
	iny	
	lda #$00			// switch direction
	sta base,y
rts
