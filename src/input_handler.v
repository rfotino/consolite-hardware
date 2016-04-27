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
   output reg [`NUM_USER_INPUTS-1:0] buf_inputs
   );

   always @ (posedge clk) begin
      buf_inputs <= {
         gpio_p9, gpio_p8, gpio_p7, gpio_p6,
         ~switches, ~buttons
      };
   end

endmodule
