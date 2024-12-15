module memctrl(
  input wire clk_in,
  input wire rst_in, // reset
  input wire rdy_in, // ready

  //from mem
  input wire [7:0] mem_din,        // data input bus
  output wire [7:0] mem_dout,      // data output bus
  output wire [31:0] mem_a,        // address bus (only 17:0 is used)
  output wire mem_wr,              // write/read signal (1 for write)

  // from lsb
  input wire lsb_in,
  input wire l_or_s,
  input wire [2:0] width_in,
  input wire [31:0] address_in,
  input wire [31:0] value_store,
  //to lsb
  output wire task_out,
  output wire [31:0] value_load,
  output wire lsb_available,

  // from icache
  input wire icache_in
);

  reg wr; // write/read state (1 for write)
  reg [31:0] address;
  reg [2:0] finished;
  reg [2:0] width;
  reg [7:0] temp[3:0];

  reg last_served; // 0 for lsb, 1 for icache

  wire [1:0] serve = finished < width ? 0 :
                     last_served ? lsb_in ? 1 : 
                                            (icache_in ? 2 : 0) :
                                   icache_in ? 2 :
                                            (lsb_in ? 1 : 0);

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      wr <= 0;
      address <= 0;
      width <= 0;
      last_served <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (serve == 1) begin
        
        last_served <= 0;
      end
      if (serve == 2) begin
        
      end
      if (finished < width) begin

      end
    end
  end
    
endmodule //memctrl
