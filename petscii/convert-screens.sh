#!/bin/bash

KICK_ASSEMBLER_PATH=$HOME/Developer/C64/KickAssembler/KickAss.jar

function convert() {
  sed "s/intro/$1/g" convert-screens.asm > convert-screens.mod 
  java -jar $KICK_ASSEMBLER_PATH convert-screens.mod
  # See "convert-screens.sym" for the address (loop) where to quit
  x64sc -silent --exitscreenshot $1.png -moncommands commands.txt -initbreak 0x08be -VICIIborders 3 -autostart convert-screens.prg 
  dd bs=2 skip=1 if=screen.bin of=screen_trimmed.bin
  dd bs=2 skip=1 if=color.bin of=color_trimmed.bin

  python_output=$(
    SCREEN_NAME="$1" COORD_PATH="$1.coords.bin" python3 - <<'PY'
import os
from pathlib import Path

name = os.environ["SCREEN_NAME"]
coord_path = Path(os.environ["COORD_PATH"])
width = 40
height = 25
needle = 60
replacement = 32

data_path = Path("screen_trimmed.bin")
data = bytearray(data_path.read_bytes())
coords = bytearray()
found = False

for index, value in enumerate(data[: width * height]):
  if value == needle:
    x = (index % width) * 8 +12
    y = (index // width) * 8 + 47
    print(f"{name}: value {needle} at x={x} y={y}")
    coords.extend((x, y))
    data[index] = replacement
    found = True

if not found:
  print(f"{name}: value {needle} not found")
else:
  data_path.write_bytes(data)
  coord_path.write_bytes(coords)

brick_count = sum(1 for value in data[: width * height] if 128 <= value <= 233)
print(f"BRICK_COUNT={brick_count}")
PY
  )

  printf '%s\n' "$python_output"

  # Calculate the number of bricks in the level, so that we can figure out
  # when all the bricks has been taken out and the level is completed. 
  brick_count=$(printf '%s\n' "$python_output" | awk -F= '/^BRICK_COUNT=/{print $2}' | tail -n 1)
  if [ -z "$brick_count" ]; then
    echo "Could not determine brick count for $1; defaulting to 0"
    brick_count=0
  fi

  bricks=$((brick_count / 2))
  if [ "$bricks" -lt 0 ] || [ "$bricks" -gt 255 ]; then
    echo "Brick count $bricks out of byte range for $1" >&2
    bricks=0
  fi

  echo "Number of bricks in the level $bricks"

  cat screen_trimmed.bin color_trimmed.bin > "$1.bin"

  python3 - "$1.bin" "$bricks" <<'PY'
import sys
from pathlib import Path

result_path = Path(sys.argv[1])
value = int(sys.argv[2])

with result_path.open("ab") as handle:
    handle.write(bytes((value,)))
PY

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
convert "level_5"
convert "level_6"
