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
.const SFX_ID_COUNT            = 6

// Voice 3 register aliases
.label SFX_FREQ_LO             = SIDBASE + $0E
.label SFX_FREQ_HI             = SIDBASE + $0F
.label SFX_PULSE_LO            = SIDBASE + $10
.label SFX_PULSE_HI            = SIDBASE + $11
.label SFX_CONTROL             = SIDBASE + $12
.label SFX_ATTACK_DECAY        = SIDBASE + $13
.label SFX_SUSTAIN_RELEASE     = SIDBASE + $14
.label SFX_VOL_FILT            = SIDBASE + $18


.segment Variables
sfxActive:      .byte 0
sfxStepCounter: .byte 0
sfxStepPtrLo:   .byte 0
sfxStepPtrHi:   .byte 0
sfxEnabled:     .byte 0

.segment Code

/*
    Encode one SID update step as {duration, freq lo, freq hi, control}:
    - duration : number of IRQ ticks this step remains active.
    - freq lo  : lower byte of the target SID frequency register.
    - freq hi  : upper byte of the SID frequency register.
    - control  : value written to SID control (waveform/gate, eg. $11 pulse/gate).

    SID control register bit layout (voice 3):
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

sfx_init:
    lda #$00
    sta sfxActive
    sta sfxStepCounter
    sta sfxStepPtrLo
    sta sfxStepPtrHi
    sta sfxEnabled

    sta SFX_CONTROL
    sta SFX_FREQ_LO
    sta SFX_FREQ_HI
    sta SFX_PULSE_LO
    sta SFX_PULSE_HI
    lda #$F0                // Default ADSR: quick attack, long sustain
    sta SFX_ATTACK_DECAY
    lda #$00
    sta SFX_SUSTAIN_RELEASE
    lda #$0f                // Ensure master volume is non-zero for effects
    sta SFX_VOL_FILT
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

sfx_trigger:
    pha
    lda sfxEnabled
    beq sfx_trigger_disabled
    pla
    tax
    cpx #SFX_ID_COUNT
    bcc sfx_trigger_valid
rts

sfx_trigger_disabled:
    pla
rts

sfx_trigger_valid:
    lda sfxDescriptorTableLo,x
    sta ZP_PTR_LO
    lda sfxDescriptorTableHi,x
    sta ZP_PTR_HI

    ldy #$00                // Descriptor header: ADSR, pulse, table pointer
    lda (ZP_PTR_LO),y
    sta SFX_ATTACK_DECAY
    iny
    lda (ZP_PTR_LO),y
    sta SFX_SUSTAIN_RELEASE
    iny
    lda (ZP_PTR_LO),y
    sta SFX_PULSE_LO
    iny
    lda (ZP_PTR_LO),y
    sta SFX_PULSE_HI
    iny
    lda (ZP_PTR_LO),y
    sta sfxStepPtrLo
    iny
    lda (ZP_PTR_LO),y
    sta sfxStepPtrHi

    lda #$01
    sta sfxActive
    lda #$00
    sta sfxStepCounter
    jsr sfx_update
rts

sfx_update:                 // Advance current effect when enabled from IRQ
    lda sfxEnabled
    bne sfx_update_enabled
rts

sfx_update_enabled:
    lda sfxActive
    bne sfx_active
rts

sfx_active:
    lda sfxStepCounter
    bne sfx_tick

    lda sfxStepPtrLo
    sta ZP_PTR_LO
    lda sfxStepPtrHi
    sta ZP_PTR_HI
    ldy #$00
    lda (ZP_PTR_LO),y
    beq sfx_finish
    sta sfxStepCounter
    iny
    lda (ZP_PTR_LO),y
    sta SFX_FREQ_LO
    iny
    lda (ZP_PTR_LO),y
    sta SFX_FREQ_HI
    iny
    lda (ZP_PTR_LO),y
    sta SFX_CONTROL
    clc
    lda sfxStepPtrLo
    adc #4
    sta sfxStepPtrLo
    lda sfxStepPtrHi
    adc #0
    sta sfxStepPtrHi
    lda sfxStepCounter
    beq sfx_active          // Handle 0-length entries gracefully
sfx_tick:
    dec sfxStepCounter
rts

sfx_finish:
    lda #$00
    sta SFX_CONTROL
    sta sfxActive
    sta sfxStepCounter
rts

sfx_disable:               // Force channel idle and prevent new triggers
    jsr sfx_finish
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

sfxDescriptorTableHi:
    .byte >sfxLaunchDescriptor
    .byte >sfxBrickDescriptor
    .byte >sfxPaddleDescriptor
    .byte >sfxPaddlePowerDescriptor
    .byte >sfxBallLostDescriptor
    .byte >sfxLevelStartDescriptor

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
