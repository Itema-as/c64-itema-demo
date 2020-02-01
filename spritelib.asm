/*
	Simple sprite handling library
	Copyright (c) 2020 Torkild U. Resheim 
*/
horizontal:			// handle left/right movement
	lda $cf00
	cmp #$00
	bne right		// move right if value != 0
	cmp #$01
	bne left		// move left if value != 1
rts

vertical:			// handle up/down movement
	lda $cf01
	cmp #$00
	bne down		// move right if value != 0
	cmp #$01
	bne up			// move left if value != 1
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

right:
	lda $d010
	and #%00000001
	cmp #%00000001	// see if we are over the 256px limit
	bne normal_right// if not move as normal to the right
	inc $d000
	lda $d000
	cmp #$40		// is right side of screen hit?
	beq change_to_left
rts

normal_right:		// move right
	inc $d000
	lda $d000
	cmp #$ff		// is the $ff side of screen hit?
	beq set_msb
rts

left:				// move left
	lda $d010
	and #%00000001
	cmp #%00000001	// see if we are over the 256px limit
	bne normal_left	// if not move as normal to the left 
	dec $d000
	lda $d000
	cmp #$00		// is the $ff side of screen hit?
	beq clear_msb
rts

normal_left:		// move left
	dec $d000
	lda $d000
	cmp #$17		// is left side of screen hit?
	beq change_to_right
rts

up:					// move up
	dec $d001
	lda $d001
	cmp #$31		// is top of screen hit?
	bcc change_to_down
rts

down:				// move down
	inc $d001
	lda $d001
	cmp #$e9		// is bottom of screen hit?
	bcs change_to_up
rts

change_to_left:
	lda #$00		// switch direction
	sta $cf00
rts

change_to_right:
	lda #$01		// switch direction
	sta $cf00
rts

change_to_up:
	lda #$00		// switch direction
	sta $cf01
rts

change_to_down:
	lda #$01		// switch direction
	sta $cf01
rts
