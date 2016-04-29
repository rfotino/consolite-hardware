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
   output                      wr_done,
   input                       rd_en,
   input      [`ADDR_BITS-1:0] rd_addr,
   output reg [`WORD_BITS-1:0] rd_data,
   output                      rd_done,
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
      rd_data = 0;
      mem_cmd_en = 0;
      mem_wr_en = 0;
      mem_rd_en = 0;
   end

   // State machine for accessing the RAM
   localparam [2:0] STATE_PRE_BOOT = 0;
   localparam [2:0] STATE_IDLE     = 1;
   localparam [2:0] STATE_WR_CMD   = 2;
   localparam [2:0] STATE_WR_WAIT  = 3;
   localparam [2:0] STATE_RD_WAIT  = 4;
   localparam [2:0] STATE_RD_EN    = 5;
   reg [2:0] state = 0;
   wire mostly_done =
      (STATE_IDLE == state) && !wr_en && !rd_en && !mem_cmd_full;
   assign wr_done = mostly_done && !mem_wr_full;
   assign rd_done = mostly_done && !mem_rd_full;
   always @ (posedge clk) begin
      mem_cmd_en <= 0;
      mem_wr_en <= 0;
      mem_rd_en <= 0;
      case (state)
         STATE_PRE_BOOT: begin
            if (boot_done) begin
               state <= STATE_IDLE;
            end
         end
         STATE_IDLE: begin
            if (wr_en) begin
               // Set up command signals and write the data to the write FIFO
               mem_cmd_instr <= 3'b000;
               mem_cmd_bl <= 6'b000000;
               mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, wr_addr };
               mem_wr_en <= 1;
               // We write only the upper or lower 16 bits
               mem_wr_mask <= wr_addr[1] ? 4'b1100 : 4'b0011;
               mem_wr_data <= {2{wr_data}};
               state <= STATE_WR_CMD;
            end else if (rd_en) begin
               // Send the read command
               mem_cmd_en <= 1;
               mem_cmd_instr <= 3'b001;
               mem_cmd_bl <= 6'b000000;
               mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, rd_addr };
               state <= STATE_RD_WAIT;
            end
         end
         STATE_WR_CMD: begin
            mem_cmd_en <= 1;
            state <= STATE_IDLE;
         end
         STATE_RD_WAIT: begin
            if (!mem_rd_empty) begin
               mem_rd_en <= 1;
               state <= STATE_RD_EN;
            end
         end
         STATE_RD_EN: begin
            // Only grab the upper or lower half, depending on the second
            // to last address bit
            rd_data <= mem_cmd_byte_addr[1] ?
                       mem_rd_data[15:0] :
                       mem_rd_data[31:16];
            state <= STATE_IDLE;
         end
      endcase
   end

endmodule
