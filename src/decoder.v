`include "const.v"

module decoder(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from ifetch
  input wire to_decoder,
  input wire [31:0] pc,
  input wire [31:0] inst,
  input wire predict,
  // to ifetch
  output wire [31:0] next_pc,
  
  output wire [5:0] op_type,
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
  output wire is_c,

  // from RS
  input wire rs_full,
  // to RS
  output wire to_rs,
  // from LSB
  input wire lsb_full,
  // to LSB
  output wire to_lsb,

  // to regfile
  output wire reorder_en,
  output wire [`REG_ID_BIT-1:0] reorder_reg,
  output wire [`ROB_WIDTH_BIT-1:0] reorder_id
);
  localparam CodeLui = 7'b0110111, CodeAupic = 7'b0010111, CodeJal = 7'b1101111;
  localparam CodeJalr = 7'b1100111, CodeBr = 7'b1100011, CodeLoad = 7'b0000011;
  localparam CodeStore = 7'b0100011, CodeArithR = 7'b0110011, CodeArithI = 7'b0010011;

  // c.instruction
  // | 15:13  | 12 | 11:7   | 6:2 | 1:0 |
  // | funct3 |    | rd_rs1 | rs2 | op  |
  wire [15:0] c_inst = inst[15:0];
  wire [1:0] c_opcode = c_inst[1:0];
  wire [4:0] c_rd_rs1 = c_inst[11:7];
  wire [4:0] c_rs2 = c_inst[6:2];
  wire [2:0] c_func3 = c_inst[15:13];

  wire [5:0] c_type = (c_opcode == 2'b01) ? (c_func3 == 3'b000) ? (c_rd_rs1 != 0 ? 0 : 39) :
                                            (c_func3 == 3'b001) ? 1 :
                                            (c_func3 == 3'b010) ? (c_rd_rs1 != 0 ? 2 : 39) :
                                            (c_func3 == 3'b011) ? (c_rd_rs1 == 2 ? 3 :
                                                                 c_rd_rs1 != 0 ? 4 : 39) :
                                            (c_func3 == 3'b100) ? (c_rd_rs1[4:3] == 2'b00 ? 5 :
                                                                 c_rd_rs1[4:3] == 2'b01 ? 6 :
                                                                 c_rd_rs1[4:3] == 2'b10 ? 7 :
                                                                 c_rd_rs1[4:3] == 2'b11 ? (c_inst[12] == 0 ? (c_rs2[4:3] == 2'b00 ? 8 :
                                                                                                              c_rs2[4:3] == 2'b01 ? 9 :
                                                                                                              c_rs2[4:3] == 2'b10 ? 10 :
                                                                                                              39) :
                                                                                        /* c_inst[12] == 1*/  c_rs2[4:3] == 2'b11 ? 11 :
                                                                                                              39) :
                                                                                               39) :
                                            (c_func3 == 3'b101) ? 12 :
                                            (c_func3 == 3'b110) ? 13 :
                                            (c_func3 == 3'b111) ? 14 :
                                            39 :
                      (c_opcode == 2'b00) ? (c_func3 == 3'b000) ? 15 :
                                            (c_func3 == 3'b010) ? 16 :
                                            (c_func3 == 3'b110) ? 17 :
                                            39 :
                      (c_opcode == 2'b10) ? (c_func3 == 3'b000) ? (c_rd_rs1 != 0 ? 18 : 39) :
                                            (c_func3 == 3'b100) ? (c_inst[12] == 0 && c_rd_rs1 != 0 && c_rs2 == 0 ? 19 : 
                                                                  c_inst[12] == 0 && c_rd_rs1 != 0 && c_rs2 != 0 ? 20 : 
                                                                  c_inst[12] == 1 && c_rd_rs1 != 0 && c_rs2 == 0 ? 21 :
                                                                  c_inst[12] == 1 && c_rd_rs1 != 0 && c_rs2 != 0 ? 22 : 39) :
                                            (c_func3 == 3'b010) ? (c_rd_rs1 != 0 ? 23 : 39) :
                                            (c_func3 == 3'b110) ? 24 : 39 :
                      39;
  wire [31:0] c_imm = (c_type == 0 || c_type == 2 || c_type == 7) ? {{27{c_inst[12]}}, c_rs2} :
                      (c_type == 1 || c_type == 12) ? {{21{c_inst[12]}}, c_inst[8], c_inst[10:9], c_inst[6], c_inst[7], c_inst[2], c_inst[11], c_inst[5 : 3], 1'b0} :
                      (c_type == 3) ? {{23{c_inst[12]}}, c_inst[4:3], c_inst[5], c_inst[2], c_inst[6], 4'b0} :
                      (c_type == 4) ? {{15{c_inst[12]}}, c_rs2, 12'b0} :
                      (c_type == 13 || c_type == 14) ? {{24{c_inst[12]}}, c_inst[6:5], c_inst[2], c_inst[11:10], c_inst[4:3], 1'b0} :
                      
                      (c_type == 5 || c_type == 6) ? {26'b0, c_inst[12], c_inst[6:2]} : // uimm
                      (c_type == 15) ? {22'b0, c_inst[10:7], c_inst[12:11], c_inst[5], c_inst[6], 2'b0} :
                      (c_type == 16) ? {25'b0, c_inst[5], c_inst[12:10], c_inst[6], 2'b0} :
                      (c_type == 17) ? {24'b0, c_inst[6:5], c_inst[12:10], 3'b0} :
                      (c_type == 18) ? {26'b0, c_inst[12], c_inst[6:2]} :
                      (c_type == 23) ? {24'b0, c_inst[3:2], c_inst[12], c_inst[6:4], 2'b0} :
                      (c_type == 24) ? {24'b0, c_inst[8:7], c_inst[12:9], 2'b0} :
                      0;
  wire [`REG_ID_BIT-1:0] c_rs_1 = (c_type == 0 || c_type == 18 || c_type == 19 || c_type == 21 || c_type == 22) ? c_rd_rs1 :
                                  ((5 <= c_type && c_type <= 11) || c_type == 13 || c_type == 14 || c_type == 16 || c_type == 17) ? {2'b1, c_rd_rs1[2:0]} :
                                  (c_type == 24) ? 2 :
                                  (c_type == 3 || c_type == 15 || c_type == 23) ? 2 : // sp
                                  0;
  wire [`REG_ID_BIT-1:0] c_rs_2 = ((8 <= c_type && c_type <= 11) || c_type == 17) ? {2'b1, c_rs2[2:0]} :
                                  (c_type == 20 || c_type == 22 || c_type == 24) ? c_rs2 :
                                  0;
  wire [`REG_ID_BIT-1:0] c_rd = (c_type == 0 || c_type == 2 || c_type == 4 || c_type == 18 || c_type == 20 || c_type == 22 || c_type == 23) ? c_rd_rs1 :
                                (5 <= c_type && c_type <= 11) ? {2'b1, c_rd_rs1[2:0]} :
                                (c_type == 15 || c_type == 16) ? {2'b1, c_rs2[2:0]} :
                                (c_type == 1) ? 1 : 
                                (c_type == 3) ? 2 :
                                0;
  wire [5:0] c_to_i = c_type == 0 ? 18 :
                      c_type == 1 ? 2 :
                      c_type == 2 ? 0 :
                      c_type == 3 ? 18 :
                      c_type == 4 ? 0 :
                      c_type == 5 ? 25 :
                      c_type == 6 ? 26 :
                      c_type == 7 ? 23 :
                      c_type == 8 ? 28 :
                      c_type == 9 ? 32 :
                      c_type == 10 ? 35 :
                      c_type == 11 ? 36 :
                      c_type == 12 ? 2 :
                      c_type == 13 ? 4 :
                      c_type == 14 ? 5 :
                      c_type == 15 ? 18 :
                      c_type == 16 ? 12 :
                      c_type == 17 ? 17 :
                      c_type == 18 ? 24 :
                      c_type == 19 ? 3 :
                      c_type == 20 ? 27 :
                      c_type == 21 ? 3 :
                      c_type == 22 ? 27 :
                      c_type == 23 ? 12 :
                      c_type == 24 ? 17 :
                      39;
  wire is_c_inst = c_type != 39;

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
  wire [31:0] imm_i_= {{27{inst[31]}}, inst[24:20]};
  wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  
  // jal
  wire [31:0] jal_imm = is_c_inst ? c_imm : imm_j;
  wire [31:0] jal_pc = pc + jal_imm;
  // branch
  wire [31:0] branch_imm = is_c_inst ? c_imm : imm_b;
  wire [31:0] branch_pc = pc + branch_imm;

  // combinatorial logic

  assign inst_pc = pc;

  assign op_type = is_c_inst ? c_to_i :
                   (opcode == CodeLui) ? 0 :
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
                 (opcode == CodeArithI) ? ((inst == 32'h0ff00513) ? 38 : // exit
                                          (func3 == 3'b000) ? 18 :
                                          (func3 == 3'b010) ? 19 :
                                          (func3 == 3'b011) ? 20 :
                                          (func3 == 3'b100) ? 21 :
                                          (func3 == 3'b110) ? 22 :
                                          (func3 == 3'b111) ? 23 :
                                          (func3 == 3'b001) ? 24 :
                                          (func3 == 3'b101 && func7 == 0) ? 25 : // slli
                                          (func3 == 3'b101) ? 26 : // srli
                                          39) :
                 (opcode == CodeArithR) ? ((func3 == 3'b000 && func7 == 0) ? 27 : // add
                                          (func3 == 3'b000) ? 28 : // sub
                                          (func3 == 3'b001) ? 29 : // sll
                                          (func3 == 3'b010) ? 30 : // slt
                                          (func3 == 3'b011) ? 31 : // sltu
                                          (func3 == 3'b100) ? 32 : // xor
                                          (func3 == 3'b101 && func7 == 0) ? 33 : // srl
                                          (func3 == 3'b101) ? 34 : // sra
                                          (func3 == 3'b110) ? 35 : // or
                                          (func3 == 3'b111) ? 36 : // and
                                          39) :
                 39;

  assign imm = is_c_inst ? c_imm :
               (opcode == CodeLui) ? imm_u :
               (opcode == CodeAupic) ? (imm_u + pc) :
               (opcode == CodeJal) ? imm_j :
               (opcode == CodeJalr) ? imm_i :
               (opcode == CodeBr) ? imm_b :
               (opcode == CodeLoad) ? imm_i :
               (opcode == CodeArithI) ? (24 <= op_type && op_type <= 26 ? imm_i_ : imm_i) :
               (opcode == CodeStore) ? imm_s :
               0;

  assign to_lsb = to_decoder && (10 <= op_type && op_type <= 17) && !lsb_full && !rob_full;
  assign to_rs  = to_decoder && (op_type < 10 || op_type > 17)   && !rs_full  && !rob_full;
  assign to_rob = to_decoder && !rob_full && (to_lsb || to_rs);
  
  assign rs1 = is_c_inst ? c_rs_1 :
               to_lsb ? rs1_raw :
               to_rs  ? ((3 <= op_type && op_type <= 36) ? rs1_raw : 0) :
               0;
  assign rs2 = is_c_inst ? c_rs_2 :
               to_lsb ? (op_type <= 14 ? 0 : rs2_raw) :
               to_rs  ? (((4 <= op_type && op_type <= 9) 
                        || (15 <= op_type && op_type <= 17)
                        || (27 <= op_type && op_type <= 36)) ? rs2_raw : 0) :
               0;

  assign j = !rs1_busy ? 1 : rob_rs1_is_ready;
  assign qj = !rs1_busy ? 0 : rs1_re;
  assign vj = !rs1_busy ? rs1_value : rob_rs1_value;

  assign k = !rs2_busy ? 1 : rob_rs2_is_ready;
  assign qk = !rs2_busy ? 0 : rs2_re;
  assign vk = !rs2_busy ? rs2_value : rob_rs2_value;
  
  assign dest = is_c_inst ? c_rd :
                (4 <= op_type && op_type <= 9) 
                    || (15 <= op_type && op_type <= 17) 
                    || op_type > 36 ? 0 : rd_raw;

  assign next_pc = to_rob ? (op_type == 2  ? jal_pc : 
                             op_type == 3 ? pc : 
                            (4 <= op_type && op_type <= 9) ? (predict ? branch_pc : pc + (is_c_inst ? 2 : 4)) :
                                                             pc + (is_c_inst ? 2 : 4)) : 
                            pc;
  assign is_c = is_c_inst;
  assign reorder_en = to_rob && dest != 0;
  assign reorder_reg = dest;
  assign reorder_id = rob_free_id;

endmodule //Decoder

