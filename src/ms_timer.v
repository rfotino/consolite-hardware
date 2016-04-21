/**
 * Handles TIME and TIMERST instructions by keeping a millisecond timer
 * and exposing a reset interface. Outputs 16-bit time representing the
 * number of milliseconds since the last reset, modulo 2^16.
 * 
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"


module ms_timer
  (
   input                       clk,
   input                       reset,
   output reg [`WORD_BITS-1:0] ms_time
   );

   initial begin
      ms_time = 0;
   end

   reg [16:0]        ms_counter = 1;
   always @ (posedge clk) begin
      if (reset) begin
         ms_counter <= 1;
         ms_time <= 0;
      end else begin
         if (ms_counter == 100000) begin
            ms_counter <= 1;
            ms_time <= ms_time + 1;
         end else begin
            ms_counter <= ms_counter + 1;
         end
      end
   end

endmodule
