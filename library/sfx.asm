/*
    Sound effect library
    Table-driven SID effects for gameplay events.
*/

#importonce
#import "libDefines.asm"

.const SFX_ID_LAUNCH           = 0
.const SFX_ID_BRICK_SCORE      = 1
.const SFX_ID_PADDLE_HIT       = 2
.const SFX_ID_PADDLE_POWER     = 3
.const SFX_ID_BALL_LOST        = 4
.const SFX_ID_LEVEL_START      = 5
.const SFX_ID_EXTRA_LIFE       = 6
.const SFX_ID_PADDLE_GROW      = 7
.const SFX_ID_PADDLE_SHRINK    = 8
.const SFX_ID_COUNT            = 9

.const SFX_VOICE_COUNT         = 3

// SID voice register aliases
.label SFX0_FREQ_LO            = SIDBASE + $00
.label SFX0_FREQ_HI            = SIDBASE + $01
.label SFX0_PULSE_LO           = SIDBASE + $02
.label SFX0_PULSE_HI           = SIDBASE + $03
.label SFX0_CONTROL            = SIDBASE + $04
.label SFX0_ATTACK_DECAY       = SIDBASE + $05
.label SFX0_SUSTAIN_RELEASE    = SIDBASE + $06

.label SFX1_FREQ_LO            = SIDBASE + $07
.label SFX1_FREQ_HI            = SIDBASE + $08
.label SFX1_PULSE_LO           = SIDBASE + $09
.label SFX1_PULSE_HI           = SIDBASE + $0A
.label SFX1_CONTROL            = SIDBASE + $0B
.label SFX1_ATTACK_DECAY       = SIDBASE + $0C
.label SFX1_SUSTAIN_RELEASE    = SIDBASE + $0D

.label SFX2_FREQ_LO            = SIDBASE + $0E
.label SFX2_FREQ_HI            = SIDBASE + $0F
.label SFX2_PULSE_LO           = SIDBASE + $10
.label SFX2_PULSE_HI           = SIDBASE + $11
.label SFX2_CONTROL            = SIDBASE + $12
.label SFX2_ATTACK_DECAY       = SIDBASE + $13
.label SFX2_SUSTAIN_RELEASE    = SIDBASE + $14

.label SFX_VOL_FILT            = SIDBASE + $18


.segment Variables
sfxActive0:         .byte 0
sfxActive1:         .byte 0
sfxActive2:         .byte 0
sfxStepCounter0:    .byte 0
sfxStepCounter1:    .byte 0
sfxStepCounter2:    .byte 0
sfxStepPtr0Lo:      .byte 0
sfxStepPtr0Hi:      .byte 0
sfxStepPtr1Lo:      .byte 0
sfxStepPtr1Hi:      .byte 0
sfxStepPtr2Lo:      .byte 0
sfxStepPtr2Hi:      .byte 0
sfxEnabled:         .byte 0
sfxVoiceNext:       .byte 0
sfxRequestedId:     .byte 0
sfxSelectedVoice:   .byte 0

.segment Code

/*
    Encode one SID update step as {duration, freq lo, freq hi, control}:
    - duration : number of IRQ ticks this step remains active.
    - freq lo  : lower byte of the target SID frequency register.
    - freq hi  : upper byte of the SID frequency register.
    - control  : value written to SID control (waveform/gate, eg. $11 pulse/gate).

    SID control register bit layout (per voice):
      bit7 Noise | bit6 Pulse | bit5 Saw | bit4 Triangle | bit3 Test
      bit2 Ring  | bit1 Sync  | bit0 Gate
    The SFX tables use combinations such as:
      $11 = Triangle + Gate on, $10 = Triangle release
      $81 = Noise  + Gate on,  $80 = Noise release
      $21 = Sawtooth + Gate on, $20 = Sawtooth release
      $41 = Pulse + Gate on, $40 = Pulse release
    Adjust/extend these constants if new waveforms or modulation bits are needed.
*/
.macro SFX_STEP(duration, freq, control) {
    .byte duration, <freq, >freq, control
}

sfx_stop_voice0:
    lda #$00
    sta SFX0_CONTROL
    sta SFX0_FREQ_LO
    sta SFX0_FREQ_HI
    sta SFX0_PULSE_LO
    sta SFX0_PULSE_HI
    sta sfxActive0
    sta sfxStepCounter0
    sta sfxStepPtr0Lo
    sta sfxStepPtr0Hi
