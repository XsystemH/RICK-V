// 由于mem的数据每周期返回[7:0]，所以没必要这么复杂

module icache#(
  parameter CACHE_WIDTH = 3,
  parameter CACHE_SIZE = 1 << CACHE_WIDTH
)(
  input wire clk,
  input wire rst, // reset when high
  input wire rdy, // pause when low

  // from memctrl
  input wire received,
  input wire memctrl_to_icache,
  input wire [31:0] inst_in,
  // to memctrl
  output reg icache_to_memctrl,
  output reg [31:0] address,

  // from ifetch
  input wire to_icache,
  input wire [31:0] pc,
  // to ifetch
  output reg have_result,
  output reg [31:0] inst
);

  reg state; // 0 IDEL 1 WAITING
  reg valid[CACHE_SIZE-1:0];
  reg [31:0] cache_block_addr[CACHE_SIZE-1:0];
  reg [31:0] cache_block[CACHE_SIZE-1:0];

  wire [CACHE_WIDTH-1:0] block_index = pc[CACHE_WIDTH:1];
  wire [31:0] head_addr = {pc[31:1], 1'b0};

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      state <= 0;
      for (i = 0; i < CACHE_SIZE; i = i + 1) begin
        valid[i] <= 0;
      end
    end else if (!rdy) begin
      // pause
    end else begin
      if (state == 0) begin // IDLE
        if (to_icache) begin
          if (valid[block_index] && cache_block_addr[block_index] == head_addr) begin
            // hit
            // $display("\nat pc %h, icache hit", pc);
            inst <= cache_block[block_index];
            have_result <= 1;
          end else begin
            // miss
            // $display("\nat pc %h, icache miss", pc);
            icache_to_memctrl <= 1;
            address <= head_addr;
            state <= 1;

            have_result <= 0;
          end
        end else begin
          icache_to_memctrl <= 0;
          have_result <= 0;
        end
      end else begin // WAITING
        if (received) begin
          icache_to_memctrl <= 0;
        end
        if (memctrl_to_icache) begin
          icache_to_memctrl <= 0;
          cache_block[block_index] <= inst_in;
          cache_block_addr[block_index] <= head_addr;
          valid[block_index] <= 1;
          have_result <= 1;
          inst <= inst_in;
          state <= 0;
        end else begin
          have_result <= 0;
        end
      end
    end
  end
endmodule //icache
