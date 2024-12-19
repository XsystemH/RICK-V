`include "const.v"

module RS(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  output wire rs_full,

  // from Decoder
  input wire to_rs,
  input wire [5:0] op_type,
  input wire j_in,
  input wire k_in,
  input wire [31:0] vj_in,
  input wire [31:0] vk_in,
  input wire [`ROB_WIDTH_BIT-1:0] qj_in,
  input wire [`ROB_WIDTH_BIT-1:0] qk_in,
  input wire [`REG_ID_BIT-1:0] dest_in,
  input wire [31:0] imm_in,
  input wire [31:0] inst_pc,

  // to ROB
  output reg has_result,
  output reg [31:0] value,
  output reg [`REG_ID_BIT-1:0] dest_out,

  output reg [31:0] new_PC
);

  reg busy [`RS_WIDTH-1:0];
  reg [`RS_WIDTH_BIT-1:0] size;
  reg [5:0] op [`RS_WIDTH-1:0];
  reg [31:0] vj [`RS_WIDTH-1:0];
  reg [31:0] vk [`RS_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] qj [`RS_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] qk [`RS_WIDTH-1:0];
  reg j [`RS_WIDTH-1:0];
  reg k [`RS_WIDTH-1:0];
  reg [31:0] imm [`RS_WIDTH-1:0];
  reg [31:0] addr [`RS_WIDTH-1:0];
  reg [`REG_ID_BIT-1:0] dest [`RS_WIDTH-1:0];

  assign rs_full = size == `RS_WIDTH;

  integer i;
  integer flag;
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      size <= 0;
      for (i = 0; i < `RS_WIDTH; i = i + 1) begin
        busy[i] <= 0;
      end
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (to_rs) begin
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          if (!busy[i]) begin
            break;
          end
        end // for
        busy[i] <= 1;
        size <= size + 1;
        op[i] <= op_type;
        vj[i] <= vj_in;
        vk[i] <= vk_in;
        qj[i] <= qj_in;
        qk[i] <= qk_in;
        j[i] <= j_in;
        k[i] <= k_in;
        imm[i] <= imm_in;
        addr[i] <= inst_pc;
        dest[i] <= dest_in;
      end
      // execute
      if (size != 0) begin
        flag = 0;
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          if (busy[i] && j[i] && k[i]) begin
            flag = 1;
            break;
          end
        end
        if (flag == 1) begin
          busy[i] <= 0;
          size <= size - 1;
          has_result <= 1;

          // 不想写ALU了 太难受了
          dest_out <= dest[i];
          case (op[i])
            0: begin // lui
              value <= imm[i];
            end
            1: begin // auipc
              value <= imm[i];
            end
            2: begin // jal: jumping to PC when decoding PC
              value <= imm[i];
            end
            3: begin // jalr: jumping to PC when decoding PC
              value <= imm[i];
              new_PC <= vj[i] + imm[i];
            end
            4: begin // beq
              value <= vj[i] == vk[i] ? 1 : 0;
            end
            5: begin // bne
              value <= vj[i] != vk[i] ? 1 : 0;
            end
            6: begin // blt
              value <= $signed(vj[i]) < $signed(vk[i]) ? 1 : 0;
            end
            7: begin // bge
              value <= $signed(vj[i]) >= $signed(vk[i]) ? 1 : 0;
            end
            8: begin // bltu
              value <= vj[i] < vk[i] ? 1 : 0;
            end
            9: begin // bgeu
              value <= vj[i] >= vk[i] ? 1 : 0;
            end
            18: begin // addi
              value <= vj[i] + imm[i];
            end
            19: begin // slti
              value <= $signed(vj[i]) < $signed(imm[i]) ? 1 : 0;
            end
            20: begin // sltiu
              value <= vj[i] < imm[i] ? 1 : 0;
            end
            21: begin // xori
              value <= vj[i] ^ imm[i];
            end
            22: begin // ori
              value <= vj[i] | imm[i];
            end
            23: begin // andi
              value <= vj[i] & imm[i];
            end
            24: begin // slli
              value <= vj[i] << imm[i];
            end
            25: begin // srli
              value <= vj[i] >> imm[i];
            end
            26: begin // srai
              value <= $signed(vj[i]) >>> imm[i];
            end
            27: begin // add
              value <= vj[i] + vk[i];
            end
            28: begin // sub
              value <= $signed(vj[i]) - $signed(vk[i]);
            end
            29: begin // sll
              value <= vj[i] << (vk[i] & 32'h1f);
            end
            30: begin // slt
              value <= $signed(vj[i]) < $signed(vk[i]) ? 1 : 0;
            end
            31: begin // sltu
              value <= vj[i] < vk[i] ? 1 : 0;
            end
            32: begin // xor
              value <= vj[i] ^ vk[i];
            end
            33: begin // srl
              value <= vj[i] >> (vk[i] & 32'h1f);
            end
            34: begin // sra
              value <= $signed(vj[i]) >>> (vk[i] & 32'h1f);
            end
            35: begin // or
              value <= vj[i] | vk[i];
            end
            36: begin // and
              value <= vj[i] & vk[i];
            end
          endcase
        end
      end
      // listen
    end
  end
endmodule //RS
