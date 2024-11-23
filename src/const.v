/*
  lui, auipc, jal, jalr, 0 - 3
  beq, bne, blt, bge, bltu, bgeu, 4 - 9
  lb, lh, lw, lbu, lhu, 10 - 14
  sb, sh, sw, 15 - 17
  addi, slti, sltiu, xori, ori, andi, slli, srli, srai, 18 - 27
  add, sub, sll, slt, sltu, xor_, srl, sra, or_, and_, 28 - 38
  exit, empty 39 - 40

  64 = 2^6 6 Bits for OP_Type
*/

`define REG_ID_BIT 5
`define REG_ID_WIDTH (1<<`REG_ID_BIT) // 32

`define ROB_WIDTH_BIT 5
`define ROB_WIDTH (1<<`ROB_WIDTH_BIT)