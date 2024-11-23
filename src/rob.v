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
  output wire [`ROB_WIDTH_BIT-1:0] rob_free_id // no need to use
  
);
  typedef struct packed {
    reg busy;
    reg [5:0] op_type;
    reg [1:0] state; // 0: Issue 1: Execute 2: WriteBack
    reg [`REG_ID_BIT-1:0] dest;
    reg [31:0] value;
    reg [31:0] pc; // for branch guessing
    reg guessed;
  } ROB_ENTRY;

  ROB_ENTRY buffer[`ROB_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] head;
  reg [`ROB_WIDTH_BIT-1:0] tail;

  assign rob_full = (head == tail) && buffer[tail].busy;
  assign rob_free_id = tail;

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (buffer[head].state == 1) begin // in execute state
        if (buffer[head].op_type == 39) begin // exit
          // todo: HALT
        end
        if (buffer[head].op_type == 3) begin // jalr
          // decoder stall false
          // pc_next <= buffer[head].PC (borrowed here)
        end
        // free reg
        // store to memory if needed
      end
      
      if (to_rob) begin
        buffer[tail].busy <= 1;
        buffer[tail].op_type <= op_type;
        buffer[tail].state <= 0;
        buffer[tail].dest <= rd;
        buffer[tail].value <= 0;
        buffer[tail].pc <= pc;
        buffer[tail].guessed <= 0;
        tail <= tail + 1;
      end
    end
  end

endmodule