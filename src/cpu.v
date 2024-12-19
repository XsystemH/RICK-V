`include "./memctrl.v"
`include "./icache.v"
// RISCV32 CPU top module
`include "./ifetch.v"
`include "./decoder.v"
`include "./rob.v"
`include "./regfile.v"
`include "./rs.v"
`include "./lsb.v"
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// outports wire
wire [31:0] 	value_load;
wire        	lsb_received;
wire        	lsb_task_out;
wire        	icache_received;
wire        	icache_task_out;

memctrl u_memctrl(
  .clk_in            	( clk_in             ),
  .rst_in            	( rst_in             ),
  .rdy_in            	( rdy_in             ),
  .mem_din           	( mem_din            ),
  .mem_dout          	( mem_dout           ),
  .mem_a             	( mem_a              ),
  .mem_wr            	( mem_wr             ),
  .value_load        	( value_load         ),
  .lsb_in            	( go_work            ),
  .l_or_s            	( l_or_s             ),
  .width_in          	( width              ),
  .lsb_address_in    	( address_from_lsb   ),
  .value_store       	( value_store        ),
  .lsb_received      	( lsb_received       ),
  .lsb_task_out      	( lsb_task_out       ),
  .icache_in         	( icache_to_memctrl  ),
  .icache_address_in 	( address_from_icache),
  .icache_received   	( icache_received    ),
  .icache_task_out   	( icache_task_out    )
);

// outports wire
wire        	icache_to_memctrl;
wire [31:0] 	address_from_icache;
wire        	have_result;
wire [31:0] 	inst_from_icache;

icache #(
  .CACHE_WIDTH 	( 3    ),
  .CACHE_SIZE  	( 1<<3 ))
u_icache(
  .clk               	( clk_in             ),
  .rst               	( rst_in             ),
  .rdy               	( rdy_in             ),
  .memctrl_to_icache 	( icache_task_out    ),
  .inst_in           	( value_load         ),
  .icache_to_memctrl 	( icache_to_memctrl  ),
  .address           	( address_from_icache),
  .to_icache         	( to_icache          ),
  .pc                	( pc_to_icache       ),
  .have_result       	( have_result        ),
  .inst              	( inst_from_icache   )
);

// outports wire
wire        	to_icache;
wire [31:0] 	pc_to_icache;
wire [31:0] 	inst;
wire [31:0] 	pc_to_decoder;
wire        	predict_result;
wire [31:0] 	pc_to_predictor;

ifetch u_ifetch(
  .clk_in             	( clk_in              ),
  .rst_in             	( rst_in              ),
  .rdy_in             	( rdy_in              ),
  .to_icache          	( to_icache           ),
  .pc_to_icache       	( pc_to_icache        ),
  .have_result        	( have_result         ),
  .inst_from_icache   	( inst_from_icache    ),
  .inst               	( inst                ),
  .pc_to_decoder      	( pc_to_decoder       ),
  .predict_result     	( predict_result      ),
  .received           	( received            ),
  .pc_to_predictor    	( pc_to_predictor     ),
  .predict            	( predict             ),
  .rob_to_ifetch      	( rob_to_ifetch       ),
  .next_pc_from_rob   	( next_pc_from_rob    ),
  .branch_pc_from_rob 	( branch_pc_from_rob  ),
  .prejudge           	( prejudge            ),
  .branch_result      	( branch_result       )
);

// outports wire
wire [5:0]                	op_type;
wire [`REG_ID_BIT-1:0]    	rd;
wire [`REG_ID_BIT-1:0]    	rs1;
wire [`REG_ID_BIT-1:0]    	rs2;
wire [31:0]               	imm;
wire [31:0]               	inst_pc;
wire                      	j;
wire                      	k;
wire [31:0]               	vj;
wire [31:0]               	vk;
wire [`ROB_WIDTH_BIT-1:0] 	qj;
wire [`ROB_WIDTH_BIT-1:0] 	qk;
wire                      	to_rob;
wire [`REG_ID_BIT-1:0]    	dest;
wire [31:0]               	rob_pc;
wire                      	rob_guess;
wire                      	to_rs;
wire                      	to_lsb;
wire [5:0]                	lsb_op;
wire [31:0]               	lsb_imm;

Decoder u_Decoder(
  .clk_in           	( clk_in            ),
  .rst_in           	( rst_in            ),
  .rdy_in           	( rdy_in            ),
  .valid            	( valid             ),
  .pc               	( pc_to_decoder     ),
  .inst             	( inst              ),
  .op_type          	( op_type           ),
  .rd               	( rd                ),
  .rs1              	( rs1               ),
  .rs2              	( rs2               ),
  .imm              	( imm               ),
  .inst_pc          	( inst_pc           ),
  .j                	( j                 ),
  .k                	( k                 ),
  .vj               	( vj                ),
  .vk               	( vk                ),
  .qj               	( qj                ),
  .qk               	( qk                ),
  .rs1_busy         	( rs1_busy          ),
  .rs2_busy         	( rs2_busy          ),
  .rs1_value        	( rs1_value         ),
  .rs2_value        	( rs2_value         ),
  .rs1_re           	( rs1_re            ),
  .rs2_re           	( rs2_re            ),
  .rob_full         	( rob_full          ),
  .rob_free_id      	( rob_free_id       ),
  .rob_rs1_is_ready 	( rob_rs1_is_ready  ),
  .rob_rs2_is_ready 	( rob_rs2_is_ready  ),
  .rob_rs1_value    	( rob_rs1_value     ),
  .rob_rs2_value    	( rob_rs2_value     ),
  .to_rob           	( to_rob            ),
  .dest             	( dest              ),
  .rob_pc           	( rob_pc            ),
  .rob_guess        	( rob_guess         ),
  .rs_full          	( rs_full           ),
  .to_rs            	( to_rs             ),
  .lsb_full         	( lsb_full          ),
  .to_lsb           	( to_lsb            ),
  .lsb_op           	( lsb_op            ),
  .lsb_imm          	( lsb_imm           )
);

