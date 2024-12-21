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

  // from ROB
  input wire [`ROB_WIDTH_BIT-1:0] rob_head,

  // to CDB
  output reg lb_to_rob,
  output reg [`ROB_WIDTH_BIT-1:0] load_id,
  output reg [31:0] value,

  output reg sb_to_rob,
  output reg [`ROB_WIDTH_BIT-1:0] store_id
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
  reg [`ROB_WIDTH_BIT-1:0] rob_id [`LSB_WIDTH-1:0];

  reg [5:0] last_op;
  reg [`REG_ID_BIT-1:0] last_dest;
  
  wire full = head == tail && busy[head];
  wire empty = head == tail && !busy[head];

  assign lsb_full = full;

  integer i;
  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      head <= 0;
      tail <= 0;
      for (i = 0; i < `LSB_WIDTH; i = i + 1) begin
        busy[i] <= 0;
      end
      go_work <= 0;
      lb_to_rob <= 0;
      sb_to_rob <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (task_in) begin
        $display("current lsb head: %d, tail: %d", head, tail);
        for (i = 0; i < `LSB_WIDTH; i = i + 1) begin
          $display("lsb[%d]: busy: %d, op: %d, vj: %d, vk: %d, qj: %d, qk: %d, j: %d, k: %d, imm: %d, addr: %h, rob#: %d", i, busy[i], op[i], vj[i], vk[i], qj[i], qk[i], j[i], k[i], imm[i], inst_pc[i], rob_id[i]);
        end
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
        rob_id[tail] <= dest_in;
        tail <= (tail + 1 == `LSB_WIDTH) ? 0 : tail + 1;
        $display("LSB got: head: %d, tail: %d, op: %d, vj: %d, vk: %d, qj: %d, qk: %d, j: %d, k: %d, imm: %d, addr: %h, rob#: %d", head, tail, op_type, vj_in, vk_in, qj_in, qk_in, j_in, k_in, imm_in, inst_pc_in, dest_in);
      end

      if (!empty && j[head] && k[head]) begin // boardcast all the time
        if (10 <= op[head] && op[head] <= 14) begin
          // load
          go_work <= 1;
          l_or_s <= 0;
          address <= vj[head] + imm[head];
          width <= op[head] == 10 ? 1 :
                   op[head] == 11 ? 2 : // sign extend
                   op[head] == 12 ? 4 :
                   op[head] == 13 ? 1 :
                   op[head] == 14 ? 2 : 0; // no sign ext
          last_dest <= rob_id[head];
        end else if (15 <= op[head] && op[head] <= 17) begin
          // store should be done when at the top of ROB
          $display("Why don't you work? lsb! rob_id[%d]: %d, rob_head: %d", head, rob_id[head], rob_head);
          go_work <= rob_head == rob_id[head] ? 1 : 0;
          l_or_s <= 1;
          address <= vj[head] + imm[head];
          width <= op[head] == 15 ? 1 :
                   op[head] == 16 ? 2 :
                   op[head] == 17 ? 4 : 0;
          value_store <= (op[head] == 15) ? (vk[head] & 32'h000000ff) :
                       (op[head] == 16) ? (vk[head] & 32'h0000ffff) :
                       (op[head] == 17) ? vk[head] : 0;
        end else begin
          go_work <= 0;
        end
      end
      if (go_work && received) begin // head + 1 when memctrl received
        $display("lsb: I'm working! id: %d, op: %d, rob#: %d", head, op[head], rob_id[head]);
        go_work <= 0;
        
        last_op <= op[head];
        last_dest <= rob_id[head];
        busy[head] <= 0;

        if (15 <= op[head] && op[head] <= 17) begin
          // store
          sb_to_rob <= 1;
          store_id <= rob_id[head];
        end else begin
          sb_to_rob <= 0;
        end
        head <= (head + 1 == `LSB_WIDTH) ? 0 : head + 1;
      end else begin
        sb_to_rob <= 0;
      end
      if (has_result) begin
        // write back
        lb_to_rob <= 1;
        value <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                 last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                 value_load;
        load_id <= last_dest;

        // renew lsb itself
        for (i = 0; i < `LSB_WIDTH; i = i + 1) begin
          if (busy[i]) begin
            if (qj[i] == last_dest && j[i] == 0) begin
              j[i] <= 1;
              vj[i] <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                       last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                       value_load;
            end
            if (qk[i] == last_dest && k[i] == 0) begin
              k[i] <= 1;
              vk[i] <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                       last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                       value_load;
            end
          end
        end
      end else begin
        lb_to_rob <= 0;
      end
    end
  end

endmodule //lsb
