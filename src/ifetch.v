`include "const.v"

module ifetch(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // to icache
  output reg to_icache,
  output reg [31:0] pc_to_icache,
  // from icache
  input wire have_result,
  input wire [31:0] inst_from_icache,

  // to decoder
  output reg to_decoder,
  output reg [31:0] inst,
  output reg [31:0] pc_to_decoder,
  output reg predict_result,
  // from decoder
  input wire received, // from rob&decoder, fetch next instr when received
  input wire [31:0] next_pc,

  // to predictor
  output reg query,
  output reg [31:0] pc_to_predictor,
  output reg update,
  output reg [31:0] update_pc,
  output reg update_result,
  // from predictor
  input wire predict,

  // from rob
  input wire jalr_finish,
  input wire branch_finish,
  input wire [31:0] next_pc_from_rob,
  input wire [31:0] branch_pc_from_rob,
  input wire prejudge,
  input wire branch_result
);
  localparam CodeLui = 7'b0110111, CodeAupic = 7'b0010111, CodeJal = 7'b1101111;
  localparam CodeJalr = 7'b1100111, CodeBr = 7'b1100011, CodeLoad = 7'b0000011;
  localparam CodeStore = 7'b0100011, CodeArithR = 7'b0110011, CodeArithI = 7'b0010011;

  reg [2:0] state; // 0 IDEL 1 WAITING FOR ICACHE 2 WAITING FOR PREDICTOR 3 WAITING FOR ROB 4 SENT WRONG PC
  reg [31:0] pc;
  reg [31:0] inst_temp;

  // if opcode is jal/branch, calculate next pc
  // - jar, modify pc
  // - branch, 1 cycle stall to get guess
  // - jalr, stall until address is ready
  wire [6:0] opcode = inst_from_icache[6:0];

  always @(posedge clk_in) begin
    if (rst_in) begin
      to_decoder <= 0;
      pc = 0;
      state <= 0;
      inst_temp <= 0;
      to_icache <= 0;
      pc_to_icache <= 0;
      inst <= 0;
      predict_result <= 0;
      pc_to_predictor <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (received && state != 4) begin
        pc = next_pc;
      end
      if (branch_finish) begin
        if (prejudge != branch_result) begin
          // $display("branch mispredicted");
          pc = next_pc_from_rob;
          to_decoder <= 0;
          state <= 4;
        end

        // predictor update
        query <= 0;
        update <= 1;
        update_pc <= branch_pc_from_rob;
        update_result <= branch_result;
      end

      if (state == 0) begin
        // $display("query: %h", pc);
        to_decoder <= 0;
        to_icache <= 1;
        pc_to_icache <= pc;
        inst <= 0;
        state <= 1;
      end else if (state == 1) begin // waiting for icache
        if (have_result) begin
          case (opcode)
            CodeJal: begin
              // $display("pc: %h inst: %h, jal", pc, inst_from_icache);
              to_decoder <= 1;
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              query <= 0;
              state <= 0;
            end
            CodeJalr: begin
              // $display("pc: %h inst: %h, jalr", pc, inst_from_icache);
              to_decoder <= 1;
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              query <= 0;
              state <= 3;
            end
            CodeBr: begin
              // $display("pc: %h inst: %h, branch", pc, inst_from_icache);
              to_decoder <= 0;
              inst <= 0; // empty
              inst_temp <= inst_from_icache;
              pc_to_predictor <= pc;
              query <= 1;
              state <= 2;
            end
            default: begin
              // $display("pc: %h inst: %h, default", pc, inst_from_icache);
              to_decoder <= 1;
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              query <= 0;
              state <= 0;
            end
          endcase
          to_icache <= 0;
        end else begin
          to_decoder <= 0;
          inst <= 0;
          to_icache <= 0;
        end

      end else if (state == 2) begin // waitied a cycle for predictor
        to_decoder <= 1;
        inst <= inst_temp;
        pc_to_decoder <= pc;
        predict_result <= predict;

        state <= 0;
      end else if (state == 3) begin // waited for rob
        to_decoder <= 0;
        inst <= 0;
        if (branch_finish && prejudge != branch_result) begin
          state <= 0;
        end else if (jalr_finish) begin
          pc = next_pc_from_rob;
          state <= 0;
        end
      end else if (state == 4) begin // sent wrong pc
        if (have_result) begin // got a wrong inst
          // $display("misunderstood fixed");
          to_decoder <= 0;
          state <= 0;
        end
      end
    end
  end

endmodule //ifetch