// outports wire
wire                      	rob_full;
wire [`ROB_WIDTH_BIT-1:0] 	rob_free_id;
wire                      	rob_rs1_is_ready;
wire                      	rob_rs2_is_ready;
wire [31:0]               	rob_rs1_value;
wire [31:0]               	rob_rs2_value;

ROB u_ROB(
  .clk_in           	( clk_in            ),
  .rst_in           	( rst_in            ),
  .rdy_in           	( rdy_in            ),
  .to_rob           	( to_rob            ),
  .pc               	( inst_pc           ),
  .op_type          	( op_type           ),
  .rd               	( rd                ),
  .rs1              	( rs1               ),
  .rs2              	( rs2               ),
  .imm              	( imm               ),
  .inst_pc          	( inst_pc           ),
  .rob_full         	( rob_full          ),
  .rob_free_id      	( rob_free_id       ),
  .reoder_1         	( rs1_re            ),
  .reoder_2         	( rs2_re            ),
  .rob_rs1_is_ready 	( rob_rs1_is_ready  ),
  .rob_rs2_is_ready 	( rob_rs2_is_ready  ),
  .rob_rs1_value    	( rob_rs1_value     ),
  .rob_rs2_value    	( rob_rs2_value     )
);

// outports wire
wire                      	is_busy;
wire [31:0]               	out_value;
wire [`ROB_WIDTH_BIT-1:0] 	reorder;
wire                      	rs1_busy;
wire                      	rs2_busy;
wire [31:0]               	rs1_value;
wire [31:0]               	rs2_value;
wire [`ROB_WIDTH_BIT-1:0] 	rs1_re;
wire [`ROB_WIDTH_BIT-1:0] 	rs2_re;

regfile u_regfile(
  .clk_in    	( clk_in     ),
  .rst_in    	( rst_in     ),
  .rdy_in    	( rdy_in     ),
  .reg_id    	( reg_id     ),
  .write_en   ( write_en   ),
  .in_rob    	( in_rob     ),
  .value     	( value      ),
  .rob_id    	( rob_id     ),
  .is_busy   	( is_busy    ),
  .out_value 	( out_value  ),
  .reorder   	( reorder    ),
  .rs1       	( rs1        ),
  .rs2       	( rs2        ),
  .rs1_busy  	( rs1_busy   ),
  .rs2_busy  	( rs2_busy   ),
  .rs1_value 	( rs1_value  ),
  .rs2_value 	( rs2_value  ),
  .rs1_re    	( rs1_re     ),
  .rs2_re    	( rs2_re     )
);

// outports wire
wire                      	rs_full;
wire                      	has_result;
wire [31:0]               	value;
wire [`REG_ID_BIT-1:0]    	dest_out;
wire [31:0]               	new_PC;

RS u_RS(
  .clk_in     	( clk_in      ),
  .rst_in     	( rst_in      ),
  .rdy_in     	( rdy_in      ),
  .rs_full    	( rs_full     ),
  .to_rs      	( to_rs       ),
  .op_type    	( op_type     ),
  .j_in       	( j           ),
  .k_in       	( k           ),
  .vj_in      	( vj          ),
  .vk_in      	( vk          ),
  .qj_in      	( qj          ),
  .qk_in      	( qk          ),
  .dest_in    	( dest        ),
  .imm_in     	( imm         ),
  .inst_pc    	( inst_pc     ),
  .has_result 	( has_result  ),
  .value      	( value       ),
  .dest_out   	( dest_out    ),
  .new_PC     	( new_PC      )
);

// outports wire
wire                      	lsb_full;
wire                      	go_work;
wire                      	l_or_s;
wire [2:0]                	width;
wire [31:0]               	address_from_lsb;
wire [31:0]               	value_store;
wire                      	lsb_to_rob;
wire [`ROB_WIDTH_BIT-1:0] 	rob_id;
wire [31:0]               	value;

lsb u_lsb(
  .clk_in      	( clk_in       ),
  .rst_in      	( rst_in       ),
  .rdy_in      	( rdy_in       ),
  .lsb_full    	( lsb_full     ),
  .task_in     	( to_lsb      ),
  .op_type     	( op_type      ),
  .vj_in       	( vj           ),
  .vk_in       	( vk           ),
  .qj_in       	( qj           ),
  .qk_in       	( qk           ),
  .j_in        	( j            ),
  .k_in        	( k            ),
  .imm_in      	( imm          ),
  .inst_pc_in  	( inst_pc      ),
  .dest_in     	( dest         ),
  .received    	( received     ),
  .has_result  	( has_result   ),
  .value_load  	( value_load   ),
  .go_work     	( go_work      ),
  .l_or_s      	( l_or_s       ),
  .width       	( width        ),
  .address     	( address_from_lsb),
  .value_store 	( value_store  ),
  .lsb_to_rob  	( lsb_to_rob   ),
  .rob_id      	( rob_id       ),
  .value       	( value        )
);


// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule