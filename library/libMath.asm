#importonce

#import "libDefines.asm"

.macro LIBMATH_ADD16BIT_AVA(wNum1, wNum2, wSum)
{
    clc                     // Clear carry before first add
    lda wNum1               // Get LSB of first number
    adc #<wNum2             // Add LSB of second number
    sta wSum                // Store in LSB of bSum
    lda wNum1+1             // Get MSB of first number
    adc #>wNum2             // Add carry and MSB of NUM2
    sta wSum+1              // Store bSum in MSB of sum
}
/*
     Convert an 8 bit binary value to BCD

    This function converts an 8 bit binary value into a 16 bit BCD. It
    works by transferring one bit a time from the source and adding it
    into a BCD value that is being doubled on each iteration. As all the
    arithmetic is being done in BCD the result is a binary to decimal
    conversion.  All conversions take 311 clock cycles.

    For example the conversion of a $96 would look like this:

    BIN = $96 -> BIN' = $2C C = 1 | BCD $0000 x2 + C -> BCD' $0001
    BIN = $2C -> BIN' = $58 C = 0 | BCD $0001 x2 + C -> BCD' $0002
    BIN = $58 -> BIN' = $B0 C = 0 | BCD $0002 x2 + C -> BCD' $0004
    BIN = $B0 -> BIN' = $60 C = 1 | BCD $0004 x2 + C -> BCD' $0009
    BIN = $60 -> BIN' = $C0 C = 0 | BCD $0009 x2 + C -> BCD' $0018
    BIN = $C0 -> BIN' = $80 C = 1 | BCD $0018 x2 + C -> BCD' $0037
    BIN = $80 -> BIN' = $00 C = 1 | BCD $0037 x2 + C -> BCD' $0075
    BIN = $00 -> BIN' = $00 C = 0 | BCD $0075 x2 + C -> BCD' $0150

    This technique is very similar to Garth Wilson's, but does away with
    the look up table for powers of two and much simpler than the approach
    used by Lance Leventhal in his books (e.g. subtracting out 1000s, 100s,
    10s and 1s).

    Andrew Jacobs, 28-Feb-2004

    http://www.6502.org/source/integers/hex2dec-more.htm
*/
.macro LIBMATH_8BITTOBCD_AA(bIn, wOut)
{
    ldy bIn
    sty ZeroPage13  // Store in a temporary variable
    sed             // Switch to decimal mode
    lda #0          // Ensure the result is clear
    sta wOut
    sta wOut+1
    ldx #8          // The number of source bits
cnvBit:
    asl ZeroPage13  // Shift out one bit
    lda wOut        // And add into result
    adc wOut
    sta wOut
    lda wOut+1      // propagating any carry
    adc wOut+1
    sta wOut+1
    dex             // And repeat for next bit
    bne cnvBit
    cld             // Back to binary
}