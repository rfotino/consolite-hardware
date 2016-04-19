/**
 * This module combines various status signals and outputs 3
 * hex digits (for a total of 12 bits) to be displayed by the
 * 7-segment display.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module seg_status
  (
   input wire        mem_calib_done, // LPDDR RAM calibration complete
   input wire        mem_error, // Bit error with LPDDR RAM
   input wire        clear_screen_done, // Done zeroing video memory
   input wire        sdcard_read_done, // Done loading SD card contents into RAM
   input wire        vga_buf_empty, // VGA buffer empty
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else if (!clear_screen_done) begin
         seg_digits = `STATE_CLEAR_SCREEN;
      end else if (!sdcard_read_done) begin
         seg_digits = `STATE_SDCARD_READ;
      end else if (vga_buf_empty) begin
         seg_digits = `STATE_VGA_BUF_EMPTY;
      end else begin
         seg_digits = `STATE_DEFAULT;
      end
   end

endmodule
