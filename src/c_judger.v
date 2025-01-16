module c_judger(
  input wire [31:0] inst,
  output wire [5:0] c_to_i,
  output wire is_c
);
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
                                                                                        /* c_inst[12] == 1*/  c_rs2[4:3] == 2'b00 ? 11 :
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
  reg [5:0] lookup_table [0:24]; // 25: 0-24
  initial begin
    lookup_table[0] = 18;
    lookup_table[1] = 2;
    lookup_table[2] = 0;
    lookup_table[3] = 18;
    lookup_table[4] = 0;
    lookup_table[5] = 25;
    lookup_table[6] = 26;
    lookup_table[7] = 23;
    lookup_table[8] = 28;
    lookup_table[9] = 32;
    lookup_table[10] = 35;
    lookup_table[11] = 36;
    lookup_table[12] = 2;
    lookup_table[13] = 4;
    lookup_table[14] = 5;
    lookup_table[15] = 18;
    lookup_table[16] = 12;
    lookup_table[17] = 17;
    lookup_table[18] = 24;
    lookup_table[19] = 3;
    lookup_table[20] = 27;
    lookup_table[21] = 3;
    lookup_table[22] = 27;
    lookup_table[23] = 12;
    lookup_table[24] = 17;
  end
  assign c_to_i = (c_type <= 24) ? lookup_table[c_type[4:0]] : 39;
  assign is_c = c_type != 39;
endmodule //c_judger
