/*
	Simple bouncing Itema logo
	Copyright (c) 2020 Torkild U. Resheim 
*/

* = $c000 "Main Program"

// import our sprite library
#import "spritelib.asm"
#import "music/music.asm"

BasicUpstart2(initialize)
	
// Initialize
initialize:
	jsr $e544			// clear screen

	lda #$ff
	sta $d000			// set x position of sprite
	
	lda #$ff
	sta $d001			// set y position of sprite
	
	lda #%00000001		// enable sprite0
	sta $d015
	
	lda #$00			// disable xpand-y
	sta $d017
	
	lda #$00			// set sprite/background priority
	sta $d01b
	
	lda #$ff			// set multicolor
	sta $d01c
	
	lda #$00			// disable xpand-x
	sta $d01d
	
	lda #$0f			// sprite multicolor 1
	sta $d025
	lda #$0c			// sprite multicolor 2
	sta $d026
	lda #$0a			// sprite individual color
	sta $d027
	
	lda #spriteData/64	// set sprite data pointer
	sta $07f8
	
	lda #$01
	sta $cf00
	sta $cf01

jsr startMusic
loop:
	lda #00					// wait until the screen refreshes
!:	cmp $d012	
	bne !-

	jsr horizontal
	jsr vertical

jmp loop


// -- Sprite Data --------------------------------------------------------------
// Created using https://www.spritemate.com
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