rts

sfx_stop_voice1:
    lda #$00
    sta SFX1_CONTROL
    sta SFX1_FREQ_LO
    sta SFX1_FREQ_HI
    sta SFX1_PULSE_LO
    sta SFX1_PULSE_HI
    sta sfxActive1
    sta sfxStepCounter1
    sta sfxStepPtr1Lo
    sta sfxStepPtr1Hi
rts

sfx_stop_voice2:
    lda #$00
    sta SFX2_CONTROL
    sta SFX2_FREQ_LO
    sta SFX2_FREQ_HI
    sta SFX2_PULSE_LO
    sta SFX2_PULSE_HI
    sta sfxActive2
    sta sfxStepCounter2
    sta sfxStepPtr2Lo
    sta sfxStepPtr2Hi
rts

sfx_update_voice0:
    lda sfxActive0
    bne sfx_voice0_active
rts

sfx_voice0_active:
    lda sfxStepCounter0
    bne sfx_voice0_tick

    lda sfxStepPtr0Lo
    sta ZeroPage14
    lda sfxStepPtr0Hi
    sta ZeroPage15
    ldy #$00
    lda (ZeroPage14),y
    beq sfx_voice0_finish
    sta sfxStepCounter0
    iny
    lda (ZeroPage14),y
    sta SFX0_FREQ_LO
    iny
    lda (ZeroPage14),y
    sta SFX0_FREQ_HI
    iny
    lda (ZeroPage14),y
    sta SFX0_CONTROL
    clc
    lda sfxStepPtr0Lo
    adc #4
    sta sfxStepPtr0Lo
    lda sfxStepPtr0Hi
    adc #0
    sta sfxStepPtr0Hi
    lda sfxStepCounter0
    beq sfx_update_voice0

sfx_voice0_tick:
    dec sfxStepCounter0
rts

sfx_voice0_finish:
    jsr sfx_stop_voice0
rts

sfx_update_voice1:
    lda sfxActive1
    bne sfx_voice1_active
rts

sfx_voice1_active:
    lda sfxStepCounter1
    bne sfx_voice1_tick

    lda sfxStepPtr1Lo
    sta ZeroPage14
    lda sfxStepPtr1Hi
    sta ZeroPage15
    ldy #$00
    lda (ZeroPage14),y
    beq sfx_voice1_finish
    sta sfxStepCounter1
    iny
    lda (ZeroPage14),y
    sta SFX1_FREQ_LO
    iny
    lda (ZeroPage14),y
    sta SFX1_FREQ_HI
    iny
    lda (ZeroPage14),y
    sta SFX1_CONTROL
    clc
    lda sfxStepPtr1Lo
    adc #4
    sta sfxStepPtr1Lo
    lda sfxStepPtr1Hi
    adc #0
    sta sfxStepPtr1Hi
    lda sfxStepCounter1
    beq sfx_update_voice1

sfx_voice1_tick:
    dec sfxStepCounter1
rts

sfx_voice1_finish:
    jsr sfx_stop_voice1
rts

sfx_update_voice2:
    lda sfxActive2
    bne sfx_voice2_active
rts

sfx_voice2_active:
    lda sfxStepCounter2
    bne sfx_voice2_tick

    lda sfxStepPtr2Lo
    sta ZeroPage14
    lda sfxStepPtr2Hi
    sta ZeroPage15
    ldy #$00
    lda (ZeroPage14),y
    beq sfx_voice2_finish
    sta sfxStepCounter2
    iny
    lda (ZeroPage14),y
    sta SFX2_FREQ_LO
    iny
    lda (ZeroPage14),y
    sta SFX2_FREQ_HI
    iny
    lda (ZeroPage14),y
    sta SFX2_CONTROL
    clc
    lda sfxStepPtr2Lo
    adc #4
    sta sfxStepPtr2Lo
    lda sfxStepPtr2Hi
    adc #0
    sta sfxStepPtr2Hi
    lda sfxStepCounter2
    beq sfx_update_voice2

sfx_voice2_tick:
    dec sfxStepCounter2
rts

sfx_voice2_finish:
    jsr sfx_stop_voice2
rts

