#importonce

#import "libMath.asm"

wHudScore: .word 0
.const HUDScoreIncrease = 1

/*
    Swich the CPU decimal mode and increase the score.
*/
gameIncreaseScore:
    sed     // Set decimal mode  
    LIBMATH_ADD16BIT_AVA(wHudScore,HUDScoreIncrease,wHudScore)
    cld     // Clear decimal mode
    rts 

