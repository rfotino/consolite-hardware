`include "definitions.vh"

module uart_loader
  (
   input             clk,
   input             calib_done,
   input             disabled,
   output reg        started,
   output reg        done,
   output [7:0]      progress,
   input             rx,
   output reg        mem_cmd_en,
   output     [2:0]  mem_cmd_instr,
   output     [5:0]  mem_cmd_bl,
   output reg [29:0] mem_cmd_byte_addr,
   input             mem_cmd_empty,
   input             mem_cmd_full,
   output reg        mem_wr_en,
   output     [3:0]  mem_wr_mask,
   output reg [31:0] mem_wr_data,
   input             mem_wr_full,
   input             mem_wr_empty,
   input [6:0]       mem_wr_count,
   input             mem_wr_underrun,
   input             mem_wr_error
   );

   // Our interface with RAM is write-only, so always give the
   // write command (000)
   assign mem_cmd_instr = 3'b000;
   // We always want to write 256-byte blocks to RAM, so always
   // use a burst length of 64 32-bit chunks
   assign mem_cmd_bl = 6'b111111;
   // We also always want to write 32-bit chunks, so don't mask
   // any bytes
   assign mem_wr_mask = 4'b0000;

   // Initialize registers
   initial begin
      started = 0;
      done = 0;
      mem_cmd_en = 0;
      mem_wr_en = 0;
   end

   // A reader for individual bytes of data off of the serial
   // interface. Use a higher baud rate so we get better throughput.
   // Data transfer takes ((2^19)/BAUD) = 4.55 seconds at 115200 baud
   wire       busy;
   wire [7:0] uart_data;
   uart uart_
     (
      .clk(clk),
      .rst(1'b0),
      .rx(rx),
      .busy(busy),
      .data(uart_data)
      );

   // State machine logic to load data
   reg [2:0] state = 0;
   reg [7:0] cur_line = 0;
   reg [7:0] cur_byte = 0;
   reg busy_prev = 0;
   assign progress = cur_line;
   always @ (posedge clk) begin
      busy_prev <= busy;
      mem_cmd_en <= 0;
      mem_wr_en <= 0;
      case (state)
         // Wait for calibration to complete
         0: begin
            if (calib_done) begin
               state <= 1;
            end
         end
         // Receive 256 bytes, load them into the RAM fifo
         1: begin
            // If we just received a byte
            if (!busy && busy_prev && !disabled) begin
               started <= 1;
               cur_byte <= cur_byte + 1;
               mem_wr_data <= { mem_wr_data[23:0], uart_data };
               // If we just filled up a word, send it
               // to the write fifo
               if (2'b11 == cur_byte[1:0]) begin
                  mem_wr_en <= 1;
               end
               // If we just filled up a row, send a write command
               if (255 == cur_byte) begin
                  state <= 2;
               end
            end
         end
         // Send a write command for the line
         2: begin
            if (mem_cmd_en) begin
               if (255 == cur_line) begin
                  state <= 3;
               end else begin
                  cur_line <= cur_line + 1;
                  state <= 1;
               end
            end else begin
               mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, cur_line, 8'b0 };
               mem_cmd_en <= 1;
            end
         end
         // Send the done signal and do nothing
         3: begin
            done <= 1;
         end
      endcase
   end

endmodule
