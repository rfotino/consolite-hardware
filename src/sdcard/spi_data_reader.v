/**
 * Used by the SD card reader to receive data responses from the
 * SPI flash interface and store them in RAM.
 *
 * @author Robert Fotino, 2016
 */

`include "../definitions.vh"

module spi_data_reader
  (
   input             clk,
   input             calib_done,
   input             sclk_posedge,
   input             sclk_negedge,
   input [6:0]       block_addr,
   input             en,
   input             in,
   output reg        error,
   output            done,
   // Signals for writing to RAM
   output reg        mem_cmd_en,
   output [2:0]      mem_cmd_instr,
   output [5:0]      mem_cmd_bl,
   output reg [29:0] mem_cmd_byte_addr,
   input             mem_cmd_empty,
   input             mem_cmd_full,
   output reg        mem_wr_en,
   output [3:0]      mem_wr_mask,
   output reg [31:0] mem_wr_data,
   input             mem_wr_full,
   input             mem_wr_empty,
   input [6:0]       mem_wr_count,
   input             mem_wr_underrun,
   input             mem_wr_error
   );

   // Initialize outputs
   initial begin
      error = 0;
      mem_cmd_en = 0;
      mem_wr_en = 0;
   end

   // Our interface with RAM is write-only, so always give the
   // write command (000)
   assign mem_cmd_instr = 3'b000;
   // We always want to write 128-byte blocks to RAM, so always
   // use a burst length of 32 32-bit words
   assign mem_cmd_bl = 6'b011111;
   // We also always want to write 32-bit words, so don't mask
   // any bytes
   assign mem_wr_mask = 4'b0000;

   // Keep track of which bit we are on, so that we always
   // start at bit 7 for synchonous byte-oriented communication
   reg [2:0] bit_counter = 7;
   always @ (posedge clk) begin
      if (sclk_negedge) begin
         bit_counter <= bit_counter - 1;
      end
   end

   // Keep track of the current byte. Once 8 bits have been read in,
   // the valid flag goes high for one cycle
   reg [7:0] cur_byte = 8'hFF;
   reg       cur_byte_valid = 0;
   always @ (posedge clk) begin
      cur_byte_valid <= 0;
      if (sclk_posedge) begin
         cur_byte[bit_counter] <= in;
         if (0 == bit_counter) begin
            cur_byte_valid <= 1;
         end
      end
   end

   // State machine logic
   localparam STATE_IDLE  = 0;
   localparam STATE_TOKEN = 1;
   localparam STATE_BLOCK = 2;
   localparam STATE_CRC   = 3;
   localparam STATE_FLUSH = 4;
   localparam STATE_ERROR = 5;
   reg [2:0]                    state = STATE_IDLE;
   reg [8:0]                    byte_counter = 0;
   reg                          crc_counter = 0;
   reg [6:0]                    block_addr_reg = 0;
   assign done = (STATE_IDLE == state) && !en;
   always @ (posedge clk) begin
      // Default to disabled signals
      mem_cmd_en <= 0;
      mem_wr_en <= 0;
      case (state)
        // Wait here until we get the enabled signal
        STATE_IDLE: begin
           if (en) begin
              state <= STATE_TOKEN;
              byte_counter <= 0;
              crc_counter <= 0;
              block_addr_reg <= block_addr;
           end
        end
        // Wait until we see 0xFE to start the data, or an error token
        // (error tokens start with 0b000)
        STATE_TOKEN: begin
           if (cur_byte_valid) begin
              if (8'hFE == cur_byte) begin
                 state <= STATE_BLOCK;
              end else if (3'b000 == cur_byte[7:5]) begin
                 state <= STATE_ERROR;
              end
           end
        end
        // Consume the data block and store it in RAM
        STATE_BLOCK: begin
           if (cur_byte_valid) begin
              mem_wr_data <= { mem_wr_data[23:0], cur_byte };
              // Check if we have read a 4-byte chunk
              if (3 == byte_counter[1:0]) begin
                 mem_wr_en <= 1;
              end
              // Check if we have read 128 bytes and are ready to write
              // to RAM
              if (127 == byte_counter[6:0]) begin
                 mem_cmd_en <= 1;
                 mem_cmd_byte_addr <= { `MAIN_MEM_PREFIX, block_addr_reg,
                                        byte_counter[8:7], 7'b0 };
              end
              // Increment the byte counter, or move onto the next state if
              // we've read all 512 bytes
              if (511 == byte_counter) begin
                 state <= STATE_CRC;
              end else begin
                 byte_counter <= byte_counter + 1;
              end
           end
        end
        // Consume the 2-byte CRC, but don't do any verification
        STATE_CRC: begin
           if (cur_byte_valid) begin
              if (crc_counter) begin
                 state <= STATE_FLUSH;
              end
              crc_counter <= ~crc_counter;
           end
        end
        // Wait until the write FIFO is empty
        STATE_FLUSH: begin
           if (mem_wr_empty) begin
              state <= STATE_IDLE;
           end
        end
        // An error occurred - no recovery mechanism right now.
        STATE_ERROR: begin
           error <= 1;
        end
      endcase
      // If we have a memory write error or underrun, go to the error state
      if (calib_done && (mem_wr_error || mem_wr_underrun)) begin
         state <= STATE_ERROR;
      end
   end

endmodule
