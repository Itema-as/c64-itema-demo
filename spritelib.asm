/*
	Simple sprite handling library
	Copyright (c) 2020 Torkild U. Resheim 

        76543210 Sprite movement x direction (1 = right, 0 = left)
$cf00	00000000

        76543210 Sprite movement y direction (1 = down, 0 = up)
$cf01	00000000

$cf02 x sprite
$cf03 y sprite 1


00000000 00000000

*/

.var base=$0010

init_spritelib:
	lda #$0
	.for (var i=0;i<47;i++) {		
		sta base+i
	}
//	lda #$60
//	sta $0011
//	sta $0013
rts

draw_sprites:
	// x ==> 0	Sprite 0 X MSB
	//       1  Sprite 0 X LSB
	//       2  Sprite 0 Y MSB
	//       3  Sprite 0 Y LSB
	//       4  Sprite 0 X Accelleration
	//       5  Sprite 0 Y Accelleration

	// handle horizontal position
	ldy $cf00		// load address offset
	ldx $cf01		// load sprite index 
	iny
	lda base,y
	sta $d000,x
	dey
	lda $d010
	and #%11111110
	ora base,y
	sta $d010,x
	
	// handle vertical position
	ldy $cf00		// load address offset 
	ldx $cf01		// load sprite index 
	iny
	iny
	iny
	lda base,y
	sta $d001,x
	
rts

set_msb:			// at the 256px limit moving right
	lda #$0
	sta $d000
	lda $d010
	ora #%00000001
	sta $d010
rts

clear_msb:			// at the 256px limit moving left
	lda #$fe
	sta $d000
	lda $d010
	and #%11111110
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
