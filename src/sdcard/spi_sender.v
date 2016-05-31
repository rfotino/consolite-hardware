/**
 * Used by the SD card reader to send commands via the
 * SPI flash interface.
 *
 * @author Robert Fotino, 2016
 */

module spi_sender
  (
   input                  clk,
   input                  sclk_posedge,
   input                  sclk_negedge,
   input                  reset,
   input                  en,
   input [DATA_BITS-1:0]  data,
   output reg             out,
   output                 done
   );

   parameter DATA_BITS = 48;

   // State machine logic
   localparam STATE_IDLE    = 0;
   localparam STATE_ENABLED = 1;
   reg                         state = STATE_IDLE;
   reg [$clog2(DATA_BITS)-1:0] out_index = DATA_BITS - 1;
   reg [DATA_BITS-1:0]         saved_data = 0;
   assign done = (STATE_IDLE == state) && !en;
   always @ (posedge clk) begin
      if (reset) begin
         state <= STATE_IDLE;
         out = 1;
      end else begin
         case (state)
            STATE_IDLE: begin
               out = 1;
               if (en) begin
                  state <= STATE_ENABLED;
                  out_index <= DATA_BITS - 1;
                  saved_data <= data;
               end
            end
            STATE_ENABLED: begin
               out = saved_data[out_index];
               if (out_index == 0) begin
                  state <= STATE_IDLE;
               end else if (sclk_negedge) begin
                  out_index <= out_index - 1'b1;
               end
            end
         endcase
      end
   end

endmodule
