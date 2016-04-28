/**
 * A module for helping the processor handle loads
 * and stores to and from main memory.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module data_cache
  (
   input                       clk,
   input                       boot_done,
   // Interface for using the cache
   input                       wr_en,
   input [`ADDR_BITS-1:0]      wr_addr,
   input [`WORD_BITS-1:0]      wr_data,
   output reg                  wr_done,
   input                       rd_en,
   input      [`ADDR_BITS-1:0] rd_addr,
   output reg [`WORD_BITS-1:0] rd_data,
   output reg                  rd_done,
   // Signals for communicating with main memory
   output reg                  mem_cmd_en,
   output reg [2:0]            mem_cmd_instr,
   output reg [5:0]            mem_cmd_bl,
   output reg [29:0]           mem_cmd_byte_addr,
   input                       mem_cmd_empty,
   input                       mem_cmd_full,
   output reg                  mem_wr_en,
   output reg [3:0]            mem_wr_mask,
   output reg [31:0]           mem_wr_data,
   input                       mem_wr_full,
   input                       mem_wr_empty,
   input [6:0]                 mem_wr_count,
   input                       mem_wr_underrun,
   input                       mem_wr_error,
   output reg                  mem_rd_en,
   input [31:0]                mem_rd_data,
   input                       mem_rd_full,
   input                       mem_rd_empty,
   input [6:0]                 mem_rd_count,
   input                       mem_rd_overflow,
   input                       mem_rd_error
   );

   initial begin
      wr_done = 0;
      rd_data = 0;
      rd_done = 0;
      mem_cmd_en = 0;
      mem_wr_en = 0;
      mem_rd_en = 0;
   end

   // State machine for accessing the RAM
   `define STATE_PRE_BOOT 0
   `define STATE_IDLE     1
   `define STATE_WR_CMD   2
   `define STATE_WR_WAIT  3
   `define STATE_RD_WAIT  4
   `define STATE_RD_EN    5
   reg [2:0] state = 0;
   always @ (posedge clk) begin
      mem_cmd_en <= 0;
      mem_wr_en <= 0;
      mem_rd_en <= 0;
      case (state)
         `STATE_PRE_BOOT: begin
            if (boot_done) begin
               state <= `STATE_IDLE;
            end
         end
         `STATE_IDLE: begin
            if (wr_en) begin
               // Set up command signals and write the data to the write FIFO
               wr_done <= 0;
               mem_cmd_instr <= 3'b000;
               mem_cmd_bl <= 6'b000000;
               mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, wr_addr };
               mem_wr_en <= 1;
               mem_wr_mask <= wr_addr[1] ? 4'b1100 : 4'b0011;
               mem_wr_data <= wr_data;
               state <= `STATE_WR_CMD;
            end else if (rd_en) begin
               // Send the read command
               rd_done <= 0;
               mem_cmd_en <= 1;
               mem_cmd_instr <= 3'b001;
               mem_cmd_bl <= 6'b000000;
               mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, rd_addr };
               state <= `STATE_RD_WAIT;
            end
         end
         `STATE_WR_CMD: begin
            mem_cmd_en <= 1;
            if (mem_cmd_full || mem_wr_full) begin
               state <= `STATE_WR_WAIT;
            end else begin
               wr_done <= 1;
               state <= `STATE_IDLE;
            end
         end
         `STATE_WR_WAIT: begin
            if (!mem_cmd_full && !mem_wr_full) begin
               wr_done <= 1;
               state <= `STATE_IDLE;
            end
         end
         `STATE_RD_WAIT: begin
            if (!mem_rd_empty) begin
               mem_rd_en <= 1;
               state <= `STATE_RD_EN;
            end
         end
         `STATE_RD_EN: begin
            rd_done <= 1;
            rd_data <= mem_rd_data;
            state <= `STATE_IDLE;
         end
      endcase
   end

endmodule
