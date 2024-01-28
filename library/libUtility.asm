//==============================================================================
//                        RetroGameDev Library C64 v2.02
//==============================================================================
// Includes

#importonce
#import "libDefines.asm"

//===============================================================================
// Macros 

.macro LIBUTILITY_DISABLEBASIC()
{
    lda R6510
    and #%11111110 // Disable BASIC ROM 
    sta R6510
}

//==============================================================================

.macro LIBUTILITY_DISABLEBASICANDKERNAL()
{
    sei             // Disable IRQ's
    lda #%01111111  // Bit 7 off
    sta CIAICR      // Turn off CIA1 timer interrupts
    sta CI2ICR      // Turn off CIA2 timer interrupts
    lda CIAICR      // Cancel all CIA1-IRQs in queue/unprocessed
    lda CI2ICR      // Cancel all CIA2-IRQs in queue/unprocessed

    lda R6510
    and #%11111101  // Disable BASIC and Kernal ROMS 
    sta R6510
    cli             // Enable IRQ's

    // Disable NMI interrupts to stop Run/Stop & Restore from halting the program
    LIBUTILITY_DISABLENMI() 
}

//==============================================================================

.macro LIBUTILITY_DISABLENMI()
{
    ldx #<libUtilityRti         // Load the empty NMI routine address
    ldy #>libUtilityRti
    stx NMIROMVECTOR            // Store in the current NMI vector
    sty NMIROMVECTOR+1
}

libUtilityRti:
    rti

//===============================================================================

// Copies ‘value’ into 1000 memory locations starting at ‘start’ address
.macro LIBUTILITY_SET1000_AV(wStart, bValue)
{
    lda #bValue         // Get value to set
    ldx #250            // Set loop value
loop:
    dex                 // Step -1
    sta wStart,x        // Set start + x
    sta wStart+250,x    // Set start + 250 + x
    sta wStart+500,x    // Set start + 500 + x
    sta wStart+750,x    // Set start + 750 + x
    bne loop            // If x != 0 loop
}

//===============================================================================

.macro LIBUTILITY_WAITLOOP_V(bNumLoops)
{
  ldx #bNumLoops
loop:
  dex
  bne loop
}