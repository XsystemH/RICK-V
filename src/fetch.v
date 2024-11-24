`include "const.v"

module ifetch(
  input wire clk_in,
  input wire rst_in, // reset when high
  input wire rdy_in, // pause when low

  // Decoder
  input wire pc,
  output wire [31:0] inst,

  // memory
  output wire [31:0] addr,
  input wire [31:0] data
);

endmodule //ifetch