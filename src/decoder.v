`include "const.v"

module Decoder(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from OP Queue
  input wire valid,
  input wire [31:0] pc,
  input wire [31:0] inst,
  
  output reg [5:0] op_type,
  output reg [`REG_ID_BIT-1:0] rd,
  output reg [`REG_ID_BIT-1:0] rs1,
  output reg [`REG_ID_BIT-1:0] rs2,
  output reg [31:0] imm,
  output reg [31:0] inst_pc,

  // from ROB
  input wire rob_full,
  input wire [`ROB_WIDTH_BIT-1:0] rob_free_id, // no need to use
  // to ROB
  output reg to_rob,
  // from RS
  input wire rs_full,
  // to RS
  output reg to_rs,
  // from LSB
  input wire lsb_full,
  // to LSB
  output reg to_lsb
);
  localparam CodeLui = 7'b0110111, CodeAupic = 7'b0010111, CodeJal = 7'b1101111;
  localparam CodeJalr = 7'b1100111, CodeBr = 7'b1100011, CodeLoad = 7'b0000011;
  localparam CodeStore = 7'b0100011, CodeArithR = 7'b0110011, CodeArithI = 7'b0010011;

  reg [31:0] pc_next;
  reg stall;

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
  
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset

    end else if (!rdy_in) begin
      // doing nothing
    end else if (!(rob_full || stall)) begin
      // processing
      if (valid) begin
        case(opcode)
          CodeLui: begin // LUI
            op_type <= 0;
            imm <= imm_u;
            pc_next <= pc + 4;
          end
          CodeAupic: begin // AUIPC
            op_type <= 1;
            imm <= imm_u + pc;
            pc_next <= pc + 4;
          end
          CodeJal: begin // JAL
            op_type <= 2;
            imm <= pc + 4;
            pc_next <= pc + imm_j;
          end
          CodeJalr: begin // JALR
            op_type <= 3;
            imm <= pc + 4;
            inst_pc <= ({25'b0, func7} << 5) + {27'b0, rs2_raw};
            if (func7[6]) begin
              inst_pc <= inst_pc | 32'hfffff000;
            end
            stall <= 1;
          end
          CodeBr: begin // BEQ, BNE, BLT, BGE, BLTU, BGEU
            imm <= pc + 4;
            pc_next = pc + imm_b; // todo: predictor
            case (func3)
              3'b000: begin // BEQ
                op_type <= 4;
              end
              3'b001: begin // BNE
                op_type <= 5;
              end
              3'b100: begin // BLT
                op_type <= 6;
              end
              3'b101: begin // BGE
                op_type <= 7;
              end
              3'b110: begin // BLTU
                op_type <= 8;
              end
              3'b111: begin // BGEU
                op_type <= 9;
              end
              default: begin
                // invalid instruction 
              end
            endcase
          end
          CodeLoad: begin // LB, LH, LW, LBU, LHU
            pc_next <= pc + 4;
            imm <= imm_i;
            case (func3)
              3'b000: begin // LB
                op_type <= 10;
              end
              3'b001: begin // LH
                op_type <= 11;
              end
              3'b010: begin // LW
                op_type <= 12;
              end
              3'b100: begin // LBU
                op_type <= 13;
              end
              3'b101: begin // LHU
                op_type <= 14;
              end
              default: begin
                // invalid instruction
              end
            endcase
          end
          CodeStore: begin // SB, SH, SW
            imm <= imm_s;
            pc_next <= pc + 4;
            case (func3)
              3'b000: begin // SB
                op_type <= 15;
              end
              3'b001: begin // SH
                op_type <= 16;
              end
              3'b010: begin // SW
                op_type <= 17;
              end
              default: begin
                // invalid instruction
              end
            endcase
          end
          CodeArithI: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            imm <= imm_i;
            pc_next <= pc + 4;
            case (func3)
              3'b000: begin // ADDI
                op_type <= 18;
              end
              3'b010: begin // SLTI
                op_type <= 19;
              end
              3'b011: begin // SLTIU
                op_type <= 20;
              end
              3'b100: begin // XORI
                op_type <= 21;
              end
              3'b110: begin // ORI
                op_type <= 22;
              end
              3'b111: begin // ANDI
                op_type <= 23;
              end
              3'b001: begin // SLLI
                op_type <= 24;
                imm <= {27'b0, rs2_raw}; // shamt
              end
              3'b101: begin // SRLI, SRAI
                if (func7[5]) begin // SRAI
                  op_type <= 26;
                end else begin // SRLI
                  op_type <= 25;
                end
                imm <= {27'b0, rs2_raw}; // shamt
              end
              default: begin
                // invalid instruction
              end
            endcase
            if (inst === 32'h0ff00513) begin // exit
              op_type <= 38;
            end
          end
          CodeArithR: begin // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            pc_next <= pc + 4;
            case (func3)
              3'b000: begin // ADD, SUB
                if (func7[5]) begin // SUB
                  op_type <= 29;
                end else begin // ADD
                  op_type <= 28;
                end
              end
              3'b001: begin // SLL
                op_type <= 30;
              end
              3'b010: begin // SLT
                op_type <= 31;
              end
              3'b011: begin // SLTU
                op_type <= 32;
              end
              3'b100: begin // XOR
                op_type <= 33;
              end
              3'b101: begin // SRL, SRA
                if (func7[5]) begin // SRA
                  op_type <= 35;
                end else begin // SRL
                  op_type <= 34;
                end
              end
              3'b110: begin // OR
                op_type <= 36;
              end
              3'b111: begin // AND
                op_type <= 37;
              end
              default: begin
                // invalid instruction
              end
            endcase
          end
          default: begin
            pc_next <= pc + 4;
            op_type <= 39;
            // invalid instruction
          end
        endcase

        if (10 <= op_type && op_type <= 17) begin // load/store
          if (!lsb_full) begin
            to_rob <= 1;
            to_lsb <= 1;
            to_rs <= 0;
            // to ROB
            if (op_type >= 15) begin
              rd <= 0; // store
            end else begin
              rd <= rd_raw;
            end
            rs1 <= rs1_raw;
            rs2 <= rs2_raw;
            // to LSB
          end else begin
            pc_next <= pc;
            to_rob <= 0;
            to_lsb <= 0;
            to_rs <= 0;
          end
        end else begin // RS
          if (!rs_full) begin
            to_rob <= 1;
            to_lsb <= 0;
            to_rs <= 1;
            // to ROB

            // to RS
          end else begin
            pc_next <= pc;
            to_rob <= 0;
            to_lsb <= 0;
            to_rs <= 0;
          end
        end
      end // if (valid)
    end // if (!(rob_full || stall))
  end
endmodule //Decoder

