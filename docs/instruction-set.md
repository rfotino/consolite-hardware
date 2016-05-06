# Consolite Instruction Set Architecture

## System Information

* 64 KiB of RAM, 16-bit addresses
* 256x192 8-bit display
* 16 registers (16 bits each).
* Register 0 is the stack pointer; the stack grows downward (increasing addresses)
* 8-bit color register
* 16-bit random number generator
* 16-bit millisecond counter
* Flags for overflow (OF), carry (CF), zero (ZF), and sign (SF)
* Fixed width, 32-bit instructions
* Big endian words

## Addressing Modes

Consolite uses a RISC architecture, so there are only two addressing modes:

1. Direct addressing, where the address is stored as a 16-bit immediate
2. Register indirect addressing, where the address is stored in a register

## Instruction Formats

Instructions are always 32 bits. The first 8 bits is always the opcode,
telling the CPU the type of instruction so that it knows what to expect in the
other 24 bits. The following table shows every instruction in the Consolite ISA,
along with its opcode, instruction format, and effect. In the "Format" column,
`DEST`, `SRC`, and `REG` are register addresses; `ADDR` and `DATA` are 16-bit
immediates; and `NUM` is an 8-bit immediate.

| Opcode | Abbrev  | Format          | Effect |
|--------|---------|-----------------|--------|
| 0x00   | NOP     | NOP             | No-op. Does nothing for one cycle. |
| 0x01   | INPUT   | INPUT DEST SRC  | Checks the input with an index equal to SRC's value, and stores the input's value in DEST. |
| 0x02   | CALL    | CALL ADDR       | Pushes the current instruction pointer onto the stack and jumps to ADDR. |
| 0x03   | RET     | RET NUM         | Pops a return address ADDR off the stack and jumps to ADDR + 2. Subtracts an additional NUM from the stack pointer. |
| 0x04   | LOAD    | LOAD DEST SRC   | Loads a word at memory address SRC and stores it in DEST. Uses register indirect addressing. |
| 0x05   | LOADI   | LOADI DEST ADDR | Loads a word at memory address ADDR and stores it in DEST. Uses direct addressing. |
| 0x06   | MOV     | MOV DEST SRC    | Copies data from SRC to DEST. |
| 0x07   | MOVI    | MOVI DEST DATA  | Moves the immediate DATA to DEST. |
| 0x08   | PUSH    | PUSH SRC        | Pushes the data in SRC onto the stack. Stack pointer goes to stack pointer + 2. |
| 0x09   | POP     | POP DEST        | Pops a word off the stack and stores it in DEST. Stack pointer goes to stack pointer - 2. |
| 0x0A   | ADD     | ADD DEST SRC    | DEST = DEST + SRC. Sets flags. |
| 0x0B   | SUB     | SUB DEST SRC    | DEST = DEST - SRC. Sets flags. |
| 0x0C   | MUL     | MUL DEST SRC    | DEST = DEST * SRC. |
| 0x0D   | DIV     | DIV DEST SRC    | DEST = DEST / SRC. On division by zero, the result is all 1s. |
| 0x0E   | AND     | AND DEST SRC    | DEST = DEST & SRC. Bitwise and. |
| 0x0F   | OR      | OR DEST SRC     | DEST = DEST | SRC. Bitwise or. |
| 0x10   | XOR     | XOR DEST SRC    | DEST = DEST ^ SRC. Bitwise exclusive or. |
| 0x11   | SHL     | SHL DEST SRC    | DEST = DEST << SRC. Logical left shift. |
| 0x12   | SHRA    | SHRA DEST SRC   | DEST = DEST >>> SRC. Arithmetic right shift, does sign extension. |
| 0x13   | SHRL    | SHRL DEST SRC   | DEST = DEST >> SRC. Logical right shift. |
| 0x14   | CMP     | CMP DEST SRC    | Does DEST - SRC and sets flags, but does not write to a register. |
| 0x15   | TST     | TST DEST SRC    | Does DEST & SRC and sets flags, but does not write to a register. |
| 0x16   | COLOR   | COLOR SRC       | Sets the color register to the lower 8 bits of SRC. |
| 0x17   | PIXEL   | PIXEL X Y       | Writes a pixel to the coordinates (X, Y) from the top-left corner of the screen. |
| 0x18   | STOR    | STOR SRC DEST   | Stores the data in SRC to the memory address in DEST. Uses register indirect addressing. |
| 0x19   | STORI   | STORI SRC ADDR  | Stores the data in SRC to the memory address ADDR. Uses direct addressing. |
| 0x1A   | TIME    | TIME DEST       | Stores the time (in milliseconds) since the last TIMERST instruction to DEST. |
| 0x1B   | TIMERST | TIMERST         | Resets the timing counter. |
| 0x1C   | RND     | RND DEST        | Gets 16 bits of random data and stores it in DEST. |
| 0x30   | JMP     | JMP REG         | Unconditionally jumps to the address stored in REG. Uses register indirect addressing. |
| 0x31   | JMPI    | JMPI ADDR       | Unconditionally jumps to the address ADDR. Uses direct addressing. |
| 0x32   | JEQ     | JEQ ADDR        | "Jump equal to". Jump to ADDR if ZF. Uses direct addressing. |
| 0x33   | JNE     | JNE ADDR        | "Jump not equal to". Jump to ADDR if !ZF. Uses direct addressing. |
| 0x34   | JG      | JG ADDR         | "Jump greater than". Jump to ADDR if !ZF && (SF == OF). Uses direct addressing. |
| 0x35   | JGE     | JGE ADDR        | "Jump greater than or equal to." Jump to ADDR if SF == OF. Uses direct addressing. |
| 0x36   | JA      | JA ADDR         | "Jump if above". Jump to ADDR if !CF && !ZF. Uses direct addressing. |
| 0x37   | JAE     | JAE ADDR        | "Jump if above or equal to". Jump to ADDR if !CF. Uses direct addressing. |
| 0x38   | JL      | JL ADDR         | "Jump less than". Jump to ADDR if SF != OF. Uses direct addressing. |
| 0x39   | JLE     | JLE ADDR        | "Jump less than or equal to." Jump to ADDR if ZF || (SF != OF). Uses direct addressing. |
| 0x3A   | JB      | JB ADDR         | "Jump if below". Jump to ADDR if CF. Uses direct addressing. |
| 0x3B   | JBE     | JBE ADDR        | "Jump if below or equal to". Jump to ADDR if ZF || CF. Uses direct addressing. |
| 0x3C   | JO      | JO ADDR         | "Jump on overflow". Jump to ADDR if OF. Uses direct addressing. |
| 0x3D   | JNO     | JNO ADDR        | "Jump on no overflow". Jump to ADDR if !OF. Uses direct addressing. |
| 0x3E   | JS      | JS ADDR         | "Jump on sign flag". Jump to ADDR if SF. Uses direct addressing. |
| 0x3F   | JNS     | JNS ADDR        | "Jump on no sign flag". Jump to ADDR if !SF. Uses direct addressing. |

Attempting to execute instructions with unrecognized opcodes should lead to halting of the processor.
