/**
 * A module for reading the first 64 Kib off of the micro
 * SD card and writing it to RAM where it can be executed.
 *
 * For more information, see:
 * http://elm-chan.org/docs/mmc/mmc_e.html
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module sdcard_reader
  (
   input             clk,
   output reg        sdcard_read_done,
   // Signals for communicating with SD card
   output reg        sdcard_cs,
   output reg        sdcard_sclk,
   output reg        sdcard_mosi,
   input             sdcard_miso,
   // Signals for writing to RAM
   output reg        mem_cmd_en,
   output wire [2:0] mem_cmd_instr,
   output reg [5:0]  mem_cmd_bl,
   output reg [29:0] mem_cmd_byte_addr,
   input             mem_cmd_empty,
   input             mem_cmd_full,
   output reg        mem_wr_en,
   output reg [3:0]  mem_wr_mask,
   output reg [31:0] mem_wr_data,
   input             mem_wr_full,
   input             mem_wr_empty,
   input [6:0]       mem_wr_count,
   input             mem_wr_underrun,
   input             mem_wr_error
   );

   initial begin
      mem_cmd_en = 0;
      mem_wr_en = 0;
      sdcard_cs = 0;
      sdcard_sclk = 0;
      sdcard_mosi = 0;
      sdcard_read_done = 1;
   end

   // Always write
   assign mem_cmd_instr = 3'b000;

endmodule
