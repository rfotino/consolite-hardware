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
   // User inputs
   input [5:0]   buttons,
   input [7:0]   switches,
   input [7:0]   gpio_p6,
   input [7:0]   gpio_p7,
   input [7:0]   gpio_p8,
   input [7:0]   gpio_p9,
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

   // Main memory port 2 (read) for VGA buffer
   wire        c3_p2_cmd_clk;
   wire        c3_p2_cmd_en;
   wire [2:0]  c3_p2_cmd_instr;
   wire [5:0]  c3_p2_cmd_bl; // bl = burst length
   wire [29:0] c3_p2_cmd_byte_addr;
   wire        c3_p2_cmd_empty;
   wire        c3_p2_cmd_full;
   wire        c3_p2_rd_clk;
   wire        c3_p2_rd_en;
   wire [31:0] c3_p2_rd_data;
   wire        c3_p2_rd_full;
   wire        c3_p2_rd_empty;
   wire [6:0]  c3_p2_rd_count;
   wire        c3_p2_rd_overflow;
   wire        c3_p2_rd_error;

   // Buffers the input for INPUT instructions
   wire [45:0] buf_inputs;
   input_handler input_handler_
     (
      .buttons(buttons),
      .switches(switches),
      .gpio_p6(gpio_p6),
      .gpio_p7(gpio_p7),
      .gpio_p8(gpio_p8),
      .gpio_p9(gpio_p9),
      .buf_inputs(buf_inputs)
      );

   // Determines the digits for the 7-segment display,
   // based on status/error conditions
   wire [11:0]    seg_digits;
   seg_status seg_status_
     (
      .mem_calib_done(mcb3_calib_done),
      .mem_error(mcb3_error),
      .vga_buf_empty(vga_buf_empty),
      .buf_inputs(buf_inputs),
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
      .clk(clk & mcb3_calib_done),
      .hsync(hsync),
      .vsync(vsync),
      .rgb(rgb),
      .buf_empty(vga_buf_empty),
      .mem_cmd_en(c3_p2_cmd_en),
      .mem_cmd_instr(c3_p2_cmd_instr),
      .mem_cmd_bl(c3_p2_cmd_bl),
      .mem_cmd_byte_addr(c3_p2_cmd_byte_addr),
      .mem_cmd_empty(c3_p2_cmd_empty),
      .mem_cmd_full(c3_p2_cmd_full),
      .mem_rd_en(c3_p2_rd_en),
      .mem_rd_data(c3_p2_rd_data),
      .mem_rd_full(c3_p2_rd_full),
      .mem_rd_empty(c3_p2_rd_empty),
      .mem_rd_count(c3_p2_rd_count),
      .mem_rd_overflow(c3_p2_rd_overflow),
      .mem_rd_error(c3_p2_rd_error)
      );

   // Create an instance of the LPDDR memory interface
   s6_lpddr_ram main_ram_
     (
      // Main memory port 2 (VGA buffer, read only)
      .c3_p2_cmd_clk(clk),
      .c3_p2_cmd_en(c3_p2_cmd_en),
      .c3_p2_cmd_instr(c3_p2_cmd_instr),
      .c3_p2_cmd_bl(c3_p2_cmd_bl),
      .c3_p2_cmd_byte_addr(c3_p2_cmd_byte_addr),
      .c3_p2_cmd_empty(c3_p2_cmd_empty),
      .c3_p2_cmd_full(c3_p2_cmd_full),
      .c3_p2_rd_clk(clk),
      .c3_p2_rd_en(c3_p2_rd_en),
      .c3_p2_rd_data(c3_p2_rd_data),
      .c3_p2_rd_full(c3_p2_rd_full),
      .c3_p2_rd_empty(c3_p2_rd_empty),
      .c3_p2_rd_count(c3_p2_rd_count),
      .c3_p2_rd_overflow(c3_p2_rd_overflow),
      .c3_p2_rd_error(c3_p2_rd_error),

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
