`include "const.v"

module lsb(
  input wire clk_in,
  input wire rst_in, // reset
  input wire rdy_in, // ready

  input wire to_rs, // store to RS
  input wire [5:0] op_type // operation type
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
  reg [31:0] inst_pc [`RS_WIDTH-1:0];
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

endmodule //lsb
