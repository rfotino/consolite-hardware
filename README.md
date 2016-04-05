# Consolite Hardware

This is a Verilog implementation of a microprocessor implementing the
Consolite ISA. It is designed for the Mimas V2 development board with a
Spartan 6 FPGA.

## What Is Consolite?

Consolite (coming from "Console Lite") is the name I've given to my design of a
hobbyist microprocessor and associated toolchain. Consolite's instruction set
architecture (ISA) has assembly level instructions for setting colors, drawing
pixels on the screen, and receiving input. This makes it suitable for writing
games, which is what makes it a "console".

### Consolite Specs

* Display: 256 x 192 pixels, 8-bit color
* Registers: 16 general purpose, instruction pointer, color, flags
* Memory: 64KiB main memory, 48KiB video memory
