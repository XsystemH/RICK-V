`include "const.v"

module ROB(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // from Decoder
  input wire to_rob,
  input wire [31:0] pc,
  input wire [5:0] op_type,
  input wire [`REG_ID_BIT-1:0] rd,
  input wire [`REG_ID_BIT-1:0] rs1,
  input wire [`REG_ID_BIT-1:0] rs2,
  input wire [31:0] imm,
  input wire [31:0] inst_pc,
  // to Decoder
  output wire rob_full,
  output wire [`ROB_WIDTH_BIT-1:0] rob_free_id,
  output reg received,
  
  // with decoder & regfile
  input wire [`REG_ID_BIT-1:0] reoder_1,
  input wire [`REG_ID_BIT-1:0] reoder_2,
  output wire rob_rs1_is_ready,
  output wire rob_rs2_is_ready,
  output wire [31:0] rob_rs1_value,
  output wire [31:0] rob_rs2_value
);
// buffer
  reg busy [`ROB_WIDTH-1:0];
  reg [5:0] op [`ROB_WIDTH-1:0];
  reg [1:0] state [`ROB_WIDTH-1:0]; // 0: Issue 1: Execute 2: WriteBack
  reg [`REG_ID_BIT-1:0] dest [`ROB_WIDTH-1:0];
  reg [31:0] value [`ROB_WIDTH-1:0];
  reg [31:0] addr [`ROB_WIDTH-1:0]; // for branch guessing
  reg guessed [`ROB_WIDTH-1:0];

  reg [`ROB_WIDTH_BIT-1:0] head;
  reg [`ROB_WIDTH_BIT-1:0] tail;

  assign rob_full = (head == tail) && busy[tail];
  assign rob_free_id = tail;

  assign rob_rs1_is_ready = busy[reoder_1] ? 0 : 1;
  assign rob_rs2_is_ready = busy[reoder_2] ? 0 : 1;
  assign rob_rs1_value = busy[reoder_1] ? 0 : value[reoder_1];
  assign rob_rs2_value = busy[reoder_2] ? 0 : value[reoder_2];

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (state[head] == 1) begin // in execute state
        if (op[head] == 39) begin // exit
          // todo: HALT
        end
        if (op[head] == 3) begin // jalr
          // decoder stall false
          // pc_next <= buffer[head].PC (borrowed here)
        end
        // free reg
        // store to memory if needed
      end
      
      if (to_rob) begin
        busy[tail] <= 1;
        op[tail] <= op_type;
        state[tail] <= 0;
        dest[tail] <= rd;
        value[tail] <= 0;
        addr[tail] <= 0;
        guessed[tail] <= 0;
        tail <= tail + 1;
        received <= 1;
      end else begin
        received <= 0;
      end
    end
  end

endmodule