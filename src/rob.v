`include "const.v"

module rob(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from Decoder
  input wire to_rob,
  input wire [5:0] op_type,
  input wire [`REG_ID_BIT-1:0] rd,
  input wire [31:0] imm,
  input wire [31:0] inst_pc,
  input wire predictor_result,
  input wire is_c_inst,
  // to Decoder
  output wire rob_full,
  output wire [`ROB_WIDTH_BIT-1:0] rob_free_id,
  
  // with decoder & regfile
  input wire [`REG_ID_BIT-1:0] reoder_1,
  input wire [`REG_ID_BIT-1:0] reoder_2,
  output wire rob_rs1_is_ready,
  output wire rob_rs2_is_ready,
  output wire [31:0] rob_rs1_value,
  output wire [31:0] rob_rs2_value,

  input wire [`REG_ID_BIT-1:0] c_reoder_1,
  input wire [`REG_ID_BIT-1:0] c_reoder_2,
  output wire c_rob_rs1_is_ready,
  output wire c_rob_rs2_is_ready,
  output wire [31:0] c_rob_rs1_value,
  output wire [31:0] c_rob_rs2_value,

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
  input wire [31:0] jalr_pc,
  input wire lb_to_rob,
  input wire [31:0] lb_value,
  input wire [`REG_ID_BIT-1:0] lb_dest,
  input wire sb_to_rob,
  input wire [`REG_ID_BIT-1:0] sb_dest,

  // to regfile
  output reg write_en,
  output reg [`REG_ID_BIT-1:0] reg_id,
  output reg [`ROB_WIDTH_BIT-1:0] rob_id,
  output reg [31:0] value_out,

  output reg HALT
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
  reg is_c [`ROB_WIDTH-1:0];

  reg [`ROB_WIDTH_BIT-1:0] head;
  reg [`ROB_WIDTH_BIT-1:0] tail;

  assign rob_full = (head == tail) && busy[tail];
  assign rob_free_id = tail;

  assign rob_rs1_is_ready = state[reoder_1] != 0 ? 1 : 0;
  assign rob_rs2_is_ready = state[reoder_2] != 0 ? 1 : 0;
  assign rob_rs1_value = state[reoder_1] != 0 ? value[reoder_1] : 0;
  assign rob_rs2_value = state[reoder_2] != 0 ? value[reoder_2] : 0;

  assign c_rob_rs1_is_ready = state[c_reoder_1] != 0 ? 1 : 0;
  assign c_rob_rs2_is_ready = state[c_reoder_2] != 0 ? 1 : 0;
  assign c_rob_rs1_value = state[c_reoder_1] != 0 ? value[c_reoder_1] : 0;
  assign c_rob_rs2_value = state[c_reoder_2] != 0 ? value[c_reoder_2] : 0;

  assign rob_head = head;

  integer i = 0;
  // integer t = 0;

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      head <= 0;
      tail <= 0;
      for (i = 0; i < `ROB_WIDTH; i = i + 1) begin
        busy[i] <= 0;
      end

      HALT <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      write_en <= 0;
      clear_all <= 0;
      
      if (to_rob) begin
        // $display("ROB--------------------------------");
        // for (i = 0; i < `ROB_WIDTH; i = i + 1) begin
        //   $display("id: %d busy: %d state: %d op: %d dest: %d value: %d imm_: %d addr: %h", i, busy[i], state[i], op[i], dest[i], value[i], imm_[i], addr[i]);
        // end
        busy[tail] <= 1;
        op[tail] <= op_type;
        state[tail] <= 0;
        dest[tail] <= rd;
        value[tail] <= 0;
        imm_[tail] <= imm;
        addr[tail] <= inst_pc;
        guessed[tail] <= predictor_result;
        is_c[tail] <= is_c_inst;
        // $display("ROB got: head: %d tail: %d op: %d dest: %d imm_: %d addr: %h", head, tail, op_type, rd, imm, inst_pc);
        tail <= tail + 1 == `ROB_WIDTH ? 0 : tail + 1;
      end

      if (busy[head] && state[head] == 1) begin // in execute state
        if (op[head] == 39) begin // exit
          // todo: HALT
          HALT <= 1;
        end
        if (op[head] == 3) begin // jalr
          // decoder stall false
          jalr_finish <= 1;
          pc_next <= jalr_pc;
        end else begin
          jalr_finish <= 0;
        end
        if (4 <= op[head] && op[head] <= 9) begin // branch
          branch_finish <= 1;
          if (value[head] != {31'b0, guessed[head]}) begin
            pc_next <= addr[head] + (value[head] == 1 ? imm_[head] : (is_c[head] ? 2 : 4));
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
        if (busy[head] && state[head] == 1 && 4 <= op[head] && op[head] <= 9 && value[head] != {31'b0, guessed[head]}) begin
          // clear all the instructions
          // $display("clear all");
          for (i = 0; i < `ROB_WIDTH; i = i + 1) begin
            busy[i] <= 0;
          end
          head <= 0;
          tail <= 0;

          clear_all <= 1;
        end else begin
          clear_all <= 0;

          // write back
          write_en <= 1;
          reg_id <= dest[head];
          rob_id <= head;
          value_out <= value[head];

          state[head] <= 2; // write back
          busy[head] <= 0;
          head <= head + 1 == `ROB_WIDTH ? 0 : head + 1;
        end
        // $display("[commit %h] rob#: %d addr: %h, value: %h", t, head, addr[head], value[head]);
        // t <= t + 1;
        // free reg
        // store to memory if needed
      end else begin
        jalr_finish <= 0;
        branch_finish <= 0;
      end

      // listen
      if (rs_to_rob) begin
        state[rs_dest] <= 1; // excute
        value[rs_dest] <= rs_value;
      end
      if (lb_to_rob) begin
        // $display("rob# %d got %d from lb", lb_dest, lb_value);
        state[lb_dest] <= 1; // excute
        value[lb_dest] <= lb_value;
      end
      if (sb_to_rob) begin
        // $display("rob# %d finished by sb", sb_dest);
        state[sb_dest] <= 1; // excute
        value[sb_dest] <= lb_value; // just for debug
      end

      if (clear_all) begin
        for (i = 0; i < `ROB_WIDTH; i = i + 1) begin
          busy[i] <= 0;
        end
        head <= 0;
        tail <= 0;
      end
    end
  end

endmodule