sfx_start_voice0:
    jsr sfx_stop_voice0
    ldy #$00
    lda (ZeroPage14),y
    sta SFX0_ATTACK_DECAY
    iny
    lda (ZeroPage14),y
    sta SFX0_SUSTAIN_RELEASE
    iny
    lda (ZeroPage14),y
    sta SFX0_PULSE_LO
    iny
    lda (ZeroPage14),y
    sta SFX0_PULSE_HI
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr0Lo
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr0Hi
    lda #$01
    sta sfxActive0
    lda #$00
    sta sfxStepCounter0
    jsr sfx_update_voice0
rts

sfx_start_voice1:
    jsr sfx_stop_voice1
    ldy #$00
    lda (ZeroPage14),y
    sta SFX1_ATTACK_DECAY
    iny
    lda (ZeroPage14),y
    sta SFX1_SUSTAIN_RELEASE
    iny
    lda (ZeroPage14),y
    sta SFX1_PULSE_LO
    iny
    lda (ZeroPage14),y
    sta SFX1_PULSE_HI
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr1Lo
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr1Hi
    lda #$01
    sta sfxActive1
    lda #$00
    sta sfxStepCounter1
    jsr sfx_update_voice1
rts

sfx_start_voice2:
    jsr sfx_stop_voice2
    ldy #$00
    lda (ZeroPage14),y
    sta SFX2_ATTACK_DECAY
    iny
    lda (ZeroPage14),y
    sta SFX2_SUSTAIN_RELEASE
    iny
    lda (ZeroPage14),y
    sta SFX2_PULSE_LO
    iny
    lda (ZeroPage14),y
    sta SFX2_PULSE_HI
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr2Lo
    iny
    lda (ZeroPage14),y
    sta sfxStepPtr2Hi
    lda #$01
    sta sfxActive2
    lda #$00
    sta sfxStepCounter2
    jsr sfx_update_voice2
rts

sfx_init:
    lda #$00
    sta sfxActive0
    sta sfxActive1
    sta sfxActive2
    sta sfxStepCounter0
    sta sfxStepCounter1
    sta sfxStepCounter2
    sta sfxStepPtr0Lo
    sta sfxStepPtr0Hi
    sta sfxStepPtr1Lo
    sta sfxStepPtr1Hi
    sta sfxStepPtr2Lo
    sta sfxStepPtr2Hi
    sta sfxEnabled
    sta sfxVoiceNext
    sta sfxRequestedId
    sta sfxSelectedVoice

    jsr sfx_stop_voice0
    jsr sfx_stop_voice1
    jsr sfx_stop_voice2

    lda #$0f                // Ensure master volume is non-zero for effects
    sta SFX_VOL_FILT
rts

sfx_allocate_voice:
    lda sfxActive0
    beq sfx_allocate_voice_use0
    lda sfxActive1
    beq sfx_allocate_voice_use1
    lda sfxActive2
    beq sfx_allocate_voice_use2

    lda sfxVoiceNext
    tax                     // Selected voice when all are busy
    tay
    iny
    cpy #SFX_VOICE_COUNT
    bcc sfx_allocate_store_next
    ldy #$00
sfx_allocate_store_next:
    sty sfxVoiceNext
    txa                     // Restore selected voice index to A
    tax                     // and return it in X
rts

sfx_allocate_voice_use0:
    ldx #$00
    lda #$01
    sta sfxVoiceNext
rts

sfx_allocate_voice_use1:
    ldx #$01
    lda #$02
    sta sfxVoiceNext
rts

sfx_allocate_voice_use2:
    ldx #$02
    lda #$00
    sta sfxVoiceNext
rts

sfx_play_launch:
    lda #SFX_ID_LAUNCH
    bne sfx_trigger         // Unconditional branch

sfx_play_brick_score:
    lda #SFX_ID_BRICK_SCORE
    bne sfx_trigger

sfx_play_paddle_hit:
    lda #SFX_ID_PADDLE_HIT
    bne sfx_trigger

sfx_play_paddle_power:
    lda #SFX_ID_PADDLE_POWER
    bne sfx_trigger

sfx_play_ball_lost:
    lda #SFX_ID_BALL_LOST
    bne sfx_trigger

sfx_play_level_start:
    lda #SFX_ID_LEVEL_START
    bne sfx_trigger

sfx_play_extra_life:
    lda #SFX_ID_EXTRA_LIFE
    bne sfx_trigger

sfx_play_paddle_grow:
    lda #SFX_ID_PADDLE_GROW
    bne sfx_trigger

