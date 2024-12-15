module icache #(
    parameter CACHE_SIZE = 1024,        // 缓存大小 (1KB)
    parameter BLOCK_SIZE = 16,         // Cache Line 大小 (16 字节)
    parameter ADDRESS_WIDTH = 32       // 地址位宽
) (
    input wire clk,
    input wire rst,
    input wire [ADDRESS_WIDTH-1:0] addr, // 请求地址
    output reg [31:0] instruction,      // 返回的指令
    output reg hit                      // 缓存命中标志
);
    // 计算 Cache 参数
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;  // 缓存块数
    localparam OFFSET_WIDTH = $clog2(BLOCK_SIZE);     // 块内偏移位宽
    localparam INDEX_WIDTH = $clog2(NUM_BLOCKS);      // 索引位宽
    localparam TAG_WIDTH = ADDRESS_WIDTH - OFFSET_WIDTH - INDEX_WIDTH; // 标签位宽

    // 缓存存储器
    reg [31:0] data[NUM_BLOCKS-1:0][BLOCK_SIZE/4-1:0]; // 存储指令数据
    reg [TAG_WIDTH-1:0] tags[NUM_BLOCKS-1:0];          // 存储标签
    reg valid[NUM_BLOCKS-1:0];                         // 有效位

    // 地址分解
    wire [TAG_WIDTH-1:0] tag = addr[ADDRESS_WIDTH-1:INDEX_WIDTH+OFFSET_WIDTH];
    wire [INDEX_WIDTH-1:0] index = addr[INDEX_WIDTH+OFFSET_WIDTH-1:OFFSET_WIDTH];
    wire [OFFSET_WIDTH-1:0] offset = addr[OFFSET_WIDTH-1:0];

    integer t;
    // 缓存访问
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hit <= 0;
            instruction <= 32'b0;
            // 重置有效位
            for (t = 0; t < NUM_BLOCKS; t = t + 1) begin
                valid[t] <= 0;
            end
        end else begin
            if (valid[index] && tags[index] == tag) begin
                // 缓存命中
                hit <= 1;
                instruction <= data[index][offset[OFFSET_WIDTH-1:2]]; // 读取指令
            end else begin
                // 缓存未命中（需要加载）
                hit <= 0;
                instruction <= 32'b0;
            end
        end
    end
endmodule
