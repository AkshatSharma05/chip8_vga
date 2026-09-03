# CHIP-8 on an FPGA 

This project is a CHIP-8 interpreter written in Verilog for the **DE0-Nano** (Cyclone IV). It runs CHIP-8 ROMs directly on the FPGA, displays them over VGA, and accepts input from a PS/2 keyboard.

> This is a work in progress. Some instructions, games, or hardware features may not behave perfectly yet.

---

### Demo Video

<a href="https://youtu.be/tYJ7WJbcMgY">
  <img 
    src="https://i.ytimg.com/vi/tYJ7WJbcMgY/hqdefault.jpg"
    width="420"
    alt="CHIP-8 Demo Video">
</a>

---

## What's here

- CHIP-8 CPU and 4 KB memory
- 64×32 framebuffer rendered over VGA
- PS/2 keyboard input
- Buzzer output driven by the CHIP-8 sound timer
- Configurable instruction speed

The default CPU rate is 2,000 instructions per second. Besides improving the
speed of instruction-heavy games, this shortens the interval between the XOR
erase and redraw operations used to move sprites, reducing visible flicker.

## Getting started

Convert a `.ch8` ROM into the memory file used by the design:

```sh
python3 tools/rom_to_hex.py path/to/game.ch8
```

Then open `top.qpf` in Quartus Prime, compile the design, and program the DE0-Nano.

## Keypad

The CHIP-8 keypad is mapped to the left side of a PS/2 keyboard:

```text
Keyboard        CHIP-8
1 2 3 4         1 2 3 C
Q W E R         4 5 6 D
A S D F         7 8 9 E
Z X C V         A 0 B F
```

Either pushbutton resets the system. The status LED blinks while the design is running.

