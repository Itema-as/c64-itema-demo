#importonce

// Port Masks
.label GameportUpMask       = %00000001
.label GameportDownMask     = %00000010
.label GameportLeftMask     = %00000100
.label GameportRightMask    = %00001000
.label GameportFireMask     = %00010000

.macro LIBINPUT_GET(portMask)
{
    lda $DC00      // Load joystick 2 state to A
    and #portMask  // Mask out direction/fire required
} // Test with bne immediately after the call