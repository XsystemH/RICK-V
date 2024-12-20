`include "const.v"

module rob(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from Decoder
  input wire to_rob,
  input wire [31:0] pc,
  input wire [5:0] op_type,
  input wire [`REG_ID_BIT-1:0] rd,
  input wire [`REG_ID_BIT-1:0] rs1,
  input wire [`REG_ID_BIT-1:0] rs2,
  input wire [31:0] imm,
  input wire [31:0] inst_pc,
  // to Decoder
  output wire rob_full,
  output wire [`ROB_WIDTH_BIT-1:0] rob_free_id,
  output reg received,
  
  // with decoder & regfile
  input wire [`REG_ID_BIT-1:0] reoder_1,
  input wire [`REG_ID_BIT-1:0] reoder_2,
  output wire rob_rs1_is_ready,
  output wire rob_rs2_is_ready,
  output wire [31:0] rob_rs1_value,
  output wire [31:0] rob_rs2_value,

  // to ifetch
  output reg jalr_finish,
  output reg branch_finish,
  output reg [31:0] pc_next,
  output reg [31:0] pc_branch,
  output reg pre,
  output reg ans,

  // to rs&lsb
  output wire [`ROB_WIDTH_BIT-1:0] rob_head,
  output reg clear_all,
  // from rs&lsb
  input wire rs_to_rob,
  input wire [31:0] rs_value,
  input wire [`REG_ID_BIT-1:0] rs_dest,
  input wire lsb_to_rob,
  input wire [31:0] lsb_value,
  input wire [`REG_ID_BIT-1:0] lsb_dest,

  // to regfile
  output reg rf_write_en,
  output reg [`REG_ID_BIT-1:0] reg_id,
  output reg [`ROB_WIDTH_BIT-1:0] rob_id,
  output reg [31:0] value_out
);
// buffer
  reg busy [`ROB_WIDTH-1:0];
  reg [5:0] op [`ROB_WIDTH-1:0];
  reg [1:0] state [`ROB_WIDTH-1:0]; // 0: Issue 1: Execute 2: WriteBack
  reg [`REG_ID_BIT-1:0] dest [`ROB_WIDTH-1:0];
  reg [31:0] value [`ROB_WIDTH-1:0];
  reg [31:0] imm_ [`ROB_WIDTH-1:0];
  reg [31:0] addr [`ROB_WIDTH-1:0]; // for branch guessing
  reg guessed [`ROB_WIDTH-1:0];

  reg [`ROB_WIDTH_BIT-1:0] head;
  reg [`ROB_WIDTH_BIT-1:0] tail;

  assign rob_full = (head == tail) && busy[tail];
  assign rob_free_id = tail;

  assign rob_rs1_is_ready = busy[reoder_1] ? 0 : 1;
  assign rob_rs2_is_ready = busy[reoder_2] ? 0 : 1;
  assign rob_rs1_value = busy[reoder_1] ? 0 : value[reoder_1];
  assign rob_rs2_value = busy[reoder_2] ? 0 : value[reoder_2];

  assign rob_head = head;

  integer flag = 0;
  integer i = 0;
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (state[head] == 1) begin // in execute state
        flag = 0;
        if (op[head] == 39) begin // exit
          // todo: HALT
        end
        if (op[head] == 3) begin // jalr
          // decoder stall false
          // pc_next <= buffer[head].PC (borrowed here)
          jalr_finish <= 1;
          pc_next <= addr[head];
        end else begin
          jalr_finish <= 0;
        end
        if (4 <= op[head] && op[head] <= 7) begin // branch
          branch_finish <= 1;
          if (value[head] != {31'b0, guessed[head]}) begin
            pc_next <= addr[head] + (value[head] == 1 ? imm_[head] : 4);
            flag = 1;
            pc_branch <= addr[head];
            pre <= guessed[head];
            ans <= value[head] != 0;
          end else begin
            pc_branch <= addr[head];
            pre <= guessed[head];
            ans <= value[head] != 0;
          end
        end else begin
          branch_finish <= 0;
        end
        if (flag == 1) begin
          // clear all the instructions
          for (i = 0; i < `ROB_WIDTH; i = i + 1) begin
            busy[i] <= 0;
          end
          head <= 0;
          tail <= 0;

          clear_all <= 1;
          jalr_finish <= 1; // quit stall?
        end else begin
          clear_all <= 0;

          reg_id <= dest[head];
          rob_id <= head;
          value_out <= value[head];

          head <= head + 1 == `ROB_WIDTH ? 0 : head + 1;
        end
        // free reg
        // store to memory if needed
      end else begin
        jalr_finish <= 0;
        branch_finish <= 0;
      end
      
      if (to_rob) begin
        busy[tail] <= 1;
        op[tail] <= op_type;
        state[tail] <= 0;
        dest[tail] <= rd;
        value[tail] <= 0;
        imm_[tail] <= imm;
        addr[tail] <= inst_pc;
        guessed[tail] <= 0;
        tail <= tail + 1 == `ROB_WIDTH ? 0 : tail + 1;
        received <= 1;
      end else begin
        received <= 0;
      end

      // listen
      if (rs_to_rob) begin
        state[rs_dest] <= 1; // excute
        value[rs_dest] <= rs_value;
      end
      if (lsb_to_rob) begin
        state[lsb_dest] <= 1; // excute
        value[lsb_dest] <= lsb_value;
      end
    end
  end

endmodule