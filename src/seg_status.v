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
   // LPDDR RAM calibration complete
   input wire                        mem_calib_done,
   // Bit error with LPDDR RAM
   input wire                        mem_error,
   // VGA buffer empty
   input wire                        vga_buf_empty,
   // The buffered user inputs
   input wire [`NUM_USER_INPUTS-1:0] buf_inputs,
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else if (vga_buf_empty) begin
         seg_digits = `STATE_VGA_BUF_EMPTY;
      end else begin
         seg_digits = `STATE_DEFAULT;
      end
   end

endmodule
