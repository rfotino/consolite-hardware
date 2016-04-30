/**
 * Does binary division of two unsigned integers. Returns
 * a quotient and a remainder after BITS clock cycles.
 * 
 * @author Robert Fotino, 2016
 */

module divider
  (
   input                 clk,
   input                 en,
   input [BITS-1:0]      dividend,
   input [BITS-1:0]      divisor,
   output reg [BITS-1:0] quotient,
   output [BITS-1:0]     remainder,
   output                done
   );

   initial begin
      quotient = 0;
   end

   parameter BITS = 16;

   localparam STATE_IDLE   = 0;
   localparam STATE_DIVIDE = 1;

   reg                    state = STATE_IDLE;
   reg [$clog2(BITS)-1:0] div_counter = 0;
   reg [(BITS-1)*2:0]     dividend_reg = 0;
   reg [(BITS-1)*2:0]     divisor_reg = 0;        

   assign done = (STATE_IDLE == state) && !en;
   assign remainder = dividend_reg[BITS-1:0];

   always @ (posedge clk) begin
      case (state)
        STATE_IDLE: begin
           if (en) begin
              div_counter <= 0;
              dividend_reg <= { {BITS-1{1'b0}}, dividend };
              divisor_reg <= { divisor, {BITS-1{1'b0}} };
              quotient <= 0;
              state <= STATE_DIVIDE;
           end
        end
        STATE_DIVIDE: begin
           // Increment the counter, if we will be done this cycle then
           // head back to STATE_IDLE
           if (div_counter == BITS - 1) begin
              state <= STATE_IDLE;
           end else begin
              div_counter <= div_counter + 1;
           end
           // Do one step of the division. Shift the divisor, possibly
           // subtract from the dividend, and shift the next bit onto
           // the quotient
           divisor_reg <= divisor_reg >> 1;
           if (dividend_reg < divisor_reg) begin
              quotient <= quotient << 1;
           end else begin
              quotient <= (quotient << 1) | 1'b1;
              dividend_reg <= dividend_reg - divisor_reg;
           end
        end
      endcase
   end

endmodule
