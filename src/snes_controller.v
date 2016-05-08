/**
 * A module for getting button state from an SNES controller.
 * If no controller is plugged in, serial_in should be low so
 * the buttons will all be in the "off" position. The button_state
 * output array is active (pressed) high. The button_state array
 * has buttons in the following order (from 0 to 11): B, Y, SELECT,
 * START, UP, DOWN, LEFT, RIGHT, A, X, L, R. See details at
 * http://www.gamefaqs.com/snes/916396-super-nintendo/faqs/5395
 *
 * @author Robert Fotino, 2016
 */

module snes_controller
  (
   input                              clk,
   input                              serial_in,
   output reg                         data_clk,
   output reg                         data_latch, 
   output reg [SNES_BUTTON_COUNT-1:0] button_state
   );

   initial begin
      data_clk = 0;
      data_latch = 0;
      button_state = 0;
   end

   localparam SNES_BUTTON_COUNT = 12;

   localparam COUNTER_60HZ_MAX = 100000000 / 60;
   localparam COUNTER_12US_MAX = 1200;

   localparam STATE_WAIT = 0;
   localparam STATE_LATCH = 1;
   localparam STATE_DATA = 2;

   reg [1:0]                           state = STATE_WAIT;
   reg [$clog2(COUNTER_60HZ_MAX)-1:0]  counter_60hz = 0;
   reg [$clog2(COUNTER_12US_MAX)-1:0]  counter_12us = 0;
   reg [3:0]                           data_counter = 0;
   reg [SNES_BUTTON_COUNT-1:0]         buf_button_state = 0;

   always @ (posedge clk) begin
      // Default outputs for data_clk and data_latch
      data_clk <= counter_12us < 600;
      data_latch <= 0;
      // A 60 Hz counter for the data latch
      if (COUNTER_60HZ_MAX - 1 == counter_60hz) begin
         counter_60hz <= 0;
      end else begin
         counter_60hz <= counter_60hz + 1;
      end
      // A 12 microsecond counter for communication
      if (COUNTER_12US_MAX - 1 == counter_12us) begin
         counter_12us <= 0;
      end else begin
         counter_12us <= counter_12us + 1;
      end
      // State machine logic
      case (state)
        // Wait for the next change of the 60 Hz sample clock
        STATE_WAIT: begin
           data_clk <= 1;
           if (0 == counter_60hz) begin
              counter_12us <= 0;
              state <= STATE_LATCH;
           end
        end
        // Sends a 12 microsecond pulse on the data latch, indicating we are
        // ready to receive the button state from the controller
        STATE_LATCH: begin
           data_clk <= 1;
           data_latch <= 1;
           if (COUNTER_12US_MAX - 1 == counter_12us) begin
              state <= STATE_DATA;
           end
        end
        // In the middle of the 12 microsecond serial data pulse, sample the
        // data and shift it onto the parallel output
        STATE_DATA: begin
           if ((COUNTER_12US_MAX / 2) - 1 == counter_12us) begin
              if (data_counter < 12) begin
                 buf_button_state <= { ~serial_in, buf_button_state[11:1] };
              end else if (~serial_in) begin
                 // The serial input is always high for the last 4 pulses
                 // that aren't mapped to any of the 12 buttons. If the serial
                 // input is low, the controller isn't connected so we default low
                 buf_button_state <= 0;
              end
              if (15 == data_counter) begin
                 data_counter <= 0;
                 button_state <= buf_button_state;
                 state <= STATE_WAIT;
              end else begin
                 data_counter <= data_counter + 1;
              end
           end
        end
      endcase
   end

endmodule
