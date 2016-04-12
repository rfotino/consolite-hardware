/**
 * This module combines various status signals and outputs 3
 * hex digits (for a total of 12 bits) to be displayed by the
 * 7-segment display.
 *
 * @author Robert Fotino, 2016
 */

`define STATE_MEM_UNCALIB  12'h500
`define STATE_MEM_ERROR    12'h501
`define STATE_DEFAULT      12'h100

module seg_status
  (
   input wire        mem_calib_done, // High if LPDDR RAM calibration complete
   input wire        mem_error, // High if a bit error with LPDDR RAM
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else begin
         seg_digits = `STATE_DEFAULT;
      end
   end

endmodule
