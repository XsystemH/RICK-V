`include "const.v"

module regfile(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from decoder
  input wire reorder_en,
  input wire [`REG_ID_BIT-1:0] reorder_reg,
  input wire [`ROB_WIDTH_BIT-1:0] reorder_id,

  // from rob
  input wire write_en,
  input wire [`REG_ID_BIT-1:0] reg_id,
  input wire [`ROB_WIDTH_BIT-1:0] rob_id,
  input wire [31:0] value,
  input wire clear_all,

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

  integer i;
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      for (i = 0; i < `REG_ID_WIDTH; i = i + 1) begin
        busy[i] <= 0;
        regs[i] <= 0;
        rob[i] <= 0;
      end
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (write_en && reg_id != 0) begin // write
        regs[reg_id] <= value;
        busy[reg_id] <= rob[reg_id] != rob_id;
      end

      if (reorder_en && reorder_reg != 0) begin // reorder
        // $display("reorder reg %d to rob# %d", reorder_reg, reorder_id);
        busy[reorder_reg] <= 1;
        rob[reorder_reg] <= reorder_id;
      end

      if (clear_all) begin
        for (i = 0; i < `REG_ID_WIDTH; i = i + 1) begin
          busy[i] <= 0;
          rob[i] <= 0;
        end
      end
    end
  end
    
endmodule //regfile
