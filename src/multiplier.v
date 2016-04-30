/**
 * A module for doing multiplication split across multiple
 * clock cycles.
 *
 * @author Robert Fotino, 2016
 */

module multiplier
  (
   input                     clk,
   input                     en,
   input [BITS-1:0]          data_a,
   input [BITS-1:0]          data_b,
   output reg [(BITS*2)-1:0] result,
   output                    done
   );

   parameter BITS = 16;

   localparam STATE_IDLE     = 0;
   localparam STATE_MULTIPLY = 1;

   reg                    state = STATE_IDLE;
   reg [$clog2(BITS)-1:0] mul_counter = 0;
   reg [BITS-1:0]         data_a_reg = 0;
   reg [(BITS*2)-1:0]     data_b_reg = 0;

   assign done = (STATE_IDLE == state) && !en;

   always @ (posedge clk) begin
      case (state)
         STATE_IDLE: begin
            if (en) begin
               mul_counter <= 0;
               data_a_reg <= data_a;
               data_b_reg <= { {BITS{1'b0}}, data_b };
               result <= 0;
               state <= STATE_MULTIPLY;
            end
         end
         STATE_MULTIPLY: begin
            if (mul_counter == BITS - 1) begin
               state <= STATE_IDLE;
            end else begin
               mul_counter <= mul_counter + 1;
            end
            data_a_reg <= data_a_reg >> 1;
            data_b_reg <= data_b_reg << 1;
            if (data_a_reg[0]) begin
               result <= result + data_b_reg;
            end
         end
      endcase
   end

endmodule
