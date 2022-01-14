#importonce

.macro PRINT_SCREEN(text,address)
{
	ldx #$00
loop:
	lda text,x
	cmp #$ff
	beq out
	sta address,x
	inx
	jmp loop
out:
	rts:	
}
