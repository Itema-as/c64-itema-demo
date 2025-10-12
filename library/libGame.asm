#importonce

#import "libMath.asm"

wHudScore:      .word 0
wHudHiScore:    .word 0
wHudLives:      .word 0
wHudBricks:     .word 0
wHudDebug:     .word 0
wHudNextExtraLife: .word 0

.const HUDScoreIncrease = 1
.const HUDExtraLifeStep = $0050

/*
    Swich the CPU decimal mode and increase the score.
*/
gameIncreaseScore:
    sed // Set decimal mode
    LIBMATH_ADD16BIT_AVA(wHudScore, HUDScoreIncrease, wHudScore)
    cld // Clear decimal mode

    lda wHudScore
    cmp wHudHiScore
    lda wHudScore+1
    sbc wHudHiScore+1

    bcc gHCNotHi

    lda wHudScore
    sta wHudHiScore
    lda wHudScore+1
    sta wHudHiScore+1
gHCNotHi:
rts

gameResetExtraLifeThreshold:
    lda #<HUDExtraLifeStep
    sta wHudNextExtraLife
    lda #>HUDExtraLifeStep
    sta wHudNextExtraLife+1
rts

gameCheckExtraLife:
    lda wHudScore+1
    cmp wHudNextExtraLife+1
    bcc gceNoLife
    bne gceGrantLife
    lda wHudScore
    cmp wHudNextExtraLife
    bcc gceNoLife
gceGrantLife:
    sed
    LIBMATH_ADD16BIT_AVA(wHudNextExtraLife, HUDExtraLifeStep, wHudNextExtraLife)
    cld
    sec
    rts
gceNoLife:
    clc
    rts

gameDecreaseLives:
    sed // Set decimal mode
    LIBMATH_SUB16BIT_AVA(wHudLives, 1, wHudLives)
    cld // Clear decimal mode
    rts

gameIncreaseLives:
    sed // Set decimal mode
    LIBMATH_ADD16BIT_AVA(wHudLives, 1, wHudLives)
    cld // Clear decimal mode
    rts
