module memctrl(
  input wire clk_in,
  input wire rst_in, // reset
  input wire rdy_in, // ready

  //from mem
  input wire [7:0] mem_din,        // data input bus
  output reg [7:0] mem_dout,      // data output bus
  output reg [31:0] mem_a,        // address bus (only 17:0 is used)
  output reg mem_wr,              // write/read signal (1 for write)

  // to lsb & icache
  output reg [31:0] value_load,

  // from lsb
  input wire lsb_in,
  input wire l_or_s,
  input wire [2:0] width_in,
  input wire [31:0] lsb_address_in,
  input wire [31:0] value_store,
  //to lsb
  output reg lsb_received,
  output reg lsb_task_out,

  // from icache
  input wire icache_in,
  input wire [31:0] icache_address_in,
  // to icache
  output reg icache_received,
  output reg icache_task_out
);

  reg wr; // write/read state (1 for write)
  reg [31:0] address;
  reg [2:0] finished;
  reg [2:0] width;
  reg [7:0] temp[4:0];

  reg last_served; // 0 for lsb, 1 for icache

  wire [1:0] serve = finished < width ? 0 : // didn;t finish yet
                     last_served ? lsb_in ? 1 : 
                                            (icache_in ? 2 : 0) :
                                   icache_in ? 2 :
                                            (lsb_in ? 1 : 0); // decide which to serve fairly

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      wr <= 0;
      address <= 0;
      width <= 0;
      last_served <= 0;

      mem_dout <= 8'b0;
      mem_a <= 32'b0;
      mem_wr <= 1'b0;

      value_load <= 32'b0;
      lsb_received <= 1'b0;
      lsb_task_out <= 1'b0;
      icache_received <= 1'b0;
      icache_task_out <= 1'b0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (serve == 0) begin
        lsb_received <= 0;
        icache_received <= 0;
      end
      if (serve == 1) begin
        last_served <= 0;
        lsb_received <= 1;
        icache_received <= 0;
        
        wr <= l_or_s;
        width <= width_in;
        address <= lsb_address_in;
        finished <= 0;
        if (l_or_s) begin
          // store
          temp[0] <= value_store[7:0];
          temp[1] <= value_store[15:8];
          temp[2] <= value_store[23:16];
          temp[3] <= value_store[31:24];
        end
      end
      if (serve == 2) begin
        last_served <= 1;
        lsb_received <= 0;
        icache_received <= 1;

        wr <= 0; // get instruction
        width <= 4;
        address <= icache_address_in;
        finished <= 0;
      end
      if (finished < width) begin
        if (wr) begin
          // store
          mem_wr <= 1;
          mem_a <= address + {29'b0, finished};
          mem_dout <= temp[finished];
        end else begin
          // load
          mem_wr <= 0;
          mem_a <= address + {29'b0, finished};
          temp[finished] <= mem_din;
        end
        finished <= finished + 1;
      end
      if (finished == width) begin
        if (!wr) begin
          // load
          if (last_served) begin
            lsb_task_out <= 0;
            icache_task_out <= 1;
          end
          else begin
            lsb_task_out <= 1;
            icache_task_out <= 0;
          end
          case (width)
            0: value_load <= 0;
            1: value_load <= {24'b0, temp[1]};
            2: value_load <= {16'b0, temp[2], temp[1]};
            3: value_load <= {8'b0, temp[3], temp[2], temp[1]};
            4: value_load <= {temp[4], temp[3], temp[2], temp[1]};
          endcase
        end else begin
          // store
          lsb_task_out <= 0;
          icache_task_out <= 0;
          value_load <= 0;
        end
      end else begin
        lsb_task_out <= 0;
        icache_task_out <= 0;
        value_load <= 0;
      end
    end
  end
    
endmodule //memctrl