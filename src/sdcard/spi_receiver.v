/**
 * Used by the SD card reader to get responses from the
 * SPI flash interface.
 *
 * @author Robert Fotino, 2016
 */

module spi_receiver
  (
   input                      clk,
   input                      sclk_posedge,
   input                      sclk_negedge,
   input                      reset,
   input                      en,
   input                      in,
   output reg [DATA_BITS-1:0] out,
   output                     done
   );

   initial begin
      out = 0;
   end

   parameter DATA_BITS = 8;

   // State machine logic
   localparam STATE_IDLE    = 0;
   localparam STATE_WAITING = 1;
   localparam STATE_ENABLED = 2;
   reg [1:0]                   state = STATE_IDLE;
   reg [$clog2(DATA_BITS)-1:0] counter = 0;
   assign done = (STATE_IDLE == state) && !en;
   always @ (posedge clk) begin
      if (reset) begin
         state <= STATE_IDLE;
      end else begin
         case (state)
            // Wait here until we get the enabled signal
            STATE_IDLE: begin
               if (en) begin
                  out <= 0;
                  state <= STATE_WAITING;
                  counter <= 0;
               end
            end
            // Wait here until the input goes low, this
            // is the start of a data packet
            STATE_WAITING: begin
               if (!in) begin
                  state <= STATE_ENABLED;
               end
            end
            // We received the low signal, now we sample on the
            // rising edge of the synchronized clock until we have
            // all 8 bits
            STATE_ENABLED: begin
               if (sclk_posedge) begin
                  out <= { out[DATA_BITS-2:0], in };
                  if (counter == DATA_BITS - 1) begin
                     state <= STATE_IDLE;
                  end else begin
                     counter <= counter + 1;
                  end
               end
            end
         endcase
      end
   end

endmodule
