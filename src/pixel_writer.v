/**
 * This module first zeros out video memory, then accepts
 * requests to write to individual pixels.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

`define STATE_CLEAR_SCREEN_WRITE 0
`define STATE_CLEAR_SCREEN_CMD   1
`define STATE_PIXEL_WRITE        2
`define STATE_PIXEL_CMD          3

module pixel_writer
  (
   input             clk,
   input             calib_done,
   output reg        clear_screen_done,
   output            pixel_wr_done,
   input             pixel_en,
   input [7:0]       pixel_rgb,
   input [7:0]       pixel_x,
   input [7:0]       pixel_y,
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
      clear_screen_done = 0;
      mem_cmd_en = 0;
      mem_cmd_bl = 6'b000000;
      mem_cmd_byte_addr = { `GRAPHICS_MEM_PREFIX, 16'h0000 };
      mem_wr_en = 0;
      mem_wr_mask = 4'b0000;
      mem_wr_data = 32'h00000000;
   end
   assign mem_cmd_instr = 3'b000; // write

   // The pixel writer will have a state machine to talk to RAM
   reg [1:0] state = `STATE_CLEAR_SCREEN_WRITE;
   assign pixel_wr_done = `STATE_PIXEL_WRITE == state && !mem_cmd_full && !mem_wr_full;
   reg [6:0] word_index = 0;
   reg [7:0] line_index = 0;
   always @ (posedge clk) begin
      mem_cmd_en <= 0;
      mem_wr_en <= 0;
      if (calib_done) begin
         case (state)
           `STATE_CLEAR_SCREEN_WRITE: begin
              mem_wr_en <= 1;
              mem_wr_data <= 32'h00000000;
              mem_wr_mask <= 4'b0000;
              word_index <= word_index + 1;
              if (word_index == 64) begin
                 word_index <= 0;
                 mem_wr_en <= 0;
                 mem_cmd_en <= 1;
                 mem_cmd_bl <= 6'b111111;
                 mem_cmd_byte_addr <= {
                    `GRAPHICS_MEM_PREFIX,
                    line_index,
                    8'b00000000
                 };
                 state <= `STATE_CLEAR_SCREEN_CMD;
              end
           end
           `STATE_CLEAR_SCREEN_CMD: begin
              if (mem_wr_empty) begin
                 if (line_index == 191) begin
                    clear_screen_done <= 1;
                    state <= `STATE_PIXEL_WRITE;
                 end else begin
                    line_index <= line_index + 1;
                    state <= `STATE_CLEAR_SCREEN_WRITE;
                 end
              end
           end
           `STATE_PIXEL_WRITE: begin
              if (pixel_en && pixel_wr_done) begin
                 mem_wr_en <= 1;
                 mem_wr_data <= {4{pixel_rgb}};
                 mem_wr_mask <= 0 == pixel_x[1:0] ? 4'b1110 :
                                1 == pixel_x[1:0] ? 4'b1101 :
                                2 == pixel_x[1:0] ? 4'b1011 : 4'b0111;
                 mem_cmd_byte_addr <= {
                    `GRAPHICS_MEM_PREFIX,
                    pixel_y, pixel_x[7:2], 2'b00
                 };
                 state <= `STATE_PIXEL_CMD;
              end
           end
           `STATE_PIXEL_CMD: begin
              mem_cmd_bl <= 6'b000000;
              mem_cmd_en <= 1;
              state <= `STATE_PIXEL_WRITE;
           end
         endcase
      end
   end

endmodule
