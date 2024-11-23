`include "const.v"

module RS(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from Decoder
  input wire to_rs,
  input wire [5:0] op_type,
  input wire [`REG_ID_BIT-1:0] rd,
  input wire [`REG_ID_BIT-1:0] rs1,
  input wire [`REG_ID_BIT-1:0] rs2,
  input wire [31:0] imm_in,
  input wire [31:0] inst_pc
);

    reg busy [`RS_WIDTH-1:0];
    reg [5:0] op [`RS_WIDTH-1:0];
    reg [31:0] vj [`RS_WIDTH-1:0];
    reg [31:0] vk [`RS_WIDTH-1:0];
    reg [`ROB_WIDTH_BIT-1:0] qj [`RS_WIDTH-1:0];
    reg [`ROB_WIDTH_BIT-1:0] qk [`RS_WIDTH-1:0];
    reg j [`RS_WIDTH-1:0];
    reg k [`RS_WIDTH-1:0];
    reg [31:0] imm [`RS_WIDTH-1:0];
    reg [31:0] addr [`RS_WIDTH-1:0];
    reg [31:0] dest [`RS_WIDTH-1:0];
  
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (to_rs) begin
        // store to RS
      end
    end
  end
endmodule //RS
