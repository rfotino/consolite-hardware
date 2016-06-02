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
   input             boot_done, // Done booting, processor can execute
   input             mem_calib_done, // LPDDR RAM calibration complete
   input             mem_error, // Bit error with LPDDR RAM
   input             clear_screen_done, // Done zeroing video memory
   input             sdcard_read_started, // Started reading from the SD card
   input             sdcard_read_done, // Done reading from the SD card
   input             sdcard_read_error, // Error reading from SD card
   input [7:0]       sdcard_progress, // SDC receiving progress from 0-255
   input             uart_load_started, // Started loading data from UART into RAM
   input             uart_load_done, // Done loading data from UART into RAM
   input [7:0]       uart_progress, // UART receiving progress from 0-255
   input [11:0]      processor_status, // Shown in normal operation after boot
   output reg [11:0] seg_digits
   );

   always @ (*) begin
      if (!mem_calib_done) begin
         seg_digits = `STATE_MEM_UNCALIB;
      end else if (mem_error) begin
         seg_digits = `STATE_MEM_ERROR;
      end else if (!clear_screen_done) begin
         seg_digits = `STATE_CLEAR_SCREEN;
      end else if (sdcard_read_error) begin
         seg_digits = `STATE_SDCARD_ERROR;
      end else if (sdcard_read_started && !sdcard_read_done) begin
         seg_digits = `STATE_SDCARD_READ | sdcard_progress;
      end else if (!boot_done) begin
         seg_digits = `STATE_UART_LOAD | uart_progress;
      end else begin
         seg_digits = processor_status;
      end
   end

endmodule
