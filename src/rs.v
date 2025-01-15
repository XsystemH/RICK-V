`include "const.v"

module rs(
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
  input wire is_c_inst,

  // from ROB
  input wire clear_all,
  // to ROB
  output reg rs_to_rob,
  output reg [31:0] value,
  output reg [`REG_ID_BIT-1:0] dest_out,

  // from LSB
  input wire lsb_to_rs,
  input wire [`ROB_WIDTH_BIT-1:0] lsb_rob_id,
  input wire [31:0] lsb_value,

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
  reg is_c [`RS_WIDTH-1:0];

  assign rs_full = size == `RS_WIDTH;

  wire [`RS_WIDTH-1:0] valid;
  assign valid[0] = busy[0]&j[0]&k[0];
  assign valid[1] = busy[1]&j[1]&k[1];
  assign valid[2] = busy[2]&j[2]&k[2];
  assign valid[3] = busy[3]&j[3]&k[3];
  assign valid[4] = busy[4]&j[4]&k[4];
  assign valid[5] = busy[5]&j[5]&k[5];
  assign valid[6] = busy[6]&j[6]&k[6];
  assign valid[7] = busy[7]&j[7]&k[7];
  assign valid[8] = busy[8]&j[8]&k[8];
  assign valid[9] = busy[9]&j[9]&k[9];
  assign valid[10] = busy[10]&j[10]&k[10];
  assign valid[11] = busy[11]&j[11]&k[11];
  assign valid[12] = busy[12]&j[12]&k[12];
  assign valid[13] = busy[13]&j[13]&k[13];
  assign valid[14] = busy[14]&j[14]&k[14];
  assign valid[15] = busy[15]&j[15]&k[15];
  wire flag = valid != 0;
  // id_in is the first 0 in busy
  wire [`RS_WIDTH_BIT-1:0] id_in =  busy[0] == 0 ? 0 :
                busy[1] == 0 ? 1 :
                busy[2] == 0 ? 2 :
                busy[3] == 0 ? 3 :
                busy[4] == 0 ? 4 :
                busy[5] == 0 ? 5 :
                busy[6] == 0 ? 6 :
                busy[7] == 0 ? 7 :
                busy[8] == 0 ? 8 :
                busy[9] == 0 ? 9 :
                busy[10] == 0 ? 10 :
                busy[11] == 0 ? 11 :
                busy[12] == 0 ? 12 :
                busy[13] == 0 ? 13 :
                busy[14] == 0 ? 14 :
                busy[15] == 0 ? 15 : 0;
  wire [`RS_WIDTH_BIT-1:0] id_out = valid[0] ? 0 :
                valid[1] ? 1 :
                valid[2] ? 2 :
                valid[3] ? 3 :
                valid[4] ? 4 :
                valid[5] ? 5 :
                valid[6] ? 6 :
                valid[7] ? 7 :
                valid[8] ? 8 :
                valid[9] ? 9 :
                valid[10] ? 10 :
                valid[11] ? 11 :
                valid[12] ? 12 :
                valid[13] ? 13 :
                valid[14] ? 14 :
                valid[15] ? 15 : 0;

  integer i,ii;
  integer value_temp;

  always @(*) begin
    case (op[id_out])
      0: begin // lui
        value_temp = imm[id_out];
      end
      1: begin // auipc
        value_temp = imm[id_out];
      end
      2: begin // jal: jumping to PC when decoding PC
        value_temp = addr[id_out] + (is_c[id_out] ? 2 : 4);
      end
      3: begin // jalr: jumping to PC when decoding PC
        value_temp = addr[id_out] + (is_c[id_out] ? 2 : 4);
      end
      4: begin // beq
        value_temp = vj[id_out] == vk[id_out] ? 1 : 0;
      end
      5: begin // bne
        value_temp = vj[id_out] != vk[id_out] ? 1 : 0;
      end
      6: begin // blt
        value_temp = $signed(vj[id_out]) < $signed(vk[id_out]) ? 1 : 0;
      end
      7: begin // bge
        value_temp = $signed(vj[id_out]) >= $signed(vk[id_out]) ? 1 : 0;
      end
      8: begin // bltu
        value_temp = vj[id_out] < vk[id_out] ? 1 : 0;
      end
      9: begin // bgeu
        value_temp = vj[id_out] >= vk[id_out] ? 1 : 0;
      end
      18: begin // addi
        value_temp = vj[id_out] + imm[id_out];
      end
      19: begin // slti
        value_temp = $signed(vj[id_out]) < $signed(imm[id_out]) ? 1 : 0;
      end
      20: begin // sltiu
        value_temp = vj[id_out] < imm[id_out] ? 1 : 0;
      end
      21: begin // xori
        value_temp = vj[id_out] ^ imm[id_out];
      end
      22: begin // ori
        value_temp = vj[id_out] | imm[id_out];
      end
      23: begin // andi
        value_temp = vj[id_out] & imm[id_out];
      end
      24: begin // slli
        value_temp = vj[id_out] << imm[id_out];
      end
      25: begin // srli
        value_temp = vj[id_out] >> imm[id_out];
      end
      26: begin // srai
        value_temp = $signed(vj[id_out]) >>> imm[id_out];
      end
      27: begin // add
        value_temp = vj[id_out] + vk[id_out];
      end
      28: begin // sub
        value_temp = $signed(vj[id_out]) - $signed(vk[id_out]);
      end
      29: begin // sll
        value_temp = vj[id_out] << (vk[id_out] & 32'h1f);
      end
      30: begin // slt
        value_temp = $signed(vj[id_out]) < $signed(vk[id_out]) ? 1 : 0;
      end
      31: begin // sltu
        value_temp = vj[id_out] < vk[id_out] ? 1 : 0;
      end
      32: begin // xor
        value_temp = vj[id_out] ^ vk[id_out];
      end
      33: begin // srl
        value_temp = vj[id_out] >> (vk[id_out] & 32'h1f);
      end
      34: begin // sra
        value_temp = $signed(vj[id_out]) >>> (vk[id_out] & 32'h1f);
      end
      35: begin // or
        value_temp = vj[id_out] | vk[id_out];
      end
      36: begin // and
        value_temp = vj[id_out] & vk[id_out];
      end
    endcase
  end

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      size <= 0;
      for (i = 0; i < `RS_WIDTH; i = i + 1) begin
        busy[i] <= 0;
      end
      rs_to_rob <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (to_rs) begin
        busy[id_in] <= 1;
        size <= size + 1;
        op[id_in] <= op_type;
        vj[id_in] <= vj_in;
        vk[id_in] <= vk_in;
        qj[id_in] <= qj_in;
        qk[id_in] <= qk_in;
        j[id_in] <= j_in;
        k[id_in] <= k_in;
        imm[id_in] <= imm_in;
        addr[id_in] <= inst_pc;
        dest[id_in] <= dest_in;
        is_c[id_in] <= is_c_inst;

        if (lsb_to_rs) begin
          if (qj_in == lsb_rob_id && j_in == 0) begin
            j[id_in] <= 1;
            vj[id_in] <= lsb_value;
          end
          if (qk_in == lsb_rob_id && k_in == 0) begin
            k[id_in] <= 1;
            vk[id_in] <= lsb_value;
          end
        end
        // $display("RS got: id: %d, op: %d, vj: %d, vk: %d, qj: %d, qk: %d, j: %d, k: %d, imm: %d, addr: %h, rob#: %d", id, op_type, vj_in, vk_in, qj_in, qk_in, j_in, k_in, imm_in, inst_pc, dest_in);
      end
      // execute
      if (size != 0) begin
        if (flag == 1) begin
          busy[id_out] <= 0;
          size <= size - 1;
          rs_to_rob <= 1;

          // 不想写ALU了 太难受了
          dest_out <= dest[id_out];
          if (op[id_out] == 3) new_PC <= vj[id_out] + imm[id_out];
          value <= value_temp;

          // renew RS
          for (ii = 0; ii < `RS_WIDTH; ii = ii + 1) begin
            if (busy[ii]) begin
              if (qj[ii] == dest[id_out] && j[ii] == 0) begin
                j[ii] <= 1;
                vj[ii] <= value_temp;
              end
              if (qk[ii] == dest[id_out] && k[ii] == 0) begin
                k[ii] <= 1;
                vk[ii] <= value_temp;
              end
            end
          end

          if (to_rs) begin
            if (qj_in == dest[id_out] && j_in == 0) begin
              j[id_in] <= 1;
              vj[id_in] <= value_temp;
            end
            if (qk_in == dest[id_out] && k_in == 0) begin
              k[id_in] <= 1;
              vk[id_in] <= value_temp;
            end
          end
        end else begin
          rs_to_rob <= 0;
        end
      end else begin
        rs_to_rob <= 0;
      end
      // listen
      if (lsb_to_rs) begin
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          if (busy[i]) begin
            if (qj[i] == lsb_rob_id && j[i] == 0) begin
              j[i] <= 1;
              vj[i] <= lsb_value;
            end
            if (qk[i] == lsb_rob_id && k[i] == 0) begin
              k[i] <= 1;
              vk[i] <= lsb_value;
            end
          end
        end
      end

      if (clear_all) begin
        size <= 0;
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          busy[i] <= 0;
        end
      end
    end
  end
endmodule //RS
