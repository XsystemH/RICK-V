`include "const.v"

module lsb(
  input wire clk_in,
  input wire rst_in, // reset
  input wire rdy_in, // ready

  output wire lsb_full,

  input wire task_in, // store to LSB
  input wire [5:0] op_type, // operation type
  input wire [31:0] vj_in,
  input wire [31:0] vk_in,
  input wire [`ROB_WIDTH_BIT-1:0] qj_in,
  input wire [`ROB_WIDTH_BIT-1:0] qk_in,
  input wire j_in,
  input wire k_in,
  input wire [31:0] imm_in,
  input wire [31:0] inst_pc_in,
  input wire [`REG_ID_BIT-1:0] dest_in,

  // form memctrl
  input wire received,
  input wire has_result,
  input wire [31:0] value_load,
  // to memctrl
  output reg go_work,
  output reg l_or_s, // 0 load 1 store
  output reg [2:0] width,
  output reg [31:0] address,
  output reg [31:0] value_store,

  // to CDB
  output reg lsb_to_rob,
  output reg [`ROB_WIDTH_BIT-1:0] rob_id,
  output reg [31:0] value
);

  reg [`LSB_WIDTH_BIT-1:0] head;
  reg [`LSB_WIDTH_BIT-1:0] tail;
  reg busy [`LSB_WIDTH-1:0];
  reg [5:0] op [`LSB_WIDTH-1:0];
  reg [31:0] vj [`LSB_WIDTH-1:0];
  reg [31:0] vk [`LSB_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] qj [`LSB_WIDTH-1:0];
  reg [`ROB_WIDTH_BIT-1:0] qk [`LSB_WIDTH-1:0];
  reg j [`LSB_WIDTH-1:0];
  reg k [`LSB_WIDTH-1:0];
  reg [31:0] imm [`LSB_WIDTH-1:0];
  reg [31:0] inst_pc [`LSB_WIDTH-1:0];
  reg [`REG_ID_BIT-1:0] dest [`LSB_WIDTH-1:0];

  reg [5:0] last_op;
  reg [`REG_ID_BIT-1:0] last_dest;
  
  wire full = head == tail && busy[head];
  wire empty = head == tail && !busy[head];

  assign lsb_full = full;

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (task_in) begin
        // store to LSB
        busy[tail] <= 1;
        op[tail] <= op_type;
        vj[tail] <= vj_in;
        vk[tail] <= vk_in;
        qj[tail] <= qj_in;
        qk[tail] <= qk_in;
        j[tail] <= j_in;
        k[tail] <= k_in;
        imm[tail] <= imm_in;
        inst_pc[tail] <= inst_pc_in;
        dest[tail] <= dest_in;
        tail <= (tail + 1 == `LSB_WIDTH) ? 0 : tail + 1;
      end

      if (!empty && j[head] && k[head]) begin // boardcast all the time
        if (10 <= op[head] && op[head] <= 15) begin
          // load
          l_or_s <= 0;
          address <= vj[head] + imm[head];
          width <= op[head] == 10 ? 1 :
                   op[head] == 11 ? 2 : // sign extend
                   op[head] == 12 ? 4 :
                   op[head] == 13 ? 1 :
                   op[head] == 14 ? 2 : 0; // no sign ext
          last_dest <= dest[head];
        end else if (20 <= op[head] && op[head] <= 25) begin
          // store
          l_or_s <= 1;
          address <= vj[head] + imm[head];
          width <= op[head] == 20 ? 1 :
                   op[head] == 21 ? 2 :
                   op[head] == 22 ? 4 : 0;
          value_store <= (op[head] == 20) ? (vk[head] & 32'h000000ff) :
                       (op[head] == 21) ? (vk[head] & 32'h0000ffff) :
                       (op[head] == 22) ? vk[head] : 0;
        end
      end
      if (received) begin // head + 1 when memctrl received
        last_op <= op[head];
        last_dest <= dest[head];
        busy[head] <= 0;
        head <= (head + 1 == `LSB_WIDTH) ? 0 : head + 1;
      end
      if (has_result) begin
        // write back
        lsb_to_rob <= 1;
        value <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                 last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                 value_load;
        rob_id <= last_dest;
      end else begin
        lsb_to_rob <= 0;
      end
      
    end
  end

endmodule //lsb
