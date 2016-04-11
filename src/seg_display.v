`define STATE_MEM_UNCALIB  12'h500
`define STATE_MEM_ERROR    12'h501
`define STATE_DEFAULT      12'h100

module seg_display
  (
   input wire       clk,
   input wire       mcb3_calib_done, // memory interface calibration done
   input wire       mcb3_error, // memory interface error
   output reg [7:0] seven_seg,
   output reg [2:0] seven_seg_en
   );

   // The 3 hex digits to display
   reg [11:0]       state;

   // Determine the current state based on input signals
   always @ (*) begin
      if (!mcb3_calib_done) begin
         state = `STATE_MEM_UNCALIB;
      end else if (mcb3_error) begin
         state = `STATE_MEM_ERROR;
      end else begin
         state = `STATE_DEFAULT;
      end
   end

   // Divide the clock so that we get a seg_clk that runs at
   // about 380Hz (if clk is 100MHz)
   reg [17:0] counter = 0;
   reg        seg_clk = 0;
   always @ (posedge clk) begin
      counter <= counter + 1;
      seg_clk <= &counter;
   end

   // Which digit are we currently displaying?
   reg [1:0] cur_digit = 0;

   always @ (posedge seg_clk) begin
      // Increment the digit
      if (cur_digit == 2) begin
         cur_digit <= 0;
      end else begin
         cur_digit <= cur_digit + 1;
      end
      // Display the current digit
      if (cur_digit == 2) begin
         seven_seg_en <= 3'b011;
         display_digit(state[11:8]);
      end else if (cur_digit == 1) begin
         seven_seg_en <= 3'b101;
         display_digit(state[7:4]);
      end else begin
         seven_seg_en <= 3'b110;
         display_digit(state[3:0]);
      end
   end

   // Display a 4-bit digit in hexadecimal
   task display_digit;
      input [3:0] d;
      begin
         case (d)
           0: seven_seg <= 8'b00000011;
           1: seven_seg <= 8'b10011111;
           2: seven_seg <= 8'b00100101;
           3: seven_seg <= 8'b00001101;
           4: seven_seg <= 8'b10011001;
           5: seven_seg <= 8'b01001001;
           6: seven_seg <= 8'b01000001;
           7: seven_seg <= 8'b00011111;
           8: seven_seg <= 8'b00000001;
           9: seven_seg <= 8'b00001001;
           10: seven_seg <= 8'b00010001; // A
           11: seven_seg <= 8'b11000001; // b
           12: seven_seg <= 8'b01100011; // C
           13: seven_seg <= 8'b10000101; // d
           14: seven_seg <= 8'b01100001; // E
           15: seven_seg <= 8'b01110001; // F
         endcase
      end
   endtask

endmodule
