/*
	Bouncing ball demo

	Copyright (c) 2020-2022 Itema AS

	Written by:
	- Øystein Steimler, ofs@itema.no
	- Torkild U. Resheim, tur@itema.no
	- Morten Moen, mmo@itema.no
	- Arve Moen, amo@itema.no
	- Bjørn Leithe Karlsen, bka@itema.no
*/

* = $c000 "Main Program"

// import our sprite library
#import "libSprite.asm"
#import "libInput.asm"
#import "libScreen.asm"
#import "music/music.asm"
//
BasicUpstart2(initialize)
	
// Initialize
initialize:
	jsr $e544			// clear screen

	lda #$17			// activate character set 2
	sta $d018

	lda #%00000001		// enable sprites
	sta $d015

	lda #$00			// disable xpand-y
	sta $d017

	lda #$00			// set sprite/background priority
	sta $d01b
	
//	lda #$ff			// enable multicolor
//	sta $d01c
	
	lda #$00			// disable xpand-x
	sta $d01d
	
//	lda #$0f			// set sprite multicolor 1
//	sta $d025
//	lda #$0c			// set sprite multicolor 2
//	sta $d026
	lda #$0a			// set sprite individual color
	sta $d027
	
	lda #spriteData/64	// set sprite data pointer
	sta $07f8			// sprite #1
	sta $07f9			// sprite #2
	sta $07fa			// sprite #3
	sta $07fb			// sprite #4
	sta $07fc			// sprite #5
	sta $07fd			// sprite #6
	sta $07fe			// sprite #7
	sta $07ff			// sprite #8
	
	//jsr startMusic

	// Set up some text for use when debugging
	line1: .text "USE JOYSTICK 2"
		   .byte $ff
		   
PRINT_SCREEN(line1, $0400)

loop:
	lda #$00
	sta SpriteIndex
	animation_loop:
		jsr player_input
		jsr move_horizontally
		jsr move_vertically
		// TODO: Draw sprite at correct interrupt ?
		jsr draw_sprite
		inc SpriteIndex
		lda SpriteIndex
		cmp #$01
		beq done
		jmp animation_loop
	done:
		// Spend a few cycles doing nothing in order to get a smooth motion
		ldy  #$10
		ldx  #$01
		delay:
			dex
			txa
			bne delay
			dey
			tya
			bne delay
jmp loop

player_input:
	// Reset acceleration on both axis
	lda #$00
	jsr store_xa
	jsr store_ya
	
	// Set acelleration according to joystick input
	LIBINPUT_GET(GameportLeftMask)
		bne inputRight
		lda #$ff
		jsr store_xa
	inputRight:
		LIBINPUT_GET(GameportRightMask)
		bne inputUp
		lda #$01
		jsr store_xa
	inputUp:
		LIBINPUT_GET(GameportUpMask)
		bne inputDown  
		lda #$f8
		jsr store_ya
	inputDown:
		LIBINPUT_GET(GameportDownMask)
		bne inputEnd
		lda #$01
		jsr store_ya
	inputEnd:	
		rts 

// -- Sprite Data --------------------------------------------------------------
// Created using https://www.spritemate.com
* = $2140 "Sprite Data"
spriteData:
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00011000,%00000000
.byte %00000000,%01111110,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000001,%11111111,%10000000
.byte %00000001,%11111111,%10000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%11111111,%00000000
.byte %00000000,%01111110,%00000000
.byte %00000000,%00011000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000
.byte %00000000,%00000000,%00000000