`timescale 1ns / 1ps

module inst_pipe_reg (
    input  wire        clk,
    input  wire        nrst,
    input  wire [31:0] din,
    output reg  [31:0] dout
);

    always @(posedge clk) begin
        if (!nrst)
            dout <= 32'd0;
        else
            dout <= din;
    end

endmodule