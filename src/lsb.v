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
  input wire clear_all,

  // from CDB
  input wire rs_to_rob,
  input wire [31:0] rs_value,
  input wire [`REG_ID_BIT-1:0] rs_dest,
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
  reg [`ROB_WIDTH_BIT-1:0] rob_id [`LSB_WIDTH-1:0];

  reg [5:0] last_op;
  reg [`REG_ID_BIT-1:0] last_dest;
  reg waiting;
  
  wire full = (head == tail) && busy[head];
  wire empty = (head == tail) && !busy[head];

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
      waiting <= 0;
      go_work <= 0;
      lb_to_rob <= 0;
      sb_to_rob <= 0;
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
        rob_id[tail] <= dest_in;
        tail <= (tail + 1 == `LSB_WIDTH) ? 0 : tail + 1;
      end

      if (!empty && j[head] && k[head]) begin // boardcast all the time
        if (10 <= op[head] && op[head] <= 14) begin
          // load
          go_work <= (vj[head] + imm[head] < 32'h00030000 || rob_head == rob_id[head]) ? 1 : 0;
          l_or_s <= 0;
          address <= vj[head] + imm[head];
          width <= op[head] == 10 ? 1 :
                   op[head] == 11 ? 2 : // sign extend
                   op[head] == 12 ? 4 :
                   op[head] == 13 ? 1 :
                   op[head] == 14 ? 2 : 0; // no sign ext
          waiting <= (vj[head] + imm[head] < 32'h00030000 || rob_head == rob_id[head]) ? 1 : 0;
        end else if (15 <= op[head] && op[head] <= 17) begin
          // store should be done when at the top of ROB
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
        go_work <= 0;
        
        last_op <= op[head];
        last_dest <= rob_id[head];
        busy[head] <= 0;

        if (15 <= op[head] && op[head] <= 17) begin
          // store
          sb_to_rob <= 1;
          store_id <= rob_id[head];
          value <= value_store;
        end else begin
          sb_to_rob <= 0;
        end
        head <= (head + 1 == `LSB_WIDTH) ? 0 : head + 1;
      end else begin
        sb_to_rob <= 0;
      end
      if (has_result && waiting) begin
        // write back
        // lb_to_rob <= 1; (X) maybe old result which no longer needed
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
        if (task_in) begin
          if (qj_in == last_dest && j_in == 0) begin
            j[tail] <= 1;
            vj[tail] <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                        last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                        value_load;
          end
          if (qk_in == last_dest && k_in == 0) begin
            k[tail] <= 1;
            vk[tail] <= last_op == 10 ? {{24{value_load[7]}}, value_load[7:0]} :
                        last_op == 11 ? {{16{value_load[15]}}, value_load[15:0]} :
                        value_load;
          end
        end

        waiting <= 0;
      end else begin
        lb_to_rob <= 0;
      end

      if (rs_to_rob) begin
        for (i = 0; i < `LSB_WIDTH; i = i + 1) begin
          if (busy[i] && qj[i] == rs_dest && j[i] == 0) begin
            j[i] <= 1;
            vj[i] <= rs_value;
          end
          if (busy[i] && qk[i] == rs_dest && k[i] == 0) begin
            k[i] <= 1;
            vk[i] <= rs_value;
          end
        end

        if (task_in) begin
          if (qj_in == rs_dest && j_in == 0) begin
            j[tail] <= 1;
            vj[tail] <= rs_value;
          end
          if (qk_in == rs_dest && k_in == 0) begin
            k[tail] <= 1;
            vk[tail] <= rs_value;
          end
        end
      end

      if (lb_to_rob && task_in) begin
        if (qj_in == load_id && j_in == 0) begin
            j[tail] <= 1;
            vj[tail] <= value;
          end
          if (qk_in == load_id && k_in == 0) begin
            k[tail] <= 1;
            vk[tail] <= value;
          end
      end

      if (clear_all) begin
        head <= 0;
        tail <= 0;
        for (i = 0; i < `LSB_WIDTH; i = i + 1) begin
          busy[i] <= 0;
        end
        go_work <= 0;
        waiting <= 0;
      end
    end
  end

endmodule //lsb
