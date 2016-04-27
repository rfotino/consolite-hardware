/**
 * Defines constants used in Consolite.
 *
 * @author Robert Fotino, 2016
 */

// VGA timing
`define VGA_WIDTH           640
`define VGA_H_FRONT_PORCH   16
`define VGA_H_SYNC_PULSE    96
`define VGA_H_BACK_PORCH    48
`define VGA_H_TOTAL         (`VGA_WIDTH + `VGA_H_FRONT_PORCH + \
                             `VGA_H_SYNC_PULSE + `VGA_H_BACK_PORCH)
`define VGA_HEIGHT          480
`define VGA_V_FRONT_PORCH   10
`define VGA_V_SYNC_PULSE    2
`define VGA_V_BACK_PORCH    33
`define VGA_V_TOTAL         (`VGA_HEIGHT + `VGA_V_FRONT_PORCH + \
                             `VGA_V_SYNC_PULSE + `VGA_V_BACK_PORCH)

// VGA buffer size in bytes
`define VGA_BUF_SIZE        256

// Consolite logical screen size
`define SCREEN_WIDTH        256
`define SCREEN_HEIGHT       192

// Bits in a Consolite word
`define WORD_BITS           16

// Memory accesses are 16 bits, but the LPDDR RAM
// has 30-bit address sizes. To access different
// segments of memory we add a 14-bit prefix
`define MAIN_MEM_PREFIX     14'b0
`define GRAPHICS_MEM_PREFIX 14'b1

// The number of inputs that user code can access.
// There are 6 buttons, 8 switches, and 32 GPIOs
`define NUM_USER_INPUTS     46
 
// States for the 7-seg display
`define STATE_MEM_UNCALIB   12'h500
`define STATE_MEM_ERROR     12'h501
`define STATE_CLEAR_SCREEN  12'h502
`define STATE_UART_LOAD     12'h503
`define STATE_DEFAULT       12'h100
