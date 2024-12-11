module alu(
  input wire [31:0] rs1, // operand 1
  input wire [31:0] rs2, // operand 2
  input wire [2:0] alu_op, // 0: add, 1: sub, 2: and, 3: or, 4: xor, 5: sll, 6: srl, 7: sra
  output wire [31:0] result // result
);
  assign result = (alu_op == 0) ? rs1 + rs2 :
                  (alu_op == 1) ? rs1 - rs2 :
                  (alu_op == 2) ? rs1 & rs2 :
                  (alu_op == 3) ? rs1 | rs2 :
                  (alu_op == 4) ? rs1 ^ rs2 :
                  (alu_op == 5) ? rs1 << rs2 :
                  (alu_op == 6) ? rs1 >> rs2 :
                  (alu_op == 7) ? rs1 >>> rs2 : 0;

endmodule //alu