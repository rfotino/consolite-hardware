/**
 * A VGA display controller for a 640x480 resolution @ 60Hz.
 * The clk is assumed to be 100MHz. For more information on timing
 * see http://tinyvga.com/vga-timing/640x480@60Hz.
 *
 * Author: Robert Fotino, 2016
 */
module vga_display
  (
   input            clk,
   output           hsync,
   output           vsync,
   output reg [7:0] rgb
   );

   /**
    * Divide the clock into 25MHz. Pixel clock for 640x480 VGA
    * should be 25.175MHz but we can't clock divide that from 100MHz.
    */
   reg [1:0]        counter = 0;
   wire             pixel_clk = counter[1];
   always @ (posedge clk) begin
      counter <= counter + 1;
   end

   /**
    * Horizontal timing (line):
    * visible area (640 pixels)
    * front porch (16 pixels)
    * hsync pulse (96 pixels, active low)
    * back porch (48 pixels)
    * total (800 pixels)
    *
    * Vertical timing (frame):
    * visible area (480 lines)
    * front porch (10 lines)
    * vsync pulse (2 lines, active low)
    * back porch (33 lines)
    * total (525 lines)
    */
   reg [9:0] counter_x = 0;
   reg [9:0] counter_y = 0;
   assign hsync = ~(656 <= counter_x && counter_x < 752);
   assign vsync = ~(490 <= counter_y && counter_y < 492);
   always @ (posedge pixel_clk) begin
      // Test the RGB colors
      if (counter_x < 213) begin
         rgb <= 8'b11100000; //red
      end else if (counter_x < 426) begin
         rgb <= 8'b00011100; //green
      end else if (counter_x < 640) begin
         rgb <= 8'b00000011; //blue
      end else begin
         rgb <= 8'b00000000; //black
      end
      // Move on to the next pixel
      if (799 <= counter_x) begin
         counter_x <= 0;
         if (524 <= counter_y) begin
            counter_y <= 0;
         end else begin
            counter_y <= counter_y + 1;
         end
      end else begin
         counter_x <= counter_x + 1;
      end
   end

endmodule