sfx_play_paddle_shrink:
    lda #SFX_ID_PADDLE_SHRINK
    bne sfx_trigger

sfx_trigger:
    tax
    lda sfxEnabled
    beq sfx_trigger_done
    cpx #SFX_ID_COUNT
    bcs sfx_trigger_done

    stx sfxRequestedId
    jsr sfx_allocate_voice
    stx sfxSelectedVoice

    ldx sfxRequestedId
    lda sfxDescriptorTableLo,x
    sta ZeroPage14
    lda sfxDescriptorTableHi,x
    sta ZeroPage15

    lda sfxSelectedVoice
    beq sfx_trigger_voice0
    cmp #$01
    beq sfx_trigger_voice1
    jmp sfx_start_voice2

sfx_trigger_voice0:
    jmp sfx_start_voice0

sfx_trigger_voice1:
    jmp sfx_start_voice1

sfx_trigger_done:

rts

sfx_update:                 // Advance current effect when enabled from IRQ
    lda sfxEnabled
    bne sfx_update_enabled
rts

sfx_update_enabled:
    jsr sfx_update_voice0
    jsr sfx_update_voice1
    jsr sfx_update_voice2
rts

sfx_disable:               // Force channel idle and prevent new triggers
    jsr sfx_stop_voice0
    jsr sfx_stop_voice1
    jsr sfx_stop_voice2
    lda #$00
    sta sfxEnabled
rts

sfx_enable:                // Re-allow queued triggers during active gameplay
    lda #$01
    sta sfxEnabled
rts

// Sound effect descriptors ----------------------------------------------------

// Descriptor records: attack/decay, sustain/release, pulse lo/hi, step pointer
sfxDescriptorTableLo:
    .byte <sfxLaunchDescriptor
    .byte <sfxBrickDescriptor
    .byte <sfxPaddleDescriptor
    .byte <sfxPaddlePowerDescriptor
    .byte <sfxBallLostDescriptor
    .byte <sfxLevelStartDescriptor
    .byte <sfxExtraLifeDescriptor
    .byte <sfxPaddleGrowDescriptor
    .byte <sfxPaddleShrinkDescriptor

sfxDescriptorTableHi:
    .byte >sfxLaunchDescriptor
    .byte >sfxBrickDescriptor
    .byte >sfxPaddleDescriptor
    .byte >sfxPaddlePowerDescriptor
    .byte >sfxBallLostDescriptor
    .byte >sfxLevelStartDescriptor
    .byte >sfxExtraLifeDescriptor
    .byte >sfxPaddleGrowDescriptor
    .byte >sfxPaddleShrinkDescriptor

sfxLaunchDescriptor:
    .byte $26               // Attack/decay: A=$2, D=$6 for moderate bite
    .byte $F6               // Sustain/release: S=$F, R=$6 keeps tone held briefly
    .byte $00               // Pulse width low byte (unused for triangle waveform)
    .byte $08               // Pulse width high byte (kept non-zero for completeness)
    .word sfxLaunchSteps    // Pointer to sequenced frequency/control steps

sfxBrickDescriptor:
    .byte $08               // Quick attack, fast decay for clicky sound
    .byte $88               // Sustain/release favouring short sustain
    .byte $00               // Pulse width lo (brick hit uses noise waveform)
    .byte $00               // Pulse width hi
    .word sfxBrickSteps

sfxPaddleDescriptor:
    .byte $12               // Quick attack/decay to emphasize a sharp impact
    .byte $25               // Low sustain with a brief release for thudding tail
    .byte $00               // Pulse width lo for follow-up pulse body
    .byte $08               // Pulse width hi (roughly 50% duty cycle)
    .word sfxPaddleSteps

sfxPaddlePowerDescriptor:
    .byte $16               // Faster attack yet still with a tail
    .byte $37               // Sustain/release gives lingering impact
    .byte $00               // Pulse width lo for pulse waveform
    .byte $06               // Pulse width hi selected for narrow buzz
    .word sfxPaddlePowerSteps

sfxBallLostDescriptor:
    .byte $58               // Slower attack to ease in losing tone
    .byte $47               // Sustain/release to allow fade-out
    .byte $00               // Pulse width lo (triangle waveform)
    .byte $00               // Pulse width hi placeholder
    .word sfxBallLostSteps

