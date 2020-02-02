// Sprite data handling
//
// By Oystein Steimler, ofs@itema.no
spriteindex:
        .byte $00

spritemem:
        //    xl   xm   yl   ym   xax  yax
        .byte $f0, $00, $f0, $00, $00, $00
        .byte $20, $00, $20, $00, $01, $01
        .byte $10, $00, $10, $00, $00, $01
        .byte $20, $00, $20, $00, $01, $00
        .byte $30, $00, $30, $00, $00, $01
        .byte $40, $00, $40, $00, $01, $00
        .byte $50, $00, $50, $00, $00, $01
        .byte $60, $00, $60, $00, $01, $00

.var xl = 0
.var xm = 1
.var yl = 2
.var ym = 3
.var xa = 4
.var ya = 5
.var spritelen = 6


ldx #0
stx spriteindex
jsr get_xm  // xm for 0 in a

get_xm:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #xm                 // Add index to get fieldaddr
        jmp get_val

get_xl:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #xl                 // Add index to get fieldaddr
        jmp get_val

get_ym:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #ym                 // Add index to get fieldaddr
        jmp get_val

get_yl:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #yl                 // Add index to get fieldaddr
        jmp get_val

get_xa:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #xa                 // Add index to get fieldaddr
        jmp get_val

get_ya:
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #ya                 // Add index to get fieldaddr

        // jmp get_val // next instr

get_val:
        tax                     // .A -> .X
        lda spritemem,x        // load fieldaddr -> .A
        rts

store_xm:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc						// Clear the carry flag
        adc #xm                 // Add index to get fieldaddr
        jmp store_val

store_xl:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc
        adc #xl          // Add index to get fieldaddr
        jmp store_val

store_ym:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc
        adc #ym                 // Add index to get fieldaddr
        jmp store_val

store_yl:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc
        adc #yl                 // Add index to get fieldaddr
        jmp store_val

store_xa:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc
        adc #xa                 // Add index to get fieldaddr
        jmp store_val

store_ya:
        pha
        jsr getspritebase       // Get spritebase in .A
		clc
        adc #ya                 // Add index to get fieldaddr
        // jmp store_val // -> next instr

store_val:
        tax                     // .A -> .X
        pla
        sta spritemem,x        // load fieldaddr -> .A
        rts


// getspritebase -> .A  -- uses .X
getspritebase:
        ldx spriteindex
        lda #$00

    getspritebase_loop:
        cpx #$00
        beq gotspritebase
		clc
        adc #spritelen
        dex
        jmp getspritebase_loop

    gotspritebase:
        rts
    
