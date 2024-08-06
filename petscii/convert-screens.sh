#!/bin/bash

KICK_ASSEMBLER_PATH=$HOME/Developer/C64/KickAssembler/KickAss.jar

function convert() {
  sed "s/into/$1/g" convert-screens.asm > convert-screens.mod
  java -jar $KICK_ASSEMBLER_PATH convert-screens.mod
  x64sc -moncommands commands.txt -initbreak 0x0845 -autostart convert-screens.prg -warp
  dd bs=2 skip=1 if=screen.bin of=screen_trimmed.bin
  dd bs=2 skip=1 if=color.bin of=color_trimmed.bin
  cat screen_trimmed.bin color_trimmed.bin > $1.bin
  # Clean up
  rm -f screen_trimmed.bin
  rm -f color_trimmed.bin
  rm -f screen.bin
  rm -f color.bin
  rm -f input.seq
}
rm -rf *.bin
convert "intro"
convert "level_1"
