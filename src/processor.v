/**
 * The central processing unit for Consolite that actually does
 * the executing of instructions.
 *
 * @author Robert Fotino, 2016
 */

`include "definitions.vh"

module processor
  (
   input                        clk,
   input                        boot_done,
   output reg [11:0]            status_digits,
   output reg                   halted,
   // Instruction cache
   output reg [`ADDR_BITS-1:0]  instr_ptr,
   input                        instr_valid,
   input [`INSTR_BITS-1:0]      cur_instr,
   // Data cache
   output reg                   cache_wr_en,
   output reg [`ADDR_BITS-1:0]  cache_wr_addr,
   output reg [`WORD_BITS-1:0]  cache_wr_data,
   input                        cache_wr_done,
   output reg                   cache_rd_en,
   output reg [`ADDR_BITS-1:0]  cache_rd_addr,
   input [`WORD_BITS-1:0]       cache_rd_data,
   input                        cache_rd_done,
   // Pixel writer
   input                        pixel_wr_done,
   output reg                   pixel_en,
   output reg [7:0]             pixel_rgb,
   output reg [7:0]             pixel_x,
   output reg [7:0]             pixel_y,
   // Random data
   input [`WORD_BITS-1:0]       rnd,
   // Millisecond timer
   output reg                   ms_time_rst,
   input [`WORD_BITS-1:0]       ms_time,
   // User input
   input [`NUM_USER_INPUTS-1:0] buf_inputs
   );

   // Initialize the color register and instruction pointer,
   // as well as setting all enable signals to low
   initial begin
      status_digits = 0;
      halted = 0;
      instr_ptr = 0;
      cache_wr_en = 0;
      cache_wr_addr = 0;
      cache_wr_data = 0;
      cache_rd_en = 0;
      cache_rd_addr = 0;
      pixel_en = 0;
      pixel_rgb = 0;
      pixel_x = 0;
      pixel_y = 0;
      ms_time_rst = 0;
   end

   // The general purpose register file. We use pixel_rgb as the
   // color register
   reg [`WORD_BITS-1:0]  registers [`NUM_REGS-1:0];
   // Flags for conditional instructions
   reg                   overflow_flag = 0;
   reg                   carry_flag = 0;
   reg                   zero_flag = 0;
   reg                   sign_flag = 0;
   // Values common to many instructions, extracted from the current
   // instruction or the register file
   wire [7:0]            opcode = cur_instr[31:24];
   wire [7:0]            arg1 = cur_instr[23:16];
   wire [7:0]            arg2 = cur_instr[15:8];
   wire [3:0]            reg1 = arg1[3:0];
   wire [3:0]            reg2 = arg2[3:0];
   wire [`WORD_BITS-1:0] dest = registers[reg1];
   wire [`WORD_BITS-1:0] src  = registers[reg2];
   wire [15:0]           argA = cur_instr[23:8];
   wire [15:0]           argB = cur_instr[15:0];
   // Used for arithmetic right shift so that sign extension works
   wire signed [`WORD_BITS-1:0] signed_dest = dest;
   // Register for saving the register index that we are going to load data
   // into while we are waiting to hear back from the data cache
   reg [3:0]             load_reg;

   // A multi-cycle multiplier module for MUL instructions
   reg                       multiply_en = 0;
   reg [`WORD_BITS-1:0]      multiply_data_a;
   reg [`WORD_BITS-1:0]      multiply_data_b;
   wire [(`WORD_BITS*2)-1:0] multiply_result;
   wire                      multiply_done;
   multiplier #(.BITS(`WORD_BITS)) multiplier_
     (
      .clk(clk),
      .en(multiply_en),
      .data_a(multiply_data_a),
      .data_b(multiply_data_b),
      .result(multiply_result),
      .done(multiply_done)
      );

   // A multi-cycle divider module for the expensive DIV instruction
   reg                   divide_en = 0;
   reg [`WORD_BITS-1:0]  dividend;
   reg [`WORD_BITS-1:0]  divisor;
   wire [`WORD_BITS-1:0] quotient;
   wire [`WORD_BITS-1:0] remainder;
   wire                  divide_done;
   divider #(.BITS(`WORD_BITS)) divider_
     (
      .clk(clk),
      .en(divide_en),
      .dividend(dividend),
      .divisor(divisor),
      .quotient(quotient),
      .remainder(remainder),
      .done(divide_done)
      );

   // Registers for keeping track of cycles per instruction
   localparam CPI_BITS = 18;
   reg [CPI_BITS-1:0] cpi_instr_counter = 0;
   reg [12+CPI_BITS-1:0] cpi_cycle_counter = 0;
   reg [12+CPI_BITS-1:0] cpi_cycle_counter_inc = 0;

   // The state machine for executing instructions
   localparam [3:0] STATE_PRE_BOOT   = 0;
   localparam [3:0] STATE_HALT       = 1;
   localparam [3:0] STATE_EXECUTING  = 2;
   localparam [3:0] STATE_WR_WAIT    = 3;
   localparam [3:0] STATE_PIXEL_WAIT = 4;
   localparam [3:0] STATE_RD_WAIT    = 5;
   localparam [3:0] STATE_RET_WAIT   = 6;
   localparam [3:0] STATE_MULTIPLY   = 7;
   localparam [3:0] STATE_DIVIDE     = 8;
   reg [3:0]            state = STATE_PRE_BOOT;
   always @ (posedge clk) begin
      cpi_cycle_counter_inc = cpi_cycle_counter + 1;
      cpi_cycle_counter <= cpi_cycle_counter_inc;
      // Default enables to off
      cache_wr_en <= 0;
      cache_rd_en <= 0;
      pixel_en <= 0;
      multiply_en <= 0;
      divide_en <= 0;
      ms_time_rst <= 0;
      // State machine
      case (state)
        STATE_PRE_BOOT: begin
           if (boot_done) begin
              cpi_cycle_counter <= 0;
              state <= STATE_EXECUTING;
           end
        end
        STATE_HALT: begin
           halted <= 1;
        end
        STATE_EXECUTING: begin
           halted <= 0;
           if (instr_valid) begin
              if (&cpi_instr_counter) begin
                 status_digits <= cpi_cycle_counter_inc[12+CPI_BITS-1:CPI_BITS];
                 cpi_cycle_counter <= 0;
              end
              cpi_instr_counter <= cpi_instr_counter + 1;
              execute();
           end
        end
        STATE_WR_WAIT: begin
           if (cache_wr_done) begin
              state <= STATE_EXECUTING;
           end
        end
        STATE_PIXEL_WAIT: begin
           if (pixel_wr_done) begin
              state <= STATE_EXECUTING;
           end
        end
        STATE_RD_WAIT: begin
           if (cache_rd_done) begin
              registers[load_reg] <= cache_rd_data;
              state <= STATE_EXECUTING;
           end
        end
        STATE_RET_WAIT: begin
           if (cache_rd_done) begin
              instr_ptr <= cache_rd_data + `INSTR_BYTES;
              state <= STATE_EXECUTING;
           end
        end
        STATE_MULTIPLY: begin
           if (multiply_done) begin
              registers[load_reg] <= multiply_result[`WORD_BITS-1:0];
              state <= STATE_EXECUTING;
           end
        end
        STATE_DIVIDE: begin
           if (divide_done) begin
              registers[load_reg] <= quotient;
              state <= STATE_EXECUTING;
           end
        end
      endcase
   end

   // A task to execute instructions
   task execute;
      // Intentionally 1 greater than WORD_BITS
      reg [`WORD_BITS:0] result;
      begin
         instr_ptr <= instr_ptr + `INSTR_BYTES;
         case (opcode)
           // NOP
           `OPCODE_NOP: begin
              // Do nothing
           end
           // INPUT DEST SRC
           `OPCODE_INPUT: begin
              registers[reg1] <= buf_inputs[src];
           end
           // CALL ADDR
           // Push the instruction pointer onto the stack
           // and jump to ADDR
           `OPCODE_CALL: begin
              if (cache_wr_done) begin
                 push(instr_ptr);
                 instr_ptr <= argA;
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // RET NUM
           `OPCODE_RET: begin
              if (cache_rd_done) begin
                 pop();
                 registers[`REG_SP] <= registers[`REG_SP] - arg1 - `WORD_BYTES;
                 state <= STATE_RET_WAIT;
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // LOAD DEST SRC
           `OPCODE_LOAD: begin
              if (cache_rd_done) begin
                 read(src);
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // LOADI DEST ADDR
           `OPCODE_LOADI: begin
              if (cache_rd_done) begin
                 read(argB);
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // MOV DEST SRC
           `OPCODE_MOV: begin
              registers[reg1] <= src;
           end
           // MOVI DEST VALUE
           `OPCODE_MOVI: begin
              registers[reg1] <= argB;
           end
           // PUSH REG
           `OPCODE_PUSH: begin
              if (cache_wr_done) begin
                 push(dest);
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // POP REG
           `OPCODE_POP: begin
              if (cache_rd_done) begin
                 pop();
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // ADD DEST SRC
           // Sets flags
           `OPCODE_ADD: begin
              result = dest + src;
              registers[reg1] <= result[`WORD_BITS-1:0];
           end
           // SUB DEST SRC
           `OPCODE_SUB: begin
              result = dest - src;
              registers[reg1] <= result[`WORD_BITS-1:0];
           end
           // MUL DEST SRC
           `OPCODE_MUL: begin
              if (multiply_done) begin
                 multiply_en <= 1;
                 multiply_data_a <= dest;
                 multiply_data_b <= src;
                 state <= STATE_MULTIPLY;
                 load_reg <= reg1;
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // DIV DEST SRC
           // On divide by zero, set dest to all ones
           `OPCODE_DIV: begin
              if (divide_done) begin
                 divide_en <= 1;
                 dividend <= dest;
                 divisor <= src;
                 state <= STATE_DIVIDE;
                 load_reg <= reg1;
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // AND DEST SRC
           `OPCODE_AND: begin
              registers[reg1] <= dest & src;
           end
           // OR DEST SRC
           `OPCODE_OR: begin
              registers[reg1] <= dest | src;
           end
           // XOR DEST SRC
           `OPCODE_XOR: begin
              registers[reg1] <= dest ^ src;
           end
           // SHL DEST SRC
           `OPCODE_SHL: begin
              registers[reg1] <= dest << src;
           end
           // SHRA DEST SRC
           // We have to cast dest to signed to do an arithmetic right shift
           // without rolling our own sign extension logic
           `OPCODE_SHRA: begin
              registers[reg1] <= signed_dest >>> src;
           end
           // SHRL DEST SRC
           `OPCODE_SHRL: begin
              registers[reg1] <= dest >> src;
           end
           // CMP DEST SRC
           // Subtract but only set flags, don't write to registers
           `OPCODE_CMP: begin
              result = dest - src;
           end
           // TST DEST SRC
           // Do an AND and set flags, but don't write to registers
           `OPCODE_TST: begin
              result = { 1'b0, dest & src };
           end
           // COLOR REG
           `OPCODE_COLOR: begin
              pixel_rgb <= dest[7:0];
           end
           // PIXEL X Y
           // Write the contents of the color register to video memory, then
           // wait for the write to finish
           `OPCODE_PIXEL: begin
              if (pixel_wr_done) begin
                 pixel_en <= 1;
                 pixel_x <= dest[7:0];
                 pixel_y <= src[7:0];
                 state <= STATE_PIXEL_WAIT;
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // STOR DEST SRC
           `OPCODE_STOR: begin
              if (cache_wr_done) begin
                 write(dest, src);
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // STOR DEST ADDR
           `OPCODE_STORI: begin
              if (cache_wr_done) begin
                 write(dest, argB);
              end else begin
                 instr_ptr <= instr_ptr;
              end
           end
           // TIME DEST
           `OPCODE_TIME: begin
              registers[reg1] <= ms_time;
           end
           // TIMERST
           `OPCODE_TIMERST: begin
              ms_time_rst <= 1;
           end
           // RND DEST
           `OPCODE_RND: begin
              registers[reg1] <= rnd;
           end
           // JMP DEST
           `OPCODE_JMP: begin
              instr_ptr <= dest;
           end
           // JMPI ADDR
           `OPCODE_JMPI: begin
              instr_ptr <= argA;
           end
           // JEQ ADDR
           `OPCODE_JEQ: begin
              if (zero_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JNE ADDR
           `OPCODE_JNE: begin
              if (!zero_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JG ADDR
           `OPCODE_JG: begin
              if (!zero_flag && sign_flag == overflow_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JGE ADDR
           `OPCODE_JGE: begin
              if (sign_flag == overflow_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JA ADDR
           `OPCODE_JA: begin
              if (!carry_flag && !zero_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JAE ADDR
           `OPCODE_JAE: begin
              if (!carry_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JL ADDR
           `OPCODE_JL: begin
              if (sign_flag != overflow_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JLE ADDR
           `OPCODE_JLE: begin
              if (sign_flag != overflow_flag || zero_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JB ADDR
           `OPCODE_JB: begin
              if (carry_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JBE ADDR
           `OPCODE_JBE: begin
              if (carry_flag || zero_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JO ADDR
           `OPCODE_JO: begin
              if (overflow_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JNO ADDR
           `OPCODE_JNO: begin
              if (!overflow_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JS ADDR
           `OPCODE_JS: begin
              if (sign_flag) begin
                 instr_ptr <= argA;
              end
           end
           // JNS ADDR
           `OPCODE_JNS: begin
              if (!sign_flag) begin
                 instr_ptr <= argA;
              end
           end
           // If we get here, there was an invalid instruction so
           // we show the error and halt
           default: begin
              status_digits <= `STATE_INVALID_INSTR | opcode;
              state <= STATE_HALT;
           end
         endcase
         // Set flags if we are executing CMP, TST, ADD, or SUB. Clear flags
         // otherwise
         if (`OPCODE_CMP == opcode || `OPCODE_TST == opcode ||
             `OPCODE_ADD == opcode || `OPCODE_SUB == opcode) begin
            set_flags(result);
         end else begin
            clear_flags();
         end
      end
   endtask

   // Gives a write command to the cache and moves to STATE_WR_WAIT to wait
   // for the write to complete
   task write;
      input [`WORD_BITS-1:0] data;
      input [`ADDR_BITS-1:0] addr;
      begin
         cache_wr_en <= 1;
         cache_wr_addr <= addr;
         cache_wr_data <= data;
         state <= STATE_WR_WAIT;
      end
   endtask

   // Gives a read command to the cache and moves to STATE_RD_WAIT to wait
   // for the read to complete
   task read;
      input [`ADDR_BITS-1:0] addr;
      begin
         load_reg <= reg1;
         cache_rd_en <= 1;
         cache_rd_addr <= addr;
         state <= STATE_RD_WAIT;
      end
   endtask

   // Push a word onto the stack
   task push;
      input [`WORD_BITS-1:0] push_data;
      reg [`ADDR_BITS-1:0]   new_stack_ptr;
      begin
         new_stack_ptr = registers[`REG_SP] + `WORD_BYTES;
         write(push_data, new_stack_ptr);
         registers[`REG_SP] <= new_stack_ptr;
      end
   endtask

   // Pop a word off the stack
   task pop;
      reg [`ADDR_BITS-1:0] stack_ptr;
      begin
         stack_ptr = registers[`REG_SP];
         read(stack_ptr);
         registers[`REG_SP] <= stack_ptr - 2;
      end
   endtask;

   // Sets overflow, carry, zero, and sign flags on ADD, SUB, or CMP
   // instructions
   task set_flags;
      // This is intentionally 1 greater than WORD_BITS in length, to check
      // for carry/overflow
      input [`WORD_BITS:0] result;
      begin
         // Overflow can be set on ADD, SUB, or CMP - if we add two numbers
         // of the same sign and get a result of the opposite sign,
         // if we subtract a positive from a negative and get a positive,
         // or subtract a negative from a positive and get a negative
         if (`OPCODE_ADD == opcode) begin
            overflow_flag <= (dest[`WORD_BITS-1] &
                              src[`WORD_BITS-1] &
                              ~result[`WORD_BITS-1]) |
                             (~dest[`WORD_BITS-1] &
                              ~src[`WORD_BITS-1] &
                              result[`WORD_BITS-1]);            
         end else if (`OPCODE_SUB == opcode || `OPCODE_CMP == opcode) begin
            overflow_flag <= (dest[`WORD_BITS-1] &
                              ~src[`WORD_BITS-1] &
                              ~result[`WORD_BITS-1]) |
                             (~dest[`WORD_BITS-1] &
                              src[`WORD_BITS-1] &
                              result[`WORD_BITS-1]);
         end else begin
            overflow_flag <= 0;
         end
         // Carry is set if the result is too large to fit into 16 bits
         carry_flag <= result[`WORD_BITS];
         // Zero set if the result was zero
         zero_flag <= (0 == result[`WORD_BITS-1:0]);
         // Sign flag set if the sign bit of the result is set (disregarding
         // the carry bit)
         sign_flag <= result[`WORD_BITS-1];
      end
   endtask

   // Set all flags to zero
   task clear_flags;
      begin
         overflow_flag <= 0;
         carry_flag <= 0;
         zero_flag <= 0;
         sign_flag <= 0;
      end
   endtask

endmodule
