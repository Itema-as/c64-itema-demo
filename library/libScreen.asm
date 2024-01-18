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

.const MEMCP_SRCVECT = $f9
.const MEMCP_DSTVECT = MEMCP_SRCVECT + 2
.const MEMCP_CNTVECT = MEMCP_DSTVECT + 2
.macro MEMCOPY(src, dst)
{
// NB! The vector for index indirect addressing is little-endian

    lda #<src          // Store src address to src vector in zero-page
    sta MEMCP_SRCVECT
    lda #>src
    sta MEMCP_SRCVECT + 1

    lda #<dst          // Store dst address to dst vector in zero-page
    sta MEMCP_DSTVECT  // The vector for index indirect addressing is
    lda #>dst          // little-endian
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

/*
    Load a screen from the address prepared in  in zeropage
    $fe – lowest byte
    $ff - highest byte
 */
load_screen:

    // Start with the characters
    lda #$00
    sta MEMCP_DSTVECT
    lda $fe                 // zeropage 
    sta MEMCP_SRCVECT
    lda #$04
    sta MEMCP_DSTVECT+1
    lda $ff                 // zeropage 
    sta MEMCP_SRCVECT+1
    lda #$00
    sta MEMCP_CNTVECT       // Initialize low byte of counter
    sta MEMCP_CNTVECT+1     // Initialize high byte of counter

    jsr copy_loop

    // Now do the colours
    lda $fe                 // Load the low byte of the pointer
    clc                     // Clear carry flag before addition
    adc #$e5                // Add the LSB for modification
    sta MEMCP_SRCVECT

    lda $ff                 // Load the high byte of the pointer
    adc #$03                // Add the MSB for modification
    bcc noCarry             // Branch if no carry from the first addition
    adc #$01                // Add the carry from the first addition
    
    noCarry:
        sta MEMCP_SRCVECT+1

    // Set the destination to colour memory at $d800
    lda #$00
    sta MEMCP_DSTVECT
    lda #$d8
    sta MEMCP_DSTVECT+1
    lda #$00
    sta MEMCP_CNTVECT       // Initialize low byte of counter
    sta MEMCP_CNTVECT+1     // Initialize high byte of counter

copy_loop:
    ldy MEMCP_CNTVECT       // Load low byte of counter into Y

    lda (MEMCP_SRCVECT),Y   // Load byte from source address + Y into A
    sta (MEMCP_DSTVECT),Y   // Store byte from A at target address + Y

    inc MEMCP_CNTVECT       // Increment low byte of counter
    bne check_counter
    inc MEMCP_CNTVECT+1     // If low byte overflowed, increment high byte

check_counter:
    lda MEMCP_CNTVECT
    cmp #$e8                // Check if low byte of counter has reached 0xe8
    bne continue_loop

    lda MEMCP_CNTVECT+1
    cmp #$03                // Check if high byte of counter has reached 0x03
    bne continue_loop

    jmp end_loop            // If we've copied 1000 bytes, end the loop

continue_loop:
    iny  // Increment Y
    bne copy_loop
    inc MEMCP_SRCVECT+1     // If Y overflowed, increment high byte of source address
    inc MEMCP_DSTVECT+1     // If Y overflowed, increment high byte of target address
    jmp copy_loop           // Jump back to the start of the loop

end_loop:

rts