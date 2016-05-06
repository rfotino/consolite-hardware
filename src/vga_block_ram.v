/**
 * Instantiates a 9Kib block RAM for the VGA buffer, and
 * exposes an interface to write 32-bit blocks to 64
 * addresses and read 8-bit blocks from 256 addresses.
 * We are only using 2Kib of memory, but the physical
 * hardware in the Spartan 6 only has two of these 9Kib
 * block RAM banks.
 *
 * @author Robert Fotino, 2016
 */
module vga_block_ram
  (
   input        wr_clk,
   input        wr_en,
   input [5:0]  wr_addr,
   input [31:0] wr_data,
   input        rd_clk,
   input [7:0]  rd_addr,
   output [7:0] rd_data
   );

   // Data out for the underlying block RAM. Output
   // is 32 bits, but we want to have byte-level indexing
   wire [31:0]  DO;
   assign rd_data = DO[{rd_addr[1:0], 3'b0}+:8];

   // Instantiate a 9Kib simple dual-port block RAM
   BRAM_SDP_MACRO
     #(
       .BRAM_SIZE("9Kb"),
       .DEVICE("SPARTAN6"),
       .WRITE_WIDTH(32),
       .READ_WIDTH(32),
       .DO_REG(0),
       .INIT_FILE("NONE"),
       .SRVAL(72'b0),
       .INIT(72'b0)
       )
   BRAM_SDP_MACRO_inst
     (
      .DO(DO),
      .DI(wr_data),
      .RDADDR({ 2'b0, rd_addr[7:2] }),
      .RDCLK(rd_clk),
      .RDEN(1'b1),
      .REGCE(REGCE),
      .RST(1'b0),
      .WE(4'b1111),
      .WRADDR({ 2'b0, wr_addr }),
      .WRCLK(wr_clk),
      .WREN(wr_en)
      );

endmodule
