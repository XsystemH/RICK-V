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
  output reg [31:0] inst,
  output reg [31:0] pc_to_decoder,
  output reg predict_result,
  // from decoder
  input wire received, // from rob?

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

  reg [1:0] state; // 0 IDEL 1 WAITING FOR ICACHE 2 WAITING FOR PREDICTOR 3 WAITING FOR ROB
  reg [31:0] pc;
  reg [31:0] inst_temp;

  // if opcode is jal/branch, calculate next pc
  // - jar, modify pc
  // - branch, 1 cycle stall to get guess
  // - jalr, stall until address is ready
  wire [6:0] opcode = inst[6:0];
  // jal
  wire [31:0] jal_imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
  wire [31:0] jal_pc = pc + jal_imm;
  // branch
  wire [31:0] branch_imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] branch_pc = pc + branch_imm;

  always @(posedge clk_in) begin
    if (rst_in) begin
      to_icache <= 0;
      pc_to_icache <= 0;
      inst <= 0;
      predict_result <= 0;
      pc_to_predictor <= 0;
    end else if (!rdy_in) begin
      // pause
    end else begin
      if (state == 0) begin
        to_icache <= 1;
        pc_to_icache <= pc;
        inst <= 0;
        state <= 1;
      end else if (state == 1) begin // waiting for icache
        if (have_result) begin
          case (opcode)
            CodeJal: begin
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              pc <= jal_pc;
              query <= 0;
              state <= 0;
            end
            CodeJalr: begin
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              query <= 0;
              state <= 3;
            end
            CodeBr: begin
              inst <= 0; // empty
              inst_temp <= inst_from_icache;
              pc_to_predictor <= pc;
              query <= 1;
              state <= 2;
            end
            default: begin
              inst <= inst_from_icache;
              pc_to_decoder <= pc;
              pc <= pc + 4;
              query <= 0;
              state <= 0;
            end
          endcase
        end // else wait for icache
      end else if (state == 2) begin // waitied a cycle for predictor
        inst <= inst_temp;
        pc_to_decoder <= pc;
        pc <= predict ? branch_pc : pc + 4;
        predict_result <= predict;

        state <= 0;
      end else if (state == 3) begin // waited for rob
        inst <= 0;
        if (jalr_finish) begin
          pc <= next_pc_from_rob;
          state <= 0;
        end
      end
      if (branch_finish) begin
        if (prejudge != branch_result) begin
          pc <= next_pc_from_rob;
        end
        state <= 0;

        // predictor update
        query <= 0;
        update <= 1;
        update_pc <= branch_pc_from_rob;
        update_result <= branch_result;
      end
    end
  end

endmodule //ifetch