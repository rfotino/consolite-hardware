/**
 * A module for fetching the next instruction for
 * the processor to execute.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module instr_cache
  (
   input                        clk,
   input                        boot_done,
   // Requests for instructions
   input [`ADDR_BITS-1:0]       instr_ptr,
   output                       valid,
   output reg [`INSTR_BITS-1:0] instr,
   // Main memory controls
   output reg                   mem_cmd_en,
   output [2:0]                 mem_cmd_instr,
   output [5:0]                 mem_cmd_bl,
   output reg [29:0]            mem_cmd_byte_addr,
   input                        mem_cmd_empty,
   input                        mem_cmd_full,
   output reg                   mem_rd_en,
   input [31:0]                 mem_rd_data,
   input                        mem_rd_full,
   input                        mem_rd_empty,
   input [6:0]                  mem_rd_count,
   input                        mem_rd_overflow,
   input                        mem_rd_error
   );

   initial begin
      instr = 0;
      mem_cmd_en = 0;
      mem_cmd_byte_addr = 0;
      mem_rd_en = 0;
   end

   // Always read
   assign mem_cmd_instr = 3'b001;
   // Burst length is always one word (for now)
   assign mem_cmd_bl = 6'b000000;

   // State machine logic for talking to RAM
   `define STATE_PRE_BOOT 0
   `define STATE_CMD      1
   `define STATE_WAIT     2
   `define STATE_READ     3
   reg [1:0]  state = `STATE_PRE_BOOT;
   wire [29:0] prefixed_instr_ptr = { `MAIN_MEM_PREFIX, instr_ptr };
   assign valid = (`STATE_CMD == state) && (mem_cmd_byte_addr == prefixed_instr_ptr);
   always @ (posedge clk) begin
      mem_cmd_en <= 0;
      mem_rd_en <= 0;
      case (state)
         `STATE_PRE_BOOT: begin
            if (boot_done) begin
               send_cmd();
            end
         end
         `STATE_CMD: begin
            if (mem_cmd_byte_addr != prefixed_instr_ptr) begin
               send_cmd();
            end
         end
         `STATE_WAIT: begin
            if (!mem_rd_empty) begin
               mem_rd_en <= 1;
               state <= `STATE_READ;
            end
         end
         `STATE_READ: begin
            instr <= mem_rd_data;
            state <= `STATE_CMD;
         end
      endcase
   end

   task send_cmd;
      begin
         mem_cmd_en <= 1;
         mem_cmd_byte_addr <= prefixed_instr_ptr;
         state <= `STATE_WAIT;
      end
   endtask

endmodule
