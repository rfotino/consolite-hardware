/**
 * Combines the inputs from buttons, switches, and GPIO
 * pins so that the processor can get the result of an
 * INPUT instruction.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module input_handler
  (
   input                             clk,
   input [5:0]                       buttons,
   input [7:0]                       switches,
   input [7:0]                       gpio_p6,
   input [7:0]                       gpio_p7,
   input [7:0]                       gpio_p8,
   input [7:0]                       gpio_p9,
   input [11:0]                      snes_0,
   input [11:0]                      snes_1,
   input [11:0]                      snes_2,
   input [11:0]                      snes_3,
   input [11:0]                      snes_4,
   input [11:0]                      snes_5,
   input [11:0]                      snes_6,
   input [11:0]                      snes_7,
   output reg [`NUM_USER_INPUTS-1:0] buf_inputs
   );

   always @ (posedge clk) begin
      buf_inputs <= {
         snes_7, snes_6, snes_5, snes_4,
         snes_3, snes_2, snes_1, snes_0,
         gpio_p9, gpio_p8, gpio_p7, gpio_p6,
         ~switches, ~buttons
      };
   end

endmodule
