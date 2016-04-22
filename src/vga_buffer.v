/**
 * A 256-byte VGA buffer (enough for storing one line of
 * pixel data for the 256x192 screen). You give it the (x, y)
 * coordinate you want the color of and it returns the 8-bit
 * color. If the invalidate input is high, the buffer invalidates
 * the byte after returning it. If reset is high, the buffer
 * clears and sets its first byte to the top left of the screen.
 * This can be used for recovering from an error.
 *
 * This buffer uses a circular buffer architecture. Due to the
 * way the VGA controller requests bytes to display, it will
 * always invalidate bytes at the beginning of the line first,
 * where the valid pointer points. This is because it will be done
 * displaying these first as it moves left to right across the
 * screen.
 *
 * If the buffer has no valid bytes, the empty signal goes high,
 * which may indicate a flaw in either the design of this module
 * or the design of the containing module's memory accesses. It
 * The containing module may be crowding out the VGA buffer, which
 * has the strictest timing requirements.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

`define MEM_STATE_IDLE 0
`define MEM_STATE_CMD  1
`define MEM_STATE_WAIT 2
`define MEM_STATE_READ 3

module vga_buffer
  (
   input         clk,
   input         calib_done,
   input [7:0]   x_coord,
   input [7:0]   y_coord,
   input         invalidate,
   output        empty,
   output [7:0]  rgb,
   // Main memory control signals
   output reg    mem_cmd_en,
   output [2:0]  mem_cmd_instr,
   output [5:0]  mem_cmd_bl,
   output [29:0] mem_cmd_byte_addr,
   input         mem_cmd_empty,
   input         mem_cmd_full,
   output reg    mem_rd_en,
   input [31:0]  mem_rd_data,
   input         mem_rd_full,
   input         mem_rd_empty,
   input [6:0]   mem_rd_count,
   input         mem_rd_overflow,
   input         mem_rd_error
   );

   initial begin
      mem_cmd_en = 0;
      mem_rd_en = 0;
   end

   // The address of the first valid byte. Bytes are indexed by
   // their last 8 bits in the buffer
   reg [15:0]  first_valid_byte = 0;
   // The number of valid bytes in the buffer
   reg [8:0]   valid_len = 256;

   // If the valid length is zero, the buffer is empty
   assign empty = (valid_len == 0);

   // The mem command is always 001 (read)
   assign mem_cmd_instr = 3'b001;
   // Similarly the burst length is always 64
   assign mem_cmd_bl = 6'b111111;
   // We always want to read from the end of the last valid byte
   wire [15:0] valid_plus_len = first_valid_byte + valid_len;
   wire [15:0] first_uncached_byte = {
      valid_plus_len[15:8] < 191 ? valid_plus_len[15:8] : 8'b0,
      valid_plus_len[7:0]
   };
   assign mem_cmd_byte_addr = { `GRAPHICS_MEM_PREFIX, first_uncached_byte };
   // We use a state machine to refill the buffer. Need to keep track
   // of how many words have been read so we know when to stop reading
   reg [1:0]   mem_state = `MEM_STATE_IDLE;
   reg [5:0]   mem_words_read = 0;

   // The buffer of data itself, stored in a block RAM
   reg         write_en = 0;
   vga_block_ram vga_block_ram_
     (
      .clk(clk),
      // Write signals
      .wr_en(write_en),
      .wr_addr(first_uncached_byte[7:2]),
      .wr_data(mem_rd_data),
      // Read signals
      .rd_addr(x_coord),
      .rd_data(rgb)
      );

   // Return the requested data, possibly invalidating the first valid
   // byte as we go. If the number of bytes in the buffer falls below
   // a certain size, request more from main memory.
   reg         incr_valid_len = 0;
   reg         decr_valid_len = 0;
   always @ (posedge clk) begin
      if (calib_done) begin
         // Invalidate the first valid byte if requested
         if (invalidate && !empty) begin
            if (first_valid_byte == (`SCREEN_WIDTH * `SCREEN_HEIGHT) - 1) begin
               first_valid_byte <= 0;
            end else begin
               first_valid_byte <= first_valid_byte + 1;
            end
         end
         // Refill logic
         write_en <= 0;
         mem_rd_en <= 0;
         case (mem_state)
           // In the idle state, don't do anything until the buffer
           // starts to drain - then switch to command state
           `MEM_STATE_IDLE: begin
              if (valid_len != `VGA_BUF_SIZE) begin
                 mem_state <= `MEM_STATE_CMD;
              end
           end
           // Request a read transaction from main memory, then switch
           // to the wait state and wait for it to return data
           `MEM_STATE_CMD: begin
              mem_cmd_en <= ~mem_cmd_en;
              if (mem_cmd_en) begin
                 mem_state <= `MEM_STATE_WAIT;
              end
           end
           // If there is data available to read and the buffer is missing
           // at least 4 bytes (which is the amount of data we read at a time)
           // then switch to the read state
           `MEM_STATE_WAIT: begin
              if (valid_len <= `VGA_BUF_SIZE - 4 && !mem_rd_empty) begin
                 mem_rd_en <= 1;
                 mem_state <= `MEM_STATE_READ;
              end
           end
           // Put the data into the buffer and mark it as valid. If we have
           // read all words, go back to the idle state. If we empty the FIFO
           // or fill up the buffer too fast, go back to the wait state
           `MEM_STATE_READ: begin
              write_en <= 1;
              mem_words_read <= mem_words_read + 1;
              if (mem_words_read == mem_cmd_bl) begin
                 mem_state <= `MEM_STATE_IDLE;
              end else if (`VGA_BUF_SIZE - 4 < valid_len || mem_rd_empty) begin
                 mem_state <= `MEM_STATE_WAIT;
              end else begin
                 mem_rd_en <= 1;
              end
           end
         endcase
         // Handle the case of incrementing and decrementing the valid_len at
         // the same time, or just one or the other. We increment by 4 because
         // we fetch 32 bits (4 bytes) from memory at a time, and decrement by
         // 1 because we only invalidate 1 byte at a time
         incr_valid_len = (`MEM_STATE_READ == mem_state);
         decr_valid_len = (invalidate && !empty);
         if (incr_valid_len) begin
            if (decr_valid_len) begin
               valid_len <= valid_len + 3;
            end else begin
               valid_len <= valid_len + 4;
            end
         end else if (decr_valid_len) begin
            valid_len <= valid_len - 1;
         end
      end
   end

endmodule
