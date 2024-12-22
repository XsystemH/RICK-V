// RISCV32 CPU top module
`include "const.v"
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

// memctrl
wire [31:0] 	value_load;
wire        	lsb_received;
wire        	lsb_task_out;
wire        	icache_received;
wire        	icache_task_out;

// icache
wire        	icache_to_memctrl;
wire [31:0] 	address_from_icache;
wire        	have_result;
wire [31:0] 	inst_from_icache;

// ifetch
wire          to_icache;
wire [31:0] 	pc_to_icache;
wire          to_decoder;
wire [31:0] 	inst;
wire [31:0] 	pc_to_decoder;
wire          query;
wire [31:0] 	pc_to_predictor;
wire          update;
wire [31:0] 	update_pc;
wire          update_result;
wire        	predict_result;

// predictor
wire        	predictor_result;

// decoder
wire [5:0]                	op_type;
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
wire [31:0]              	  next_pc;
wire                      	reorder_en;
wire [`REG_ID_BIT-1:0]    	reorder_reg;
wire [`ROB_WIDTH_BIT-1:0] 	reorder_id;

// rob
wire                      	rob_full;
wire [`ROB_WIDTH_BIT-1:0] 	rob_free_id;
wire                      	rob_rs1_is_ready;
wire                      	rob_rs2_is_ready;
wire [31:0]               	rob_rs1_value;
wire [31:0]               	rob_rs2_value;
wire                      	jalr_finish;
wire                      	branch_finish;
wire [31:0]               	pc_next;
wire [31:0]               	pc_branch;
wire                      	pre;
wire                      	ans;
wire [`ROB_WIDTH_BIT-1:0] 	rob_head;
wire                      	clear_all;
wire                      	write_en;
wire [`ROB_WIDTH_BIT-1:0] 	reg_id;
wire [`REG_ID_BIT-1:0]    	rob_id;
wire [31:0]               	value_out;
wire                      	HALT;

// regfile
wire                      	rs1_busy;
wire                      	rs2_busy;
wire [31:0]               	rs1_value;
wire [31:0]               	rs2_value;
wire [`ROB_WIDTH_BIT-1:0] 	rs1_re;
wire [`ROB_WIDTH_BIT-1:0] 	rs2_re;

// rs
wire                      	rs_full;
wire                      	rs_to_rob;
wire [31:0]               	rs_value;
wire [`REG_ID_BIT-1:0]    	rs_dest;
wire [31:0]               	rs_new_PC;

// lsb
wire                      	lsb_full;
wire                      	go_work;
wire                      	l_or_s;
wire [2:0]                	width;
wire [31:0]               	address_from_lsb;
wire [31:0]               	value_store;
wire                      	lb_to_rob;
wire [`ROB_WIDTH_BIT-1:0] 	lb_rob_id;
wire [31:0]               	lb_value;
wire                      	sb_to_rob;
wire [`ROB_WIDTH_BIT-1:0] 	sb_rob_id;

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
  .icache_task_out   	( icache_task_out    ),
  .HALT             	( HALT               )
);

icache #(
  .CACHE_WIDTH 	( 3    ),
  .CACHE_SIZE  	( 1<<3 ))
u_icache(
  .clk               	( clk_in             ),
  .rst               	( rst_in             ),
  .rdy               	( rdy_in             ),
  .received   	      ( icache_received    ),
  .memctrl_to_icache 	( icache_task_out    ),
  .inst_in           	( value_load         ),
  .icache_to_memctrl 	( icache_to_memctrl  ),
  .address           	( address_from_icache),
  .to_icache         	( to_icache          ),
  .pc                	( pc_to_icache       ),
  .have_result       	( have_result        ),
  .inst              	( inst_from_icache   )
);

ifetch u_ifetch(
  .clk_in             	( clk_in              ),
  .rst_in             	( rst_in              ),
  .rdy_in             	( rdy_in              ),
  .to_icache          	( to_icache           ),
  .pc_to_icache       	( pc_to_icache        ),
  .have_result        	( have_result         ),
  .inst_from_icache   	( inst_from_icache    ),
  .to_decoder      	    ( to_decoder          ),
  .inst               	( inst                ),
  .pc_to_decoder      	( pc_to_decoder       ),
  .predict_result     	( predict_result      ),
  .received           	( to_rob              ),
  .next_pc            	( next_pc             ),
  .query              	( query               ),
  .pc_to_predictor    	( pc_to_predictor     ),
  .update             	( update              ),
  .update_pc          	( update_pc           ),
  .update_result      	( update_result       ),
  .predict            	( predictor_result    ),
  .jalr_finish        	( jalr_finish         ),
  .branch_finish      	( branch_finish       ),
  .next_pc_from_rob   	( pc_next             ),
  .branch_pc_from_rob 	( pc_branch           ),
  .prejudge           	( pre                 ),
  .branch_result      	( ans                 )
);

predictor #(
  .PREDICTOR_WIDTH 	( 3                   ),
  .PREDICTOR_SIZE  	( 1<<3                ))
