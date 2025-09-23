#!/bin/bash

KICK_ASSEMBLER_PATH=$HOME/Developer/C64/KickAssembler/KickAss.jar

function convert() {
  sed "s/intro/$1/g" convert-screens.asm > convert-screens.mod 
  java -jar $KICK_ASSEMBLER_PATH convert-screens.mod
  # See "convert-screens.sym" for the address (loop) where to quit
  x64sc -silent --exitscreenshot $1.png -moncommands commands.txt -initbreak 0x0895 -VICIIborders 3 -autostart convert-screens.prg 
  dd bs=2 skip=1 if=screen.bin of=screen_trimmed.bin
  dd bs=2 skip=1 if=color.bin of=color_trimmed.bin

  SCREEN_NAME="$1" COORD_PATH="$1.coords.bin" python3 - <<'PY'
import os
from pathlib import Path

name = os.environ["SCREEN_NAME"]
coord_path = Path(os.environ["COORD_PATH"])
width = 40
height = 25
needle = 60
replacement = 32

data = bytearray(Path("screen_trimmed.bin").read_bytes())
coords = bytearray()
found = False

for index, value in enumerate(data[: width * height]):
  if value == needle:
    x = (index % width) * 8 - 7 + 20
    y = (index // width) * 8 + 47
    print(f"{name}: value {needle} at x={x} y={y}")
    coords.extend((x, y))
    data[index] = replacement
    found = True

if not found:
  print(f"{name}: value {needle} not found")
else:
  Path("screen_trimmed.bin").write_bytes(data)
  coord_path.write_bytes(coords)
PY

  cat screen_trimmed.bin color_trimmed.bin > $1.bin
  # Calculate the number of bricks in the level, so that we can figure out
  # when all the bricks has been taken out and the level is completed. 
  count=$(head -c 1000 screen_trimmed.bin | od -An -t u1 | \
  awk '{for(i=1;i<=NF;i++) if($i>=128 && $i<=223) c++} END{print c}')
  val=$((count / 2))
  echo $val
  printf "%c" $val >> "$1.bin"
  
  # Add X and Y coordinates for the ball drop if found 
  if [ -f "$1.coords.bin" ]; then
    cat "$1.coords.bin" >> "$1.bin"
    rm -f "$1.coords.bin"
  else
    printf "%c" 0 >> "$1.bin"
    printf "%c" 0 >> "$1.bin"
  fi

  
  # Clean up
  rm -f screen_trimmed.bin
  rm -f color_trimmed.bin
  rm -f screen.bin
  rm -f color.bin
  rm -f input.seq
}
rm -rf *.bin
convert "intro"
convert "level_0"
convert "level_1"
convert "level_2"
convert "level_3"
convert "level_4"
