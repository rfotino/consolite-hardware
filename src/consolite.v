module consolite
  (
   // 100MHz system clock
   input         clk,
   // 7-segment display outputs
   output [7:0]  seven_seg,
   output [2:0]  seven_seg_en,
   // VGA display outputs
   output        hsync,
   output        vsync,
   output [7:0]  rgb,
   // LPDDR RAM inputs and outputs
   inout [15:0]  mcb3_dram_dq,
   output [12:0] mcb3_dram_a,
   output [1:0]  mcb3_dram_ba,
   output        mcb3_dram_cke,
   output        mcb3_dram_ras_n,
   output        mcb3_dram_cas_n,
   output        mcb3_dram_we_n,
   output        mcb3_dram_dm,
   inout         mcb3_dram_udqs,
   inout         mcb3_rzq,
   output        mcb3_dram_udm,
   input         c3_sys_rst_n,
   inout         mcb3_dram_dqs,
   output        mcb3_dram_ck,
   output        mcb3_dram_ck_n,
   output        mcb3_calib_done,
   input         mcb3_error
   );

   // Main memory command signals
   reg           lpram_cmd_en = 0;
   reg [2:0]     lpram_cmd_instr = 0;
   reg [5:0]     lpram_cmd_bl = 0; // bl = burst length
   reg [29:0]    lpram_cmd_addr = 0;
   wire          lpram_cmd_empty;
   wire          lpram_cmd_full;

   // Main memory write signals
   reg           lpram_w_en = 0;
   reg [3:0]     lpram_w_mask = 0;
   reg [31:0]    lpram_w_data = 0;
   wire          lpram_w_full;
   wire          lpram_w_empty;
   wire [6:0]    lpram_w_count;
   wire          lpram_w_underrun;
   wire          lpram_w_error;

   // Main memory read signals
   reg           lpram_r_en = 0;
   wire [31:0]   lpram_r_data = 0;
   wire          lpram_r_full;
   wire          lpram_r_empty;
   wire [6:0]    lpram_r_count;
   wire          lpram_r_overflow;
   wire          lpram_r_error;

   // Determines the digits for the 7-segment display,
   // based on status/error conditions
   wire [11:0]    seg_digits;
   seg_status seg_status_
     (
      .mem_calib_done(mcb3_calib_done),
      .mem_error(mcb3_error),
      .seg_digits(seg_digits)
      );

   // The 7-segment display controller
   seg_display seg_display_
     (
      .clk(clk),
      .digits(seg_digits),
      .seven_seg(seven_seg),
      .seven_seg_en(seven_seg_en)
      );

   // The VGA display controller
   vga_display vga_display_
     (
      .clk(clk),
      .hsync(hsync),
      .vsync(vsync),
      .rgb(rgb)
      );

   // Create an instance of the LPDDR memory interface
   s6_lpddr_ram main_ram_
     (
      // Command signals
      .c3_p0_cmd_clk(clk),
      .c3_p0_cmd_en(lpram_cmd_en),
      .c3_p0_cmd_instr(lpram_cmd_instr),
      .c3_p0_cmd_bl(lpram_cmd_bl),
      .c3_p0_cmd_byte_addr(lpram_cmd_addr),
      .c3_p0_cmd_empty(lpram_cmd_empty),
      .c3_p0_cmd_full(lpram_cmd_full),

      // Write signals
      .c3_p0_wr_clk(clk),
      .c3_p0_wr_en(lpram_w_en),
      .c3_p0_wr_mask(lpram_w_mask),
      .c3_p0_wr_data(lpram_w_data),
      .c3_p0_wr_full(lpram_w_full),
      .c3_p0_wr_empty(lpram_w_empty),
      .c3_p0_wr_count(lpram_w_count),
      .c3_p0_wr_underrun(lpram_w_underrun),
      .c3_p0_wr_error(lpram_w_error),

      // Read signals
      .c3_p0_rd_clk(clk),
      .c3_p0_rd_en(lpram_r_en),
      .c3_p0_rd_data(lpram_r_data),
      .c3_p0_rd_full(lpram_r_full),
      .c3_p0_rd_empty(lpram_r_empty),
      .c3_p0_rd_count(lpram_r_count),
      .c3_p0_rd_overflow(lpram_r_overflow),
      .c3_p0_rd_error(lpram_r_error),

      // Memory interface signals
      .mcb3_dram_dq(mcb3_dram_dq),
      .mcb3_dram_a(mcb3_dram_a),
      .mcb3_dram_ba(mcb3_dram_ba),
      .mcb3_dram_cke(mcb3_dram_cke),
      .mcb3_dram_ras_n(mcb3_dram_ras_n),
      .mcb3_dram_cas_n(mcb3_dram_cas_n),
      .mcb3_dram_we_n(mcb3_dram_we_n),
      .mcb3_dram_dm(mcb3_dram_dm),
      .mcb3_dram_udqs(mcb3_dram_udqs),
      .mcb3_rzq(mcb3_rzq),
      .mcb3_dram_udm(mcb3_dram_udm),
      .c3_sys_clk(clk),
      .c3_sys_rst_n(c3_sys_rst_n),
      .c3_calib_done(mcb3_calib_done),
      .mcb3_dram_dqs(mcb3_dram_dqs),
      .mcb3_dram_ck(mcb3_dram_ck),
      .mcb3_dram_ck_n(mcb3_dram_ck_n)
      );

endmodule
