`include "const.v"

module regfile(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  input wire [`REG_ID_BIT-1:0] reg_id,
  input wire write_en, // write
  
  // write
  input wire in_rob, // 0: value, 1: rob_id
  input wire [31:0] value,
  input wire [`ROB_WIDTH_BIT-1:0] rob_id,

  // read
  output reg is_busy, // 0: valid, 1: rob_id
  output reg [31:0] out_value,
  output reg [`ROB_WIDTH_BIT-1:0] reorder,

  // with decoder
  input wire [`REG_ID_BIT-1:0] rs1,
  input wire [`REG_ID_BIT-1:0] rs2,
  output wire rs1_busy,
  output wire rs2_busy,
  output wire [31:0] rs1_value,
  output wire [31:0] rs2_value,
  output wire [`ROB_WIDTH_BIT-1:0] rs1_re,
  output wire [`ROB_WIDTH_BIT-1:0] rs2_re
);

  reg busy [`REG_ID_WIDTH-1:0];
  reg [31:0] regs [`REG_ID_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] rob [`REG_ID_WIDTH-1:0];
  
  // connect with decoder
  assign rs1_busy = busy[rs1];
  assign rs2_busy = busy[rs2];
  assign rs1_value = busy[rs1] ? 0 : regs[rs1];
  assign rs2_value = busy[rs2] ? 0 : regs[rs2];
  assign rs1_re = busy[rs1] ? rob[rs1] : 0;
  assign rs2_re = busy[rs2] ? rob[rs2] : 0;

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (write_en) begin // read
        if (busy[reg_id]) begin
          is_busy <= 1;
          reorder <= rob[reg_id];
        end else begin
          is_busy <= 0;
          out_value <= regs[reg_id];
        end
      end else begin // write
        if (in_rob) begin
          busy[reg_id] <= 1;
          rob[reg_id] <= rob_id;
        end else begin
          busy[reg_id] <= 0;
          regs[reg_id] <= value;
        end
      end
    end
  end
    
endmodule //regfile
