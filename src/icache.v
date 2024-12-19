// 由于mem的数据每周期返回[7:0]，所以没必要这么复杂

module icache#(
  parameter CACHE_WIDTH = 3,
  parameter CACHE_SIZE = 1 << CACHE_WIDTH
)(
  input wire clk,
  input wire rst, // reset when high
  input wire rdy, // pause when low

  // from memctrl
  input wire memctrl_to_icache,
  input wire [31:0] inst_in,
  // to memctrl
  output reg icache_to_memctrl,
  output reg [31:0] address,

  // from Decoder
  input wire to_icache,
  input wire [31:0] pc,
  // to Decoder
  output reg have_result,
  output reg [31:0] inst
);

  reg state; // 0 IDEL 1 WAITING
  reg valid[CACHE_SIZE-1:0];
  reg [31:0] cache_block_addr[CACHE_SIZE-1:0];
  reg [31:0] cache_block[CACHE_SIZE-1:0];

  wire [CACHE_WIDTH-1:0] block_index;
  wire [31:0] head_addr = {pc[31:2], 2'b00};

  assign block_index = pc[CACHE_WIDTH+1:2];

  always @(posedge clk) begin
    if (rst) begin
      state <= 0;
    end else if (!rdy) begin
      // pause
    end else begin
      if (state == 0) begin // IDLE
        if (to_icache) begin
          // hit
          if (valid[block_index] && cache_block_addr[block_index] == head_addr) begin
            inst <= cache_block[block_index];
            have_result <= 1;
          end else begin
            // miss
            icache_to_memctrl <= 1;
            address <= head_addr;
            state <= 1;

            have_result <= 0;
          end
        end else begin
          have_result <= 0;
        end
      end else begin // WAITING
        if (memctrl_to_icache) begin
          cache_block[block_index] <= inst_in;
          cache_block_addr[block_index] <= head_addr;
          valid[block_index] <= 1;
          have_result <= 1;
          state <= 0;
        end
      end
    end
  end
endmodule //icache
