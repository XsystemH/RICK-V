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

  integer i,ii;
  integer id_in,id_out;
  integer flag;
  integer value_temp;
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
        // $display("RS--------------------------------");
        // for (i = 0; i < `RS_WIDTH; i = i + 1) begin
        //   $display("RS[%d]: busy: %d, op: %d, vj: %d, vk: %d, qj: %d, qk: %d, j: %d, k: %d, imm: %d, addr: %h, rob#: %d", i, busy[i], op[i], vj[i], vk[i], qj[i], qk[i], j[i], k[i], imm[i], addr[i], dest[i]);
        // end
        id_in = -1;
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          if (id_in == -1 && !busy[i]) begin
            id_in = i;
          end
        end // for
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
        flag = 0;
        id_out = -1;
        for (i = 0; i < `RS_WIDTH; i = i + 1) begin
          if (id_out == -1 && busy[i] && j[i] && k[i]) begin
            flag = 1;
            id_out = i;
          end
        end
        if (flag == 1) begin
          busy[id_out] <= 0;
          size <= size - 1;
          rs_to_rob <= 1;

          // 不想写ALU了 太难受了
          dest_out <= dest[id_out];
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
              new_PC <= vj[id_out] + imm[id_out];
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
