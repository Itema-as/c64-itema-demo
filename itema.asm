/*
	Useful links,

	* C64 Sprites
	  - https://www.c64-wiki.com/wiki/Sprite
*/

* = $c000 "Main Program"

BasicUpstart2(initialize)
	
// Initialize
initialize:
	lda #$ff
	sta $d000 			// set x position of sprite
	
	lda #$32
	sta $d001 			// set y position of sprite
	
	lda #$01 			// enable sprite0
	sta $d015 	
	
	lda #$00        	// disable xpand-y
	sta $d017 	
	
	lda #$01        	// set sprite/background priority
	sta $d01b       
	
	lda #$ff        	// set multicolor
	sta $d01c 	
	
	lda #$00 			// disable xpand-x
	sta $d01d 	
	
	lda #$0f			// sprite multicolor 1
	sta $d025
	lda #$0c 			// sprite multicolor 2
	sta $d026
	lda #$0a 			// sprite individual color
	sta $d027
	
	lda #spriteData/64	// set sprite pointer
	sta $07f8
	
	lda #$01
	sta $cf00
	sta $cf01

loop:
	lda #00					// wait until the screen refreshes	
!:	cmp $d012	
	bne !-

	jsr horizontal
	jsr vertical
	jmp loop
			
horizontal:				// handle left/right movement			
	lda $cf00
	cmp #$00
	bne right			// move right if value != 0
	cmp #$01			
	bne left			// move left if value != 1
rts

vertical:				// handle up/down movement
	lda $cf01
	cmp #$00
	bne down			// move right if value != 0
	cmp #$01			
	bne up				// move left if value != 1
rts

right:
	lda $d010
	and #%00000001
	cmp #%00000001		// see if we are over the 256px limit
	bne normal_right	// if not move as normal to the right
	inc $d000
	lda $d000
	cmp #$40 
	beq change_to_left
rts

normal_right:			// move right
	inc $d000
	lda $d000
	cmp #$ff
	beq set_msb
rts

set_msb:				// at the 256px limit moving right
	lda #$0
	sta $d000
	lda $d010			
	ora #%00000001
	sta $d010
rts

clear_msb:				// at the 256px limit moving left
	lda #$fe
	sta $d000
	lda $d010			
	and #%11111110
	sta $d010
rts

left:					// move left
	lda $d010
	and #%00000001
	cmp #%00000001		// see if we are over the 256px limit
	bne normal_left		// if not move as normal to the left 
	dec $d000
	lda $d000
	cmp #$00
	beq clear_msb
rts

normal_left:			// move left
	dec $d000
	lda $d000
	cmp #$17
	beq change_to_right
rts

up:						// move up
	dec $d001
	lda $d001
	cmp #$31
	bcc change_to_down
rts

down:					// move down
	inc $d001
	lda $d001
	cmp #$e9
	bcs change_to_up
rts

change_to_left:
	lda #$00			// switch direction
	sta $cf00
rts

change_to_right:
	lda #$01			// switch direction
	sta $cf00
rts

change_to_up:
	lda #$00			// switch direction
	sta $cf01
rts

change_to_down:
	lda #$01			// switch direction
	sta $cf01
rts
		
// -- Data ---------------------------------------------------------

* = $2140 "Sprite Data"
spriteData:
.byte %00000000,%00101000,%00000000
.byte %00000000,%10101010,%00000000
.byte %00000001,%10101010,%01000000
.byte %00000101,%10101010,%01010000
.byte %00110111,%00101000,%11011100
.byte %00010100,%00000000,%00010100
.byte %11010100,%01010100,%00010111
.byte %01011100,%01010100,%00110101
.byte %01011100,%00010100,%00110101
.byte %01011100,%00010100,%00110101
.byte %01011100,%00010100,%00110101
.byte %01011100,%00010100,%00110101
.byte %01011100,%00010100,%00010101
.byte %01011100,%00010100,%00010111
.byte %01011100,%00010111,%11010100
.byte %11010100,%00010101,%01011100
.byte %00010100,%00010101,%01110000
.byte %00110111,%00000000,%00000000
.byte %00000101,%01111101,%00000000
.byte %00001101,%01010101,%00000000
.byte %00000011,%11011100,%00000000