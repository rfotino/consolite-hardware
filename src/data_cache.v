/**
 * A module for helping the processor handle loads
 * and stores to and from main memory.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module data_cache
  (
   input             clk,
   input             boot_done,
   output reg        mem_cmd_en,
   output reg [2:0]  mem_cmd_instr,
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
   input             mem_wr_error,
   output reg        mem_rd_en,
   input [31:0]      mem_rd_data,
   input             mem_rd_full,
   input             mem_rd_empty,
   input [6:0]       mem_rd_count,
   input             mem_rd_overflow,
   input             mem_rd_error
   );

   initial begin
      mem_cmd_en = 0;
      mem_wr_en = 0;
      mem_rd_en = 0;
   end

endmodule
