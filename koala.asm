.var picture = LoadBinary("NINJA3.KOA", BF_KOALA)

#import "library/libDefines.asm"

        *=$0801 "Basic Program"
        BasicUpstart($0810)

        *=$0810 "Program"
        lda #$38                // Bitmap pointer at $2000, screen at $0c00
        sta VMCSB
        lda #$d8                // Multicolor on, 40 cols, no h-scroll
        sta SCROLX
        lda #$3b                // Bitmap mode on, 25 rows
        sta SCROLY
        lda #$00
        sta EXTCOL
        lda #$00
        sta BGCOL0
        ldx #$00
!loop:
        .for (var i=0; i<4; i++) {
           lda colorRam+i*$100,x
           sta COLORRAM+i*$100,x
        }
        inx
        bne !loop-
        jmp *

*=$0c00;            .fill picture.getScreenRamSize(), picture.getScreenRam(i)
*=$1c00; colorRam:  .fill picture.getColorRamSize(), picture.getColorRam(i)
*=$2000;            .fill picture.getBitmapSize(), picture.getBitmap(i)
