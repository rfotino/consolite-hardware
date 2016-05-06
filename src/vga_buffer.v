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

`define MEM_WAIT_TIMEOUT 100

module vga_buffer
  (
   input         clk,      // 65 MHz pixel clock
   input         clk_fast, // 100 MHz master clock
   input         calib_done,
   input [7:0]   x_coord,
   input [7:0]   y_coord,
   input         invalidate,
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

   // The mem command is always 001 (read)
   assign mem_cmd_instr = 3'b001;
   // Similarly the burst length is always 64
   assign mem_cmd_bl = 6'b111111;
   // The address we request data from is the start of the next line
   wire [7:0] y_coord_next = y_coord == `SCREEN_HEIGHT - 1 ? 8'b0 : y_coord + 1;
   assign mem_cmd_byte_addr = { `GRAPHICS_MEM_PREFIX, y_coord_next, 8'b0 };
   // We use a state machine to refill the buffer. Need to keep track
   // of how many words have been read so we know when to stop reading
   reg [1:0]   mem_state = `MEM_STATE_IDLE;
   reg [5:0]   mem_words_read = 0;

   // The buffer of data itself, stored in a block RAM
   reg         write_en = 0;
   reg [5:0]   write_addr = 0;
   reg [31:0]  write_data = 0;
   vga_block_ram vga_block_ram_
     (
      .wr_clk(clk),
      .rd_clk(clk_fast),
      // Write signals
      .wr_en(write_en),
      .wr_addr(write_addr),
      .wr_data(write_data),
      // Read signals
      .rd_addr(x_coord),
      .rd_data(rgb)
      );

   // Buffer refill logic
   reg [7:0] invalid_index = 0;
   reg [6:0] mem_wait_timer = 0;
   always @ (posedge clk) begin
      write_en <= 0;
      mem_rd_en <= 0;
      if (calib_done) begin
         // State machine to handle memory accesses
         case (mem_state)
           // In the idle state, don't do anything until the invalidate
           // signal goes high - then we enter the command state and
           // reset the invalid index
           `MEM_STATE_IDLE: begin
              if (invalidate && x_coord == 0) begin
                 invalid_index <= 0;
                 mem_state <= `MEM_STATE_CMD;
              end
           end
           // Request a read transaction from main memory, then switch
           // to the wait state and wait for it to return data
           `MEM_STATE_CMD: begin
              mem_cmd_en <= ~mem_cmd_en;
              if (mem_cmd_en) begin
                 mem_state <= `MEM_STATE_WAIT;
                 mem_wait_timer <= 0;
              end
           end
           // If there is data available to read and the buffer is missing
           // at least 4 bytes (which is the amount of data we read at a time)
           // then switch to the read state. We may get stuck in this state,
           // so if we timeout just abandon the read and switch back to idling
           `MEM_STATE_WAIT: begin
              // The invalid index is the highest x coordinate that is
              // currently invalid and can be replaced with fresh data
              if (invalid_index < x_coord) begin
                 invalid_index <= x_coord;
              end
              // Once the line we are going to replace has been completely
              // displayed, we can start replacing it with bytes read from
              // main memory
              if (invalid_index == 255) begin
                 if (!mem_rd_empty) begin
                    mem_rd_en <= 1;
                    mem_state <= `MEM_STATE_READ;
                 end else if (`MEM_WAIT_TIMEOUT <= mem_wait_timer) begin
                    mem_words_read <= 0;
                    mem_state <= `MEM_STATE_IDLE;
                 end else begin
                    mem_wait_timer <= mem_wait_timer + 1;
                 end
              end
           end
           // Put the data into the buffer and mark it as valid. If we have
           // read all words, go back to the idle state. If we empty the FIFO
           // or fill up the buffer too fast, go back to the wait state
           `MEM_STATE_READ: begin
              write_en <= 1;
              write_addr <= mem_words_read;
              write_data <= mem_rd_data;
              mem_words_read <= mem_words_read + 1;
              if (mem_words_read == mem_cmd_bl) begin
                 mem_state <= `MEM_STATE_IDLE;
              end else if (mem_rd_empty) begin
                 mem_state <= `MEM_STATE_WAIT;
                 mem_wait_timer <= 0;
              end else begin
                 mem_rd_en <= 1;
              end
           end
         endcase
      end
   end

endmodule
