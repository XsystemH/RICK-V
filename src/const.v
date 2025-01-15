/*
  lui, auipc, jal, jalr, 0 - 3
  beq, bne, blt, bge, bltu, bgeu, 4 - 9
  lb, lh, lw, lbu, lhu, 10 - 14
  sb, sh, sw, 15 - 17
  addi, slti, sltiu, xori, ori, andi, slli, srli, srai, 18 - 26
  add, sub, sll, slt, sltu, xor_, srl, sra, or_, and_, 27 - 36
  exit, empty 38 - 39

  64 = 2^6 6 Bits for OP_Type
*/

/*
- c.addi      000 | imm[5]  | rs1/rd != 0   | imm[4:0]      | 01 ->0 18
- c.jal       001 | imm[11|4|9:8|10|6|7|3:1|5]              | 01 ->1 2 x[1] = pc + 2; pc = pc + sext(imm)
- c.li        010 | imm[5]  | rd!=0         | imm[4:0]      | 01 ->2 0
- c.addi16sp  011 | imm[9]  | 2             | imm[4|6|8:7|5]| 01 ->3 18 x[2] = x[2] + sext(imm)
- c.lui       011 | imm[17] | rd!={0,2}     | imm[16:12]    | 01 ->4 0
- c.srli      100 | uimm[5] | 00 | rs1'/rd' | uimm[4:0]     | 01 ->5 25
- c.srai      100 | uimm[5] | 01 | rs1'/rd' | uimm[4:0]     | 01 ->6 26
- c.andi      100 | imm[5]  | 10 | rs1'/rd' | imm[4:0]      | 01 ->7 23
- c.sub       100 | 0       | 11 | rs1'/rd' | 00 | rs2'     | 01 ->8 28
- c.xor       100 | 0       | 11 | rs1'/rd' | 01 | rs2'     | 01 ->9 32
- c.or        100 | 0       | 11 | rs1'/rd' | 10 | rs2'     | 01 ->10 35
- c.and       100 | 1       | 11 | rs1'/rd' | 11 | rs2'     | 01 ->11 36
- c.j         101 | imm[11|4|9:8|10|6|7|3:1|5]              | 01 ->12 2 x[0] = pc + 2; pc = pc + sext(imm)
- c.beqz      110 | imm[8|4:3]   | rs1'     | imm[7:6|2:1|5]| 01 ->13 4 
- c.bnez      111 | imm[8|4:3]   | rs1'     | imm[7:6|2:1|5]| 01 ->14 5
- c.addi4spn  000 | uimm[5:4|9:6|2|3]                  |rd' | 00 ->15 18 x[8 + rd'] = x[2] + sext(imm)
- c.lw        010 | uimm[5:3]    | rs1'     | uimm[2|6]|rd' | 00 ->16 12
- c.sw        110 | uimm[5:3]    | rs1'     | uimm[7:6]|rs2'| 00 ->17 17
- c.slli      000 | uimm[5] | rs1/rd != 0   | uimm[4:0]     | 10 ->18 24
- c.jr        100 | 0       | rs1 != 0      | 0             | 10 ->19 3 x[0]
- c.mv        100 | 0       | rd != 0       | rs2 != 0      | 10 ->20 27
- c.jalr      100 | 1       | rs1 != 0      | 0             | 10 ->21 3
- c.add       100 | 1       | rs1/rd != 0   | rs2 != 0      | 10 ->22 27
- c.lwsp      010 | uimm[5] | rd != 0       | uimm[4:2|7:6] | 10 ->23 12
- c.swsp      110 | uimm[5:2|7:6]           | rs2           | 10 ->24 17
*/

`define REG_ID_BIT 5
`define REG_ID_WIDTH (1<<`REG_ID_BIT) // 32

`define ROB_WIDTH_BIT 5
`define ROB_WIDTH (1<<`ROB_WIDTH_BIT) // 32

`define RS_WIDTH_BIT 4
`define RS_WIDTH (1<<`RS_WIDTH_BIT) // 16

`define LSB_WIDTH_BIT 4
`define LSB_WIDTH (1<<`LSB_WIDTH_BIT) // 16