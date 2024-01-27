#importonce

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
