/**
 * A module for reading the first 64 Kib off of the micro SD card
 * using an SPI flash interface and writing it to RAM where it can
 * be executed.
 *
 * For more information, see:
 * http://elm-chan.org/docs/mmc/mmc_e.html
 * http://elm-chan.org/docs/spi_e.html
 * http://elm-chan.org/docs/mmc/gfx1/sdinit.png
 * http://www.dejazzer.com/ee379/lecture_notes/lec12_sd_card.pdf
 * https://learn.sparkfun.com/tutorials/serial-peripheral-interface-spi
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module sdcard_reader
  (
   input             clk,
   input             calib_done,
   input             disabled,
   input [7:0]       program_index,
   output reg        started,
   output reg        done,
   output reg [7:0]  progress,
   output reg        error,
   // Signals for communicating with SD card
   output reg        sdcard_cs,
   output reg        sdcard_sclk,
   output            sdcard_mosi,
   input             sdcard_miso,
   // Signals for writing to RAM
   output            mem_cmd_en,
   output [2:0]      mem_cmd_instr,
   output [5:0]      mem_cmd_bl,
   output     [29:0] mem_cmd_byte_addr,
   input             mem_cmd_empty,
   input             mem_cmd_full,
   output            mem_wr_en,
   output [3:0]      mem_wr_mask,
   output     [31:0] mem_wr_data,
   input             mem_wr_full,
   input             mem_wr_empty,
   input [6:0]       mem_wr_count,
   input             mem_wr_underrun,
   input             mem_wr_error
   );

   // Give outputs their initial values
   initial begin
      started = 0;
      done = 0;
      progress = 0;
      error = 0;
      sdcard_cs = 1;
      sdcard_sclk = 1;
   end

   // Divide the clock that we send to the SD card
   reg [8:0] sclk_counter = 0;
   reg [8:0] sclk_div = 250; // Default to 400 kHz
   reg       sclk_reset = 0;
   reg       sclk_posedge = 0;
   reg       sclk_negedge = 0;
   always @ (posedge clk) begin
      sclk_posedge <= 0;
      sclk_negedge <= 0;
      if (sclk_reset || sclk_div - 1 == sclk_counter) begin
         sclk_counter <= 0;
         if (sdcard_sclk) begin
            sclk_negedge <= 1;
         end
         sdcard_sclk <= 0;
      end else begin
         sclk_counter <= sclk_counter + 1;
         // At the halfway point, switch the serial clock to 1
         if ((sclk_div >> 1) - 1 == sclk_counter) begin
            sclk_posedge <= 1;
            sdcard_sclk <= 1;
         end
      end
   end

   // Count whether 1.5 milliseconds have passed before
   // establishing communication with the SD card
   localparam                          POWER_COUNTER_MAX = 150000;
   reg                                 power_on_done = 0;
   reg [$clog2(POWER_COUNTER_MAX)-1:0] power_on_counter = 0;
   always @ (posedge clk) begin
      if (power_on_counter == POWER_COUNTER_MAX - 1) begin
         power_on_done <= 1;
      end else begin
         power_on_counter <= power_on_counter + 1;
      end
   end

   // Controls for sending 6-byte SPI commands to SD card
   localparam          CMD_BITS = 48;
   reg                 spi_cmd_send_reset = 0;
   reg                 spi_cmd_send_en = 0;
   reg [5:0]           spi_cmd_send_index = 0;
   reg [31:0]          spi_cmd_send_arg = 0;
   reg [6:0]           spi_cmd_send_crc = 0;
   wire [CMD_BITS-1:0] spi_cmd_send_data = {
      2'b01, spi_cmd_send_index,
      spi_cmd_send_arg, spi_cmd_send_crc, 1'b1
   };
   wire                spi_cmd_send_done;
   spi_sender #(.DATA_BITS(CMD_BITS)) spi_cmd_sender_
     (
      .clk(clk),
      .sclk_posedge(sclk_posedge),
      .sclk_negedge(sclk_negedge),
      .reset(spi_cmd_send_reset),
      .en(spi_cmd_send_en),
      .data(spi_cmd_send_data),
      .out(sdcard_mosi),
      .done(spi_cmd_send_done)
      );

   // Controls for receiving 8-bit R1 responses from SD card
   localparam         R1_BITS = 8;
   reg                spi_r1_recv_reset = 0;
   reg                spi_r1_recv_en = 0;
   wire [R1_BITS-1:0] spi_r1_recv_out;
   wire               spi_r1_recv_done;
   spi_receiver #(.DATA_BITS(R1_BITS)) spi_r1_receiver_
     (
      .clk(clk),
      .sclk_posedge(sclk_posedge),
      .sclk_negedge(sclk_negedge),
      .reset(spi_r1_recv_reset),
      .en(spi_r1_recv_en),
      .in(sdcard_miso),
      .out(spi_r1_recv_out),
      .done(spi_r1_recv_done)
      );

   // Controls for receiving 40-bit R3/R7 responses from SD card
   // (R1 followed by 32 bits of data)
   localparam            R3_R7_BITS = 40;
   reg                   spi_r3_r7_recv_reset = 0;
   reg                   spi_r3_r7_recv_en = 0;
   wire [R3_R7_BITS-1:0] spi_r3_r7_recv_out;
   wire                  spi_r3_r7_recv_done;
   spi_receiver #(.DATA_BITS(R3_R7_BITS)) spi_r3_r7_receiver_
     (
      .clk(clk),
      .sclk_posedge(sclk_posedge),
      .sclk_negedge(sclk_negedge),
      .reset(spi_r3_r7_recv_reset),
      .en(spi_r3_r7_recv_en),
      .in(sdcard_miso),
      .out(spi_r3_r7_recv_out),
      .done(spi_r3_r7_recv_done)
      );

   // Module for receiving data blocks and storing them in RAM
   reg [6:0]             block_addr = 0;
   reg                   spi_data_read_en = 0;
   wire                  spi_data_read_error;
   wire                  spi_data_read_done;
   spi_data_reader spi_data_reader_
     (
      .clk(clk),
      .calib_done(calib_done),
      .sclk_posedge(sclk_posedge),
      .sclk_negedge(sclk_negedge),
      .block_addr(block_addr),
      .en(spi_data_read_en),
      .in(sdcard_miso),
      .error(spi_data_read_error),
      .done(spi_data_read_done),
      .mem_cmd_en(mem_cmd_en),
      .mem_cmd_instr(mem_cmd_instr),
      .mem_cmd_bl(mem_cmd_bl),
      .mem_cmd_byte_addr(mem_cmd_byte_addr),
      .mem_cmd_empty(mem_cmd_empty),
      .mem_cmd_full(mem_cmd_full),
      .mem_wr_en(mem_wr_en),
      .mem_wr_mask(mem_wr_mask),
      .mem_wr_data(mem_wr_data),
      .mem_wr_full(mem_wr_full),
      .mem_wr_empty(mem_wr_empty),
      .mem_wr_count(mem_wr_count),
      .mem_wr_underrun(mem_wr_underrun),
      .mem_wr_error(mem_wr_error)
      );

   // State machine logic for communicating with the SD card
   localparam STATE_POWER_ON    = 0;
   localparam STATE_DUMMY_CLK   = 1;
   localparam STATE_0xFF_WAIT   = 2;
   localparam STATE_R1_SEND     = 3;
   localparam STATE_R3_R7_SEND  = 4;
   localparam STATE_CMD0_SEND   = 5;
   localparam STATE_CMD0_RECV   = 6;
   localparam STATE_CMD8_SEND   = 7;
   localparam STATE_CMD8_RECV   = 8;
   localparam STATE_CMD55_SEND  = 9;
   localparam STATE_CMD55_RECV  = 10;
   localparam STATE_ACMD41_SEND = 11;
   localparam STATE_ACMD41_RECV = 12;
   localparam STATE_CMD58_SEND  = 13;
   localparam STATE_CMD58_RECV  = 14;
   localparam STATE_CALIB_WAIT  = 15;
   localparam STATE_CMD17_SEND  = 16;
   localparam STATE_CMD17_RECV  = 17;
   localparam STATE_DATA_RECV   = 18;
   localparam STATE_DONE        = 254;
   localparam STATE_ERROR       = 255;
   reg [7:0] state = STATE_POWER_ON;
   reg [7:0] next_state;
   reg [7:0] dummy_clk_counter = 0;
   reg [7:0] miso_ready_counter = 0;
   always @ (posedge clk) begin
      sclk_reset <= 0;
      spi_cmd_send_en <= 0;
      spi_cmd_send_reset <= 0;
      spi_r1_recv_en <= 0;
      spi_r1_recv_reset <= 0;
      spi_r3_r7_recv_en <= 0;
      spi_r3_r7_recv_reset <= 0;
      spi_data_read_en <= 0;
      case (state)
         // Wait >= 1 millisecond, then send dummy clock
         STATE_POWER_ON: begin
            sclk_reset <= 1;
            sdcard_cs <= 1;
            if (power_on_done) begin
               state <= STATE_DUMMY_CLK;
            end
         end
         // Send >= 74 pulses with clock between 100kHz and 400kHz. The card
         // is ready to receive a command when it drives the MISO signal high
         STATE_DUMMY_CLK: begin
            sdcard_cs <= 1;
            if (sdcard_miso && sclk_negedge && 74 <= dummy_clk_counter) begin
               state <= STATE_CMD0_SEND;
            end else if (sclk_posedge) begin
               dummy_clk_counter <= dummy_clk_counter + 1;
            end
         end
         // Wait until we have seen 0xFF from the card's MISO
         STATE_0xFF_WAIT: begin
            if (sclk_posedge) begin
               if (sdcard_miso) begin
                  if (7 == miso_ready_counter) begin
                     miso_ready_counter <= 0;
                     state <= next_state;
                  end else begin
                     miso_ready_counter <= miso_ready_counter + 1;
                  end
               end else begin
                  miso_ready_counter <= 0;
               end
            end
         end
         // Wait for a command with R1 response to be sent
         STATE_R1_SEND: begin
            if (spi_cmd_send_done) begin
               spi_r1_recv_en <= 1;
               state <= next_state;
            end
         end
         // Wait for a command with R3/R7 response to be sent
         STATE_R3_R7_SEND: begin
            if (spi_cmd_send_done) begin
               spi_r3_r7_recv_en <= 1;
               state <= next_state;
            end
         end
         // Set up the sender module to send CMD0
         STATE_CMD0_SEND: begin
            // Change to 10 MHz clock
            sclk_div <= 10;
            // If CS is low for CMD0 we go into SPI mode
            sdcard_cs <= 0;
            // Setup command packet
            spi_cmd_send_index <= 6'd0;
            spi_cmd_send_arg <= 32'h00000000;
            spi_cmd_send_crc <= 7'b1001010; // hardcoded CRC for CMD0
            // Enable sending of command
            spi_cmd_send_en <= 1;
            state <= STATE_R1_SEND;
            next_state <= STATE_CMD0_RECV;
         end
         // Wait for response from CMD0, then verify
         STATE_CMD0_RECV: begin
            if (spi_r1_recv_done && !disabled) begin
               started <= 1;
               // Check that the response is valid
               if (8'b1 == spi_r1_recv_out) begin
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_CMD8_SEND;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Set up sender module to send CMD8
         STATE_CMD8_SEND: begin
            // Setup command packet
            spi_cmd_send_index <= 6'd8;
            spi_cmd_send_arg <= 32'h000001AA;
            spi_cmd_send_crc <= 7'b1000011; // hardcoded CRC for CMD8
            // Enable sending of command
            spi_cmd_send_en <= 1;
            state <= STATE_R3_R7_SEND;
            next_state <= STATE_CMD8_RECV;
         end
         // Wait for response from CMD8, then verify that we
         // are in the idle state with the voltage echoed back
         // correctly
         STATE_CMD8_RECV: begin
            if (spi_r3_r7_recv_done) begin
               if (40'h01000001AA == spi_r3_r7_recv_out) begin
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_CMD55_SEND;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Set up sender module to send CMD55
         STATE_CMD55_SEND: begin
            spi_cmd_send_index <= 6'd55;
            spi_cmd_send_arg <= 32'h00000000;
            spi_cmd_send_crc <= 7'b0000000; // Shouldn't be checked
            spi_cmd_send_en <= 1;
            state <= STATE_R1_SEND;
            next_state <= STATE_CMD55_RECV;
         end
         // Wait for response from CMD55 and check for errors
         STATE_CMD55_RECV: begin
            if (spi_r1_recv_done) begin
               if (8'b1 == spi_r1_recv_out) begin
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_ACMD41_SEND;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Set up sender module to send ACMD41
         STATE_ACMD41_SEND: begin
            spi_cmd_send_index <= 6'd41;
            spi_cmd_send_arg <= 32'h40000000;
            spi_cmd_send_crc <= 7'b0000000; // Shouldn't be checked
            spi_cmd_send_en <= 1;
            state <= STATE_R1_SEND;
            next_state <= STATE_ACMD41_RECV;
         end
         // Wait for response from ACMD41, check for errors, and start
         // back at CMD55 if still in idle state
         STATE_ACMD41_RECV: begin
            if (spi_r1_recv_done) begin
               if (8'b1 == spi_r1_recv_out) begin
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_CMD55_SEND;
               end else if (8'b0 == spi_r1_recv_out) begin
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_CMD58_SEND;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Set up sender module to send CMD58
         STATE_CMD58_SEND: begin
            spi_cmd_send_index <= 6'd58;
            spi_cmd_send_arg <= 32'h00000000;
            spi_cmd_send_crc <= 7'b0000000; // Shouldn't be checked
            spi_cmd_send_en <= 1;
            state <= STATE_R3_R7_SEND;
            next_state <= STATE_CMD58_RECV;
         end
         // Wait for response from CMD58, check for errors, and then
         // check if the CCS (Card Capacity Status) flag is set. This
         // indicates 512-byte block level addressing
         STATE_CMD58_RECV: begin
            if (spi_r3_r7_recv_done) begin
               if (8'b0 == spi_r3_r7_recv_out[39:32] &&
                   spi_r3_r7_recv_out[30]) begin
                  state <= STATE_CALIB_WAIT;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Wait for memory calibration to be done, then start
         // reading from SD card and storing in RAM
         STATE_CALIB_WAIT: begin
            if (calib_done) begin
               state <= STATE_0xFF_WAIT;
               next_state <= STATE_CMD17_SEND;
            end
         end
         // Send CMD17, single block read
         STATE_CMD17_SEND: begin
            spi_cmd_send_index <= 6'd17;
            spi_cmd_send_arg <= { 17'b0, program_index, block_addr }; // Block address
            spi_cmd_send_crc <= 7'b0000000; // Shouldn't be checked
            spi_cmd_send_en <= 1;
            state <= STATE_R1_SEND;
            next_state <= STATE_CMD17_RECV;
         end
         // Wait for response from CMD17, check for errors, then move
         // to handle the incoming data packet
         STATE_CMD17_RECV: begin
            if (spi_r1_recv_done) begin
               if (8'b0 == spi_r1_recv_out) begin
                  spi_data_read_en <= 1;
                  state <= STATE_DATA_RECV;
               end else begin
                  state <= STATE_ERROR;
               end
            end
         end
         // Handle receiving an incoming data packet, and send to RAM
         STATE_DATA_RECV: begin
            if (spi_data_read_error) begin
               state <= STATE_ERROR;
            end else if (spi_data_read_done) begin
               progress <= progress + 2;
               if (127 == block_addr) begin
                  state <= STATE_DONE;
               end else begin
                  block_addr <= block_addr + 1;
                  state <= STATE_0xFF_WAIT;
                  next_state <= STATE_CMD17_SEND;
               end
            end
         end
         // Done reading from the card
         STATE_DONE: begin
            sclk_reset <= 1;
            sdcard_cs <= 1;
            done <= 1;
         end
         // There was an error reading from the SD card
         STATE_ERROR: begin
            sclk_reset <= 1;
            sdcard_cs <= 1;
            error <= 1;
         end
      endcase
   end

endmodule
