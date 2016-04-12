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
   input wire [45:0] buf_inputs, // The buffered user inputs
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else begin
         if (buf_inputs[0]) begin
            seg_digits = 12'h000;
         end else if (buf_inputs[1]) begin
            seg_digits = 12'h001;
         end else if (buf_inputs[2]) begin
            seg_digits = 12'h002;
         end else if (buf_inputs[3]) begin
            seg_digits = 12'h003;
         end else if (buf_inputs[4]) begin
            seg_digits = 12'h004;
         end else if (buf_inputs[5]) begin
            seg_digits = 12'h005;
         end else if (buf_inputs[6]) begin
            seg_digits = 12'h006;
         end else if (buf_inputs[7]) begin
            seg_digits = 12'h007;
         end else if (buf_inputs[8]) begin
            seg_digits = 12'h008;
         end else if (buf_inputs[9]) begin
            seg_digits = 12'h009;
         end else if (buf_inputs[10]) begin
            seg_digits = 12'h010;
         end else if (buf_inputs[11]) begin
            seg_digits = 12'h011;
         end else if (buf_inputs[12]) begin
            seg_digits = 12'h012;
         end else if (buf_inputs[13]) begin
            seg_digits = 12'h013;
         end else begin
            seg_digits = `STATE_DEFAULT;
         end
      end
   end

endmodule
