/**
 * Receives serial data from the UART interface and exposes it
 * to the containing module as parallel data.
 *
 * @author Robert Fotino, 2016
 */

module uart
  (
   input                      clk,
   input                      rst,  // Synchronous reset
   input                      rx,   // Data in
   output reg                 busy, // Goes high when receiving data
   output reg [DATA_BITS-1:0] data  // Data output
   );

   initial begin
      busy = 0;
      data = 0;
   end

   // Variables/constants for clock division depending on baud
   parameter DATA_BITS = 8;
   parameter BAUD = 19200;
   parameter CLK_RATE = 100000000;
   localparam CLK_DIV = CLK_RATE / BAUD;
   reg [$clog2(CLK_DIV)-1:0] baud_counter = 0;
   // Input comes in the form of 0AAAAAAAA1
   // where A[7:0] is the input byte
   `define STATE_IDLE      0
   `define STATE_WAIT_HALF 1
   `define STATE_RX        2
   `define STATE_END       3
   reg [1:0] state = `STATE_IDLE;
   reg rx_reg = 1;
   assign uart_state = state;
   reg [$clog2(DATA_BITS)-1:0] rx_counter = 0;
   always @ (posedge clk) begin
      rx_reg <= rx;
      if (rst) begin
         state <= `STATE_IDLE;
         busy <= 0;
      end else begin
         case (state)
           `STATE_IDLE: begin
              if (~rx_reg) begin
                 busy <= 1;
                 state <= `STATE_WAIT_HALF;
                 baud_counter <= 0;
                 rx_counter <= 0;
              end
           end
           `STATE_WAIT_HALF: begin
              if (baud_counter == (CLK_DIV / 2) - 1) begin
                 state <= `STATE_RX;
                 baud_counter <= 0;
              end else begin
                 baud_counter <= baud_counter + 1;
              end
           end
           `STATE_RX: begin
              if (baud_counter == CLK_DIV - 1) begin
                 data <= { rx_reg, data[7:1] }; // Sample the serial input
                 baud_counter <= 0;
                 if (rx_counter == DATA_BITS - 1) begin
                    state <= `STATE_END;
                 end else begin
                    rx_counter <= rx_counter + 1;
                 end
              end else begin
                 baud_counter <= baud_counter + 1;
              end
           end
           `STATE_END: begin
              if (baud_counter == CLK_DIV - 1) begin
                 state <= `STATE_IDLE;
                 busy <= 0;
              end else begin
                 baud_counter <= baud_counter + 1;
              end
           end
         endcase
      end
   end

endmodule
