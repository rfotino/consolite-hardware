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
   input wire        uart_load_done, // Done loading data from UART into RAM
   input wire [7:0]  uart_progress, // UART receiving progress from 0-255
   input wire [11:0] processor_status, // Shown in normal operation after boot
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else if (!clear_screen_done) begin
         seg_digits = `STATE_CLEAR_SCREEN;
      end else if (!uart_load_done) begin
         seg_digits = `STATE_UART_LOAD | uart_progress;
      end else begin
         seg_digits = processor_status;
      end
   end

endmodule
