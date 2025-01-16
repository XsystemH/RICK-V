module memctrl(
  input wire clk_in,
  input wire rst_in, // reset
  input wire rdy_in, // ready
  input wire io_buffer_full, // buffer full

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
  output reg icache_task_out,

  // from rob
  input wire HALT
);

  reg wr; // write/read state (1 for write)
  reg [31:0] address;
  
  reg [2:0] width; // 0 - 4
  reg [7:0] temp[7:0];

  reg [1:0] last_served; // 1 for lsb, 2 for icache

  reg state; // 0: idle 1: working
  wire [1:0] serve = state ? 0 : // didn;t finish yet
                     last_served == 2 ? lsb_in ? 1 : 
                                            (icache_in ? 2 : 0) :
                                   icache_in ? 2 :
                                            (lsb_in ? 1 : 0); // decide which to serve fairly

  integer finished;

  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      state <= 0;
      wr <= 0;
      address <= 0;
      width <= 0;
      finished <= 0;
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
      if (state == 0) begin
        if (serve == 0) begin
          lsb_received <= 0;
          icache_received <= 0;
        end else begin
          state <= 1; // start to serve
        end
        if (serve == 1) begin
          last_served <= 1;
          lsb_received <= 1;
          icache_received <= 0;
        
          wr <= l_or_s;
          width <= width_in;
          address <= lsb_address_in;
          finished <= 0;
          // if (l_or_s && lsb_address_in == 32'h00030000) begin
          //   $display("\n[cout] ascii: %h %h %h %h", value_store[7:0], value_store[15:8], value_store[23:16], value_store[31:24]);
          // end
          if (l_or_s) begin
            // store
            temp[0] <= value_store[7:0];
            temp[1] <= value_store[15:8];
            temp[2] <= value_store[23:16];
            temp[3] <= value_store[31:24];
          end else begin
            // load
            finished <= -2;
          end
        end
        if (serve == 2) begin
          last_served <= 2;
          lsb_received <= 0;
          icache_received <= 1;

          wr <= 0; // get instruction
          width <= 4;
          address <= icache_address_in;
          finished <= -2;
        end
      end else begin
        lsb_received <= 0;
        icache_received <= 0;
      end

      if (state == 1) begin
        if ($signed(finished) < $signed({{29{1'b0}}, width})) begin
          if (wr && !(io_buffer_full && address >= 32'h00030000)) begin
            // store
            mem_wr <= 1;
            mem_a <= address + finished;
            mem_dout <= temp[finished];
            finished <= finished + 1;
          end else if (wr && io_buffer_full && address >= 32'h00030000) begin
            // io_buffer_full when store
            mem_wr <= 0;
            mem_a <= 32'h0;
          end else begin
            // load
            mem_wr <= 0;
            mem_a <= address + finished + 2;
            if (finished >= 0) begin
              temp[finished] <= mem_din;
            end
            finished <= finished + 1;
          end
          lsb_task_out <= 0;
          icache_task_out <= 0;
        end else begin // finish
          if (!wr) begin
            // load
            if (last_served == 2) begin
              lsb_task_out <= 0;
              icache_task_out <= 1;
            end
            else if (last_served == 1) begin
              lsb_task_out <= 1;
              icache_task_out <= 0;
            end
            case (width)
              0: value_load <= 0;
              1: value_load <= {24'b0, temp[0]};
              2: value_load <= {16'b0, temp[1], temp[0]};
              3: value_load <= {8'b0, temp[2], temp[1], temp[0]};
              4: value_load <= {temp[3], temp[2], temp[1], temp[0]};
            endcase
          end else begin
            // store
            lsb_task_out <= 0;
            icache_task_out <= 0;
            value_load <= 0;
          end
          state <= 0;

          mem_wr <= 0;
          mem_a <= 32'h0;
        end
      end else begin
        lsb_task_out <= 0;
        icache_task_out <= 0;

        mem_wr <= 0;
        mem_a <= 32'h0;
      end

      if (HALT) begin
        // $display("memctrl: HALT");
        mem_wr <= 1; // write
        mem_a <= 32'h00030004;
        mem_dout <= 8'b0;
      end
    end
  end
    
endmodule //memctrl
