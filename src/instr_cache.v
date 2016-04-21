/**
 * A module for fetching the next instruction for
 * the processor to execute.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module instr_cache
  (
   input clk,
   output reg        mem_cmd_en,
   output wire [2:0] mem_cmd_instr,
   output reg [5:0]  mem_cmd_bl,
   output reg [29:0] mem_cmd_byte_addr,
   input             mem_cmd_empty,
   input             mem_cmd_full,
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
      mem_rd_en = 0;
   end

   // Always read
   assign mem_cmd_instr = 3'b001;

endmodule
