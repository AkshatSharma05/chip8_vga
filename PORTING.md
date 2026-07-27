# Cyclone IV HDL port

This project contains the restored, pure-HDL CHIP-8 design. The CPU, 4 KiB
program memory, framebuffer, and VGA generator all live in the FPGA. No
RP2040 firmware, SPI mailbox, Shrike wrapper, or Shrike pin constraint is
included.

## Top-level interface

The top-level module is `src/top.v` and exposes:

- `clk_50`: nominal 50 MHz board clock
- `reset_n`: asynchronous active-low reset
- scalar one-bit color outputs `r`, `g`, and `b`
- `vga_hsync`, `vga_vsync`
- `status_led`

Assign these ports to the desired DE0-Nano pins and I/O standards in Quartus.
No pin assignments were added or modified by this port.

The 50 MHz clock remains the only internal clock. `freq_div` produces a
25 MHz clock-enable used by the 640x480 timing logic, avoiding a fabric-derived
clock.

## Source layout

- `src/cpu/cpu.v`: CHIP-8 fetch/decode/execute core
- `src/memory/memory.v`: 4 KiB CHIP-8 memory and initial test program
- `src/video/display.v`: 64x32 one-bit framebuffer
- `src/video/vga_timing.v`: 640x480 VGA timing
- `src/video/vga_renderer.v`: scales each CHIP-8 pixel to 10x10 VGA pixels
- `src/system/freq_div.v`: 25 MHz pixel clock-enable

The Quartus project file lists only those synthesizable modules. The old SPI
and RP2040 files are intentionally absent.

## Continuing development

The current memory test program starts at address `0x200`. Edit the
initialization in `src/memory/memory.v` to load another ROM, or replace it
with a Quartus-compatible memory initialization flow.

The restored CPU source is an early implementation: several CHIP-8 opcodes,
including sprite draw (`DXYN`), keyboard operations, random, font lookup,
BCD, and bulk register transfers, are incomplete. The framebuffer and VGA
plumbing are present, but displaying a real ROM will require completing those
CPU paths.
