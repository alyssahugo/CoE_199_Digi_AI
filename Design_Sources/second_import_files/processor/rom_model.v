`timescale 1ns / 1ps

module rom_model #(
    parameter ADDR_BITS = 16,
    parameter DEPTH = 65536
)(
    input  wire                 clk,
    input  wire                 ena,
    input  wire [ADDR_BITS-1:0] addra,
    output reg  [31:0]          douta
);

    reg [31:0] mem [0:DEPTH-1];

    initial begin
        $readmemh("instmem_hex.mem", mem);
    end

    always @(posedge clk) begin
        if (ena)
            douta <= mem[addra];
    end

endmodule