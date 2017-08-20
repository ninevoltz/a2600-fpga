@echo off
set rom_path=carts\

tools\romgen %rom_path%Adventure.bin cart_rom 14 l r e > %rom_path%cart_rom.vhd

echo done
