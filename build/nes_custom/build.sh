#!/bin/bash
# Build custom NES Z1 ROM from disassembly source.
set -e

CC65=/c/tools/cc65/bin
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
OUT="$ROOT/out"
HEADER="$ROOT/header.bin"

cd "$SRC"

# Assemble each bank
for asm in Z_00.asm Z_01.asm Z_02.asm Z_03.asm Z_04.asm Z_05.asm Z_06.asm Z_07.asm Z_debug.asm; do
    obj="${asm%.asm}.o"
    echo "[ca65] $asm"
    "$CC65/ca65.exe" "$asm" -o "$obj" --bin-include-dir dat 2>&1 | head -5
done

# Link
echo "[ld65] linking"
"$CC65/ld65.exe" -C Z.cfg -o "$OUT/prg.bin" Z_00.o Z_01.o Z_02.o Z_03.o Z_04.o Z_05.o Z_06.o Z_07.o Z_debug.o 2>&1 | head -10

# Prepend NES header (16 bytes) to PRG. CHR-RAM = 0 bytes of CHR data.
cat "$HEADER" "$OUT/prg.bin" > "$OUT/zelda_custom.nes"

echo "Built: $OUT/zelda_custom.nes ($(wc -c < "$OUT/zelda_custom.nes") bytes)"
ls -la "$OUT/zelda_custom.nes"