u_predictor(
  .clk            	( clk_in          ),
  .rst            	( rst_in          ),
  .rdy            	( rdy_in          ),
  .query          	( query           ),
  .query_pc       	( pc_to_predictor ),
  .predict_result 	( predictor_result),
  .update         	( update          ),
  .update_pc      	( update_pc       ),
  .update_result  	( update_result   )
);

decoder u_decoder(
  .clk_in           	( clk_in            ),
  .rst_in           	( rst_in            ),
  .rdy_in           	( rdy_in            ),
  .to_decoder       	( to_decoder        ),
  .pc               	( pc_to_decoder     ),
  .inst             	( inst              ),
  .predict          	( predictor_result  ),
  .next_pc          	( next_pc           ),
  .op_type          	( op_type           ),
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
  .reorder_en       	( reorder_en        ),
  .reorder_reg      	( reorder_reg       ),
  .reorder_id       	( reorder_id        )
);

rob u_rob(
  .clk_in           	( clk_in            ),
  .rst_in           	( rst_in            ),
  .rdy_in           	( rdy_in            ),
  .to_rob           	( to_rob            ),
  .pc               	( inst_pc           ),
  .op_type          	( op_type           ),
  .rd               	( dest              ),
  .rs1              	( rs1               ),
  .rs2              	( rs2               ),
  .imm              	( imm               ),
  .inst_pc          	( inst_pc           ),
  .predictor_result 	( predictor_result  ),
  .rob_full         	( rob_full          ),
  .rob_free_id      	( rob_free_id       ),
  .reoder_1         	( rs1_re            ),
  .reoder_2         	( rs2_re            ),
  .rob_rs1_is_ready 	( rob_rs1_is_ready  ),
  .rob_rs2_is_ready 	( rob_rs2_is_ready  ),
  .rob_rs1_value    	( rob_rs1_value     ),
  .rob_rs2_value    	( rob_rs2_value     ),
  .jalr_finish      	( jalr_finish       ),
  .branch_finish    	( branch_finish     ),
  .pc_next          	( pc_next           ),
  .pc_branch        	( pc_branch         ),
  .pre              	( pre               ),
  .ans              	( ans               ),
  .rob_head         	( rob_head          ),
  .clear_all        	( clear_all         ),
  .rs_to_rob        	( rs_to_rob         ),
  .rs_value         	( rs_value          ),
  .rs_dest          	( rs_dest           ),
  .jalr_pc          	( rs_new_PC         ),
  .lb_to_rob       	  ( lb_to_rob         ),
  .lb_value        	  ( lb_value          ),
  .lb_dest         	  ( lb_rob_id         ),
  .sb_to_rob       	  ( sb_to_rob         ),
  .sb_dest         	  ( sb_rob_id         ),
  .write_en         	( write_en          ),
  .reg_id           	( reg_id            ),
  .rob_id           	( rob_id            ),
  .value_out        	( value_out         ),
  .HALT             	( HALT              )
);

regfile u_regfile(
  .clk_in    	( clk_in     ),
  .rst_in    	( rst_in     ),
  .rdy_in    	( rdy_in     ),
  .reorder_en ( reorder_en  ),
  .reorder_reg( reorder_reg),
  .reorder_id	( reorder_id ),
  .write_en  	( write_en   ),
  .reg_id    	( reg_id     ),
  .rob_id    	( rob_id     ),
  .value     	( value_out  ),
  .rs1       	( rs1        ),
  .rs2       	( rs2        ),
  .rs1_busy  	( rs1_busy   ),
  .rs2_busy  	( rs2_busy   ),
  .rs1_value 	( rs1_value  ),
  .rs2_value 	( rs2_value  ),
  .rs1_re    	( rs1_re     ),
  .rs2_re    	( rs2_re     )
);

rs u_rs(
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
  .dest_in    	( reorder_id  ),
  .imm_in     	( imm         ),
  .inst_pc    	( inst_pc     ),
  .rs_to_rob 	  ( rs_to_rob   ),
  .value      	( rs_value    ),
  .dest_out   	( rs_dest     ),
  .lsb_to_rs  	( lb_to_rob   ),
  .lsb_rob_id 	( lb_rob_id   ),
  .lsb_value	  ( lb_value    ),
  .new_PC     	( rs_new_PC   )
);

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
  .dest_in     	( reorder_id   ),
  .received    	( lsb_received ),
  .has_result  	( lsb_task_out ),
  .value_load  	( value_load   ),
  .go_work     	( go_work      ),
  .l_or_s      	( l_or_s       ),
  .width       	( width        ),
  .address     	( address_from_lsb),
  .value_store 	( value_store  ),
  .rob_head    	( rob_head     ),
  .lb_to_rob  	( lb_to_rob    ),
  .load_id     	( lb_rob_id    ),
  .value       	( lb_value     ),
  .sb_to_rob   	( sb_to_rob    ),
  .store_id    	( sb_rob_id    )
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

// integer t = 0;
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
      // $display("clk=%d", t);
      // t = t + 1;
      end
  end

endmodule