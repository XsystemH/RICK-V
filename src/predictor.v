module predictor #(
  parameter PREDICTOR_WIDTH = 5,
  parameter PREDICTOR_SIZE = 1 << PREDICTOR_WIDTH
) (
  input wire clk,
  input wire rst,
  input wire rdy,

  // with ifetch
  input wire [31:0] query_pc,
  output wire predict_result,

  input wire update,
  input wire [31:0] update_pc,
  input wire update_result
);

  reg [1:0] predictors[PREDICTOR_SIZE-1:0];
  integer i;

  assign predict_result = predictors[query_pc[PREDICTOR_WIDTH:1]] >= 2'b10;

  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < PREDICTOR_SIZE; i = i + 1) begin
        predictors[i] <= 2'b01;
      end
    end else if (!rdy) begin
      // pause
    end else begin
      if (update) begin
        if (update_result) begin // 1: taken
          case (predictors[update_pc[PREDICTOR_WIDTH:1]])
            2'b00: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b01;
            2'b01: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b10;
            2'b10: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b11;
            2'b11: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b11;
          endcase
        end else begin // 0: not taken
          case (predictors[update_pc[PREDICTOR_WIDTH:1]])
            2'b00: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b00;
            2'b01: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b00;
            2'b10: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b01;
            2'b11: predictors[update_pc[PREDICTOR_WIDTH:1]] <= 2'b10;
          endcase
        end
      end
    end
  end
    
endmodule //predictor
