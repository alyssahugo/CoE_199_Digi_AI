`timescale 1ns / 1ps

module ram_dp_model #(
    parameter ADDR_BITS = 16,
    parameter DEPTH = 65536
)(
    // Port A = write
    input  wire                 clka,
    input  wire                 ena,
    input  wire                 wea,
    input  wire [ADDR_BITS-1:0] addra,
    input  wire [31:0]          dina,

    // Port B = read
    input  wire                 clkb,
    input  wire                 enb,
    input  wire [ADDR_BITS-1:0] addrb,
    output reg  [31:0]          doutb
);

    reg [31:0] mem [0:DEPTH-1];

    always @(posedge clka) begin
        if (ena && wea)
            mem[addra] <= dina;
    end

    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end

endmodule