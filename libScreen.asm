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

.const MEMCP_SRCVECT = $fb
.const MEMCP_DSTVECT = MEMCP_SRCVECT + 2
.macro PRINT_SCREEN(src, dest)
{
// NB! The vector for index indirect addressing is little-endian

    lda #<src          // Store src address to src vector in zero-page
    sta MEMCP_SRCVECT
    lad #>src
    sta MEMCP_SRCVECT + 1

    lda #<dst          // Store dst address to dst vector in zero-page
    sta MEMCP_DSTVECT  // The vector for index indirect addressing is
    lad #>dst          // little-endian
    sta MEMCP_DSTVECT + 1

    ldx #$00
    ldy #$00
memcp_loop:
    lda (MEMCP_SRCVECT),y
    cmp #$ff
    beq memcp_out
    sta (MEMCP_DSTVECT),y
    iny
    cpy #$00            // If Y has wrapped, go to next page
    beq memcp_nextpage
    jmp memcp_loop
memcp_nextpage:
    inc MEMCP_SRCVECT + 1
    inc MEMCP_DSTVECT + 1
    jmp memcp_loop
memcp_out:
}