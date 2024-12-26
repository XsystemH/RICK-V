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
  assign c_to_i = c_type == 0 ? 18 :
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
  assign is_c = c_type != 39;
endmodule //c_judger
