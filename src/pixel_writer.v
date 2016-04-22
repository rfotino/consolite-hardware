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
              mem_cmd_en <= 0;
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
              mem_wr_en <= 0;
              mem_cmd_bl <= 6'b000000;
              mem_cmd_en <= ~mem_cmd_en;
              if (mem_cmd_en) begin
                 state <= `STATE_PIXEL_WRITE;
              end
           end
         endcase
      end
   end

endmodule

/**
 * Draws a space invader graphic to the screen as a test for
 * the pixel writer at (50, 50). The graphic is 11 pixels wide
 * and 8 pixels high, with white as the foreground and red as
 * the background. In tests it runs in ~350 cycles, or
 * 3.5 microseconds.
 *
 * @author Robert Fotino, 2016
 */
module pixel_tester
  (
   input clk,
   input clear_screen_done,
   input pixel_wr_done,
   output reg pixel_en,
   output [7:0] pixel_rgb,
   output [7:0] pixel_x,
   output [7:0] pixel_y
   );

   `define WIDTH  11
   `define HEIGHT 8
   wire [`WIDTH-1:0] graphic [`HEIGHT-1:0] = {
      11'b00011011000,
      11'b10100000101,
      11'b10111111101,
      11'b11111111111,
      11'b01101110110,
      11'b00111111100,
      11'b00010001000,
      11'b00100000100
   };

   reg [7:0] x = 0;
   reg [7:0] y = 0;
   assign pixel_rgb = graphic[y][x] ? 8'hff : 8'he0;
   assign pixel_x = 50 + x;
   assign pixel_y = 50 + y;
   reg [1:0] status = 0;

   initial begin
      pixel_en = 0;
   end

   always @ (posedge clk) begin
      case (status)
         0: begin
            if (pixel_wr_done) begin
               pixel_en <= 1;
               status <= 1;
            end
         end
         1: begin
            if (pixel_wr_done) begin
               if (x == `WIDTH - 1) begin
                  x <= 0;
                  if (y == `HEIGHT - 1) begin
                     pixel_en <= 0;
                     status <= 2;
                  end else begin
                     y <= y + 1;
                  end
               end else begin
                  x <= x + 1;
               end
            end
         end
         2: begin
            // Do nothing
         end
      endcase
   end

endmodule