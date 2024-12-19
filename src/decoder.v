`include "const.v"

module Decoder(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from OP Queue
  input wire valid,
  input wire [31:0] pc,
  input wire [31:0] inst,
  
  output wire [5:0] op_type,
  output wire [`REG_ID_BIT-1:0] rd,
  output wire [`REG_ID_BIT-1:0] rs1,
  output wire [`REG_ID_BIT-1:0] rs2,
  output wire [31:0] imm,
  output wire [31:0] inst_pc,

  output wire j,
  output wire k,
  output wire [31:0] vj,
  output wire [31:0] vk,
  output wire [`ROB_WIDTH_BIT-1:0] qj,
  output wire [`ROB_WIDTH_BIT-1:0] qk,

  // from register file
  input wire rs1_busy,
  input wire rs2_busy,
  input wire [31:0] rs1_value,
  input wire [31:0] rs2_value,
  input wire [`ROB_WIDTH_BIT-1:0] rs1_re,
  input wire [`ROB_WIDTH_BIT-1:0] rs2_re,

  // from ROB
  input wire rob_full,
  input wire [`ROB_WIDTH_BIT-1:0] rob_free_id,
  input wire rob_rs1_is_ready,
  input wire rob_rs2_is_ready,
  input wire [31:0] rob_rs1_value,
  input wire [31:0] rob_rs2_value,
  // to ROB
  output wire to_rob,
  output wire [`REG_ID_BIT-1:0] dest,
  output wire [31:0] rob_pc,
  output wire rob_guess,

  // from RS
  input wire rs_full,
  // to RS
  output wire to_rs,
  // from LSB
  input wire lsb_full,
  // to LSB
  output wire to_lsb,
  output wire [5:0] lsb_op,
  output wire [31:0] lsb_imm
);
  localparam CodeLui = 7'b0110111, CodeAupic = 7'b0010111, CodeJal = 7'b1101111;
  localparam CodeJalr = 7'b1100111, CodeBr = 7'b1100011, CodeLoad = 7'b0000011;
  localparam CodeStore = 7'b0100011, CodeArithR = 7'b0110011, CodeArithI = 7'b0010011;

  // instr processing
  wire [6:0] opcode = inst[6:0];
  wire [2:0] func3 = inst[14:12];
  wire [6:0] func7 = inst[31:25];
  wire [4:0] rs1_raw = inst[19:15];
  wire [4:0] rs2_raw = inst[24:20];
  wire [4:0] rd_raw = inst[11:7];

  // imm
  wire [31:0] imm_u = {inst[31:12], 12'b0};
  wire [31:0] imm_j = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
  wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  
  // combinatorial logic

  assign inst_pc = (opcode == CodeJalr) ? (({25'b0, func7} << 5) + {27'b0, rs2_raw} | (func7[6] ? 32'hfffff000 : 32'h0)) : 0;

  assign imm = (opcode == CodeLui) ? imm_u :
               (opcode == CodeAupic) ? (imm_u + pc) :
               (opcode == CodeJal) ? (pc + 4) :
               (opcode == CodeJalr) ? (pc + 4) :
               (opcode == CodeBr || opcode == CodeLoad || opcode == CodeArithI) ? imm_i :
               (opcode == CodeStore) ? imm_s :
               0;

  assign op_type = (opcode == CodeLui) ? 0 :
                   (opcode == CodeAupic) ? 1 :
                   (opcode == CodeJal) ? 2 :
                   (opcode == CodeJalr) ? 3 :
                   (opcode == CodeBr) ? ((func3 == 3'b000) ? 4 :
                                        (func3 == 3'b001) ? 5 :
                                        (func3 == 3'b100) ? 6 :
                                        (func3 == 3'b101) ? 7 :
                                        (func3 == 3'b110) ? 8 :
                                        (func3 == 3'b111) ? 9 :
                                        39) :
                   (opcode == CodeLoad) ? ((func3 == 3'b000) ? 10 :
                                          (func3 == 3'b001) ? 11 :
                                          (func3 == 3'b010) ? 12 :
                                          (func3 == 3'b100) ? 13 :
                                          (func3 == 3'b101) ? 14 :
                                          39) :
                 (opcode == CodeStore) ? ((func3 == 3'b000) ? 15 :
                                         (func3 == 3'b001) ? 16 :
                                         (func3 == 3'b010) ? 17 :
                                         39) :
                 (opcode == CodeArithI) ? ((func3 == 3'b000) ? 18 :
                                          (func3 == 3'b010) ? 19 :
                                          (func3 == 3'b011) ? 20 :
                                          (func3 == 3'b100) ? 21 :
                                          (func3 == 3'b110) ? 22 :
                                          (func3 == 3'b111) ? 23 :
                                          (func3 == 3'b001) ? 24 :
                                          (func3 == 3'b101 && func7[5]) ? 26 :
                                          (func3 == 3'b101) ? 25 :
                                          (inst == 32'h0ff00513) ? 38 :
                                          39) :
                 (opcode == CodeArithR) ? ((func3 == 3'b000 && func7[5]) ? 29 :
                                          (func3 == 3'b000) ? 28 :
                                          (func3 == 3'b001) ? 30 :
                                          (func3 == 3'b010) ? 31 :
                                          (func3 == 3'b011) ? 32 :
                                          (func3 == 3'b100) ? 33 :
                                          (func3 == 3'b101 && func7[5]) ? 35 :
                                          (func3 == 3'b101) ? 34 :
                                          (func3 == 3'b110) ? 36 :
                                          (func3 == 3'b111) ? 37 :
                                          39) :
                 39;

  assign to_rob = op_type != 39 && !rob_full;
  assign to_lsb = (10 <= op_type && op_type <= 17) && !lsb_full;
  assign to_rs = (op_type < 10 || op_type > 17) && op_type != 39 && !rs_full;

  assign rs1 = to_lsb ? rs1_raw :
               to_rs  ? ((3 <= op_type && op_type <= 37) ? rs1_raw : 0) :
               0;
  assign rs2 = to_lsb ? (op_type <= 14 ? 0 : rs2_raw) :
               to_rs  ? (((4 <= op_type && op_type <= 9) 
                        || (15 <= op_type && op_type <= 17)
                        || (27 <= op_type && op_type <= 37)) ? rs2_raw : 0) :
               0;

  assign j = !rs1_busy ? 1 : rob_rs1_is_ready;
  assign qj = !rs1_busy ? 0 : rs1_re;
  assign vj = !rs1_busy ? rs1_value : rob_rs1_value;

  assign k = !rs2_busy ? 1 : rob_rs2_is_ready;
  assign qk = !rs2_busy ? 0 : rs2_re;
  assign vk = !rs2_busy ? rs2_value : rob_rs2_value;
  
  assign dest = (4 <= op_type && op_type <= 9) 
                    || (18 <= op_type && op_type <= 26) 
                    || op_type > 37 ? 0 : rd_raw;

endmodule //Decoder