sfxLevelStartDescriptor:
    .byte $14               // Quick attack with moderate decay for melodic stab
    .byte $42               // Medium sustain, short release to separate notes
    .byte $00               // Pulse width lo (triangle waveform)
    .byte $00               // Pulse width hi unused
    .word sfxLevelStartSteps

sfxExtraLifeDescriptor:
    .byte $24               // Snappy attack with gentle decay for celebratory flair
    .byte $58               // Sustain and release give the fanfare room to breathe
    .byte $00               // Pulse width lo (triangle-based melody)
    .byte $00               // Pulse width hi placeholder
    .word sfxExtraLifeSteps

sfxPaddleGrowDescriptor:
    .byte $14               // Crisp attack, moderate decay for power-up pickup
    .byte $36               // Sustain/release keep the swell audible
    .byte $00               // Pulse width lo for the pulse waveform
    .byte $04               // Pulse width hi ~25% duty
    .word sfxPaddleGrowSteps

sfxPaddleShrinkDescriptor:
    .byte $14               // Match grow effect envelope for familiarity
    .byte $36               // Same sustain/release to mirror behaviour
    .byte $00               // Pulse width lo for pulse waveform
    .byte $0C               // Pulse width hi ~75% duty for darker tone
    .word sfxPaddleShrinkSteps

// Sound effect step tables ----------------------------------------------------

// Ball launch effect (upward glide)
sfxLaunchSteps:
    SFX_STEP(2, $0900, $11)
    SFX_STEP(2, $0C00, $11)
    SFX_STEP(3, $1000, $11)
    SFX_STEP(4, $1400, $10)
    .byte 0

// Brick hit awards points (short click)
sfxBrickSteps:
    SFX_STEP(2, $4000, $81)
    SFX_STEP(2, $3000, $81)
    SFX_STEP(2, $0000, $80)
    .byte 0

// Soft paddle contact with percussive "whack"
sfxPaddleSteps:
    SFX_STEP(1, $4800, $81)
    SFX_STEP(1, $4800, $80)
    SFX_STEP(1, $1C00, $41)
    SFX_STEP(2, $1400, $41)
    SFX_STEP(2, $0C00, $40)
    .byte 0

// Powered paddle smash
sfxPaddlePowerSteps:
    SFX_STEP(3, $1400, $41)
    SFX_STEP(3, $1800, $41)
    SFX_STEP(3, $1C00, $41)
    SFX_STEP(4, $1C00, $40)
    .byte 0

// Ball falls below paddle (descending tone)
sfxBallLostSteps:
    SFX_STEP(6, $1400, $11)
    SFX_STEP(6, $1000, $11)
    SFX_STEP(6, $0C00, $11)
    SFX_STEP(6, $0800, $10)
    .byte 0

// New level melody (bright arpeggio)
sfxLevelStartSteps:
    SFX_STEP(5, $1167, $11)
    SFX_STEP(1, $1167, $10)
    SFX_STEP(5, $15ED, $11)
    SFX_STEP(1, $15ED, $10)
    SFX_STEP(5, $1A13, $11)
    SFX_STEP(7, $22CE, $11)
    SFX_STEP(4, $22CE, $10)
    .byte 0

// Extra life fanfare (ascending flourish)
sfxExtraLifeSteps:
    SFX_STEP(4, $1000, $11)
    SFX_STEP(1, $1000, $10)
    SFX_STEP(4, $1400, $11)
    SFX_STEP(1, $1400, $10)
    SFX_STEP(4, $1800, $11)
    SFX_STEP(1, $1800, $10)
    SFX_STEP(6, $1E00, $11)
    SFX_STEP(2, $1E00, $10)
    SFX_STEP(8, $2400, $11)
    SFX_STEP(4, $2400, $10)
    .byte 0

// Paddle grows wider (rising shimmer)
sfxPaddleGrowSteps:
    SFX_STEP(3, $1200, $41)
    SFX_STEP(3, $1600, $41)
    SFX_STEP(3, $1C00, $41)
    SFX_STEP(5, $2200, $41)
    SFX_STEP(4, $2200, $40)
    .byte 0

// Paddle returns to normal (falling tone)
sfxPaddleShrinkSteps:
    SFX_STEP(3, $2200, $41)
    SFX_STEP(3, $1C00, $41)
    SFX_STEP(3, $1600, $41)
    SFX_STEP(5, $1200, $41)
    SFX_STEP(4, $0E00, $40)
    .byte 0
