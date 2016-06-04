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

* Display: 256 x 192 pixels, 8-bit color (VGA output)
* Registers: 16 general purpose, instruction pointer, color, flags
* Memory: 64KiB main memory, 48KiB video memory (write only)
* Storage: Up to 256 programs on microSD card
* Input: 6 buttons, 8 switches, 32 GPIOs, up to 8 SNES controllers

## Documentation

* [Instruction Set](docs/instruction-set.md)
* [How to load and run programs](docs/programming.md)
* [How to modify SNES controllers as input](docs/controllers.md)

## License

The Verilog code in the `/src` directory and any documentation is covered under
the license in `LICENSE.txt`. The `MimasV2Config.py` script for flashing Consolite
onto the development board is not my creation and is not covered under this license.
Additionally, the files under the `/proj/ipcore_dir` directory have been generated
from the Xilinx software and are not covered under the license; these files are used
for interfacing with the on board LPDDR RAM.
