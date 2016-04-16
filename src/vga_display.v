/**
 * A VGA display controller for a 640x480 resolution @ 60Hz.
 * The clk is assumed to be 100MHz. For more information on timing
 * see http://tinyvga.com/vga-timing/640x480@60Hz.
 *
 * Author: Robert Fotino, 2016
 */

`include "definitions.vh"

module vga_display
  (
   input            clk,
   output           hsync,
   output           vsync,
   output reg [7:0] rgb,
   output           buf_empty,
   // Main memory control signals
   output           mem_cmd_en,
   output [2:0]     mem_cmd_instr,
   output [5:0]     mem_cmd_bl,
   output [29:0]    mem_cmd_byte_addr,
   input            mem_cmd_empty,
   input            mem_cmd_full,
   output           mem_rd_en,
   input [31:0]     mem_rd_data,
   input            mem_rd_full,
   input            mem_rd_empty,
   input [6:0]      mem_rd_count,
   input            mem_rd_overflow,
   input            mem_rd_error
   );

   // The x and y coordinates of the 256x192 screen, and
   // other signals for communicating with the VGA buffer
   reg [7:0]  x_coord = 0;
   reg [7:0]  y_coord = 0;
   reg        buf_invalidate = 0;
   wire [7:0] buf_rgb;

   // Instantiate a VGA buffer and get the byte to display from there.
   vga_buffer vga_buffer_
     (
      .clk(clk),
      .x_coord(x_coord),
      .y_coord(y_coord),
      .invalidate(buf_invalidate),
      .empty(buf_empty),
      .rgb(buf_rgb),
      .mem_cmd_en(mem_cmd_en),
      .mem_cmd_instr(mem_cmd_instr),
      .mem_cmd_bl(mem_cmd_bl),
      .mem_cmd_byte_addr(mem_cmd_byte_addr),
      .mem_cmd_empty(mem_cmd_empty),
      .mem_cmd_full(mem_cmd_full),
      .mem_rd_en(mem_rd_en),
      .mem_rd_data(mem_rd_data),
      .mem_rd_full(mem_rd_full),
      .mem_rd_empty(mem_rd_empty),
      .mem_rd_count(mem_rd_count),
      .mem_rd_overflow(mem_rd_overflow),
      .mem_rd_error(mem_rd_error)
      );

   // Divide the clock into 25MHz. Pixel clock for 640x480 VGA
   // should be 25.175MHz but we can't clock divide that from 100MHz.
   reg [1:0]        counter = 0;
   wire             pixel_clk = counter[1];
   always @ (posedge clk) begin
      counter <= counter + 1;
   end

   // Counter for VGA (x, y) coords
   reg [9:0] counter_x = 0;
   reg [9:0] counter_y = 0;
   // The number of times the screen (x, y) coord has been displayed
   reg [1:0] counter_x_coord = 0;
   reg [1:0] counter_y_coord = 0;
   // The width and heights of the current screen (x, y) coord. Alternates
   // between 2 and 3 (0-based) because the ratio of VGA coords to screen
   // coords is 2.5
   reg [1:0] counter_x_coord_max = 2;
   reg [1:0] counter_y_coord_max = 2;
   assign hsync = ~(`VGA_WIDTH + `VGA_H_FRONT_PORCH <= counter_x &&
                    counter_x < `VGA_WIDTH + `VGA_H_FRONT_PORCH + `VGA_H_SYNC_PULSE);
   assign vsync = ~(`VGA_HEIGHT + `VGA_V_FRONT_PORCH <= counter_y &&
                    counter_y < `VGA_HEIGHT + `VGA_V_FRONT_PORCH + `VGA_V_SYNC_PULSE);
   always @ (posedge pixel_clk) begin
      // Check if we're in the drawing space
      if (counter_x < `VGA_WIDTH && counter_y < `VGA_HEIGHT) begin
         // Increment the x_coord for the 256x192 screen if necessary
         if (counter_x_coord == counter_x_coord_max) begin
            x_coord <= x_coord + 1;
            counter_x_coord <= 0;
            if (x_coord[0]) begin
               counter_x_coord_max <= 2; // x-coord is odd
            end else begin
               counter_x_coord_max <= 1; // x-coord is even
            end
         end else begin
            counter_x_coord <= counter_x_coord + 1;
         end
         // Increment the y_coord for the 256x192 screen if necessary
         if (counter_x == `VGA_WIDTH - 1) begin
            if (counter_y_coord == counter_y_coord_max) begin
               y_coord <= y_coord + 1;
               counter_y_coord <= 0;
               if (y_coord[0]) begin
                  counter_y_coord_max <= 2; // y-coord is odd
               end else begin
                  counter_y_coord_max <= 1; // y-coord is even
               end
            end else begin
               counter_y_coord <= counter_y_coord + 1;
            end
         end else if (counter_y == 0) begin
            y_coord <= 0;
         end
         // Display the color driven out of the buffer
         rgb <= buf_rgb;
      end else begin
         // We're not in the drawing space
         rgb <= 0;
      end
      // Move on to the next pixel
      if (`VGA_H_TOTAL - 1 <= counter_x) begin
         counter_x <= 0;
         if (`VGA_V_TOTAL - 1 <= counter_y) begin
            counter_y <= 0;
         end else begin
            counter_y <= counter_y + 1;
         end
      end else begin
         counter_x <= counter_x + 1;
      end
   end

   // Invalidate the bytes we're pulling out of the buffer
   // if this is the last line of pixels we're using them for
   always @ (*) begin
      buf_invalidate =
         (counter == 0) && // Only go high for one clock cycle
         (counter_x_coord == counter_x_coord_max) &&
         (counter_y_coord == counter_y_coord_max);
   end

endmodule
