/**
 * Defines constants used in Consolite.
 *
 * @author Robert Fotino, 2016
 */

// VGA timing
`define VGA_WIDTH           1024
`define VGA_H_FRONT_PORCH   24
`define VGA_H_SYNC_PULSE    136
`define VGA_H_BACK_PORCH    160
`define VGA_H_TOTAL         (`VGA_WIDTH + `VGA_H_FRONT_PORCH + \
                             `VGA_H_SYNC_PULSE + `VGA_H_BACK_PORCH)
`define VGA_HEIGHT          768
`define VGA_V_FRONT_PORCH   3
`define VGA_V_SYNC_PULSE    6
`define VGA_V_BACK_PORCH    29
`define VGA_V_TOTAL         (`VGA_HEIGHT + `VGA_V_FRONT_PORCH + \
                             `VGA_V_SYNC_PULSE + `VGA_V_BACK_PORCH)

// VGA buffer size in bytes
`define VGA_BUF_SIZE        256

// Consolite logical screen size
`define SCREEN_WIDTH        256
`define SCREEN_HEIGHT       192

// Size of words, addresses, instructions, etc
`define WORD_BITS           16
`define ADDR_BITS           16
`define INSTR_BITS          32
`define NUM_REGS            16
`define WORD_BYTES          `WORD_BITS / 8
`define ADDR_BYTES          `ADDR_BITS / 8
`define INSTR_BYTES         `INSTR_BITS / 8

// Memory accesses are 16 bits, but the LPDDR RAM
// has 30-bit address sizes. To access different
// segments of memory we add a 14-bit prefix
`define MAIN_MEM_PREFIX     14'b0
`define GRAPHICS_MEM_PREFIX 14'b1

// The number of inputs that user code can access.
// There are 6 buttons, 8 switches, 32 GPIOs, and
// 8 12-button SNES controllers
`define NUM_USER_INPUTS     142
 
// States for the 7-seg display
`define STATE_MEM_UNCALIB   12'h500
`define STATE_MEM_ERROR     12'h501
`define STATE_CLEAR_SCREEN  12'h502
`define STATE_SDCARD_ERROR  12'h503
`define STATE_UART_LOAD     12'h600
`define STATE_INVALID_INSTR 12'h700
`define STATE_SDCARD_READ   12'h800
`define STATE_DEFAULT       12'h100

// Stack pointer
`define REG_SP              4'b0

// Opcode definitions
`define OPCODE_NOP          8'h00
`define OPCODE_INPUT        8'h01
`define OPCODE_CALL         8'h02
`define OPCODE_RET          8'h03
`define OPCODE_LOAD         8'h04
`define OPCODE_LOADI        8'h05
`define OPCODE_MOV          8'h06
`define OPCODE_MOVI         8'h07
`define OPCODE_PUSH         8'h08
`define OPCODE_POP          8'h09
`define OPCODE_ADD          8'h0A
`define OPCODE_SUB          8'h0B
`define OPCODE_MUL          8'h0C
`define OPCODE_DIV          8'h0D
`define OPCODE_AND          8'h0E
`define OPCODE_OR           8'h0F
`define OPCODE_XOR          8'h10
`define OPCODE_SHL          8'h11
`define OPCODE_SHRA         8'h12
`define OPCODE_SHRL         8'h13
`define OPCODE_CMP          8'h14
`define OPCODE_TST          8'h15
`define OPCODE_COLOR        8'h16
`define OPCODE_PIXEL        8'h17
`define OPCODE_STOR         8'h18
`define OPCODE_STORI        8'h19
`define OPCODE_TIME         8'h1A
`define OPCODE_TIMERST      8'h1B
`define OPCODE_RND          8'h1C
`define OPCODE_JMP          8'h30
`define OPCODE_JMPI         8'h31
`define OPCODE_JEQ          8'h32
`define OPCODE_JNE          8'h33
`define OPCODE_JG           8'h34
`define OPCODE_JGE          8'h35
`define OPCODE_JA           8'h36
`define OPCODE_JAE          8'h37
`define OPCODE_JL           8'h38
`define OPCODE_JLE          8'h39
`define OPCODE_JB           8'h3A
`define OPCODE_JBE          8'h3B
`define OPCODE_JO           8'h3C
`define OPCODE_JNO          8'h3D
`define OPCODE_JS           8'h3E
`define OPCODE_JNS          8'h3F
