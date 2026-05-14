`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.03.2026 15:35:39
// Design Name: 
// Module Name: refill_pointer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//`timescale 1ns / 1ps

//module instmem_write_ptr
//#(
//    parameter ADDR_BITS = 16
//)
//(
//    input  wire                 clk,
//    input  wire                 nrst,
//    input  wire                 write_advance,
//    output reg  [ADDR_BITS-1:0] write_addr
//);

//    always @(posedge clk) begin
//        if (!nrst)
//            write_addr <= {ADDR_BITS{1'b0}};
//        else if (write_advance)
//            write_addr <= write_addr + 1'b1;
//    end

//endmodule

`timescale 1ns / 1ps

module instmem_write_ctrl
#(
    parameter ADDR_BITS = 16
)
(
    input  wire                 clk,
    input  wire                 nrst,
    input  wire                 src_valid,

    output reg                  dst_valid,
    output reg  [ADDR_BITS-1:0] write_addr
);

    always @(posedge clk) begin
        if (!nrst) begin
            dst_valid  <= 1'b0;
            write_addr <= {ADDR_BITS{1'b0}};
        end else begin
            dst_valid <= src_valid;

            if (dst_valid)
                write_addr <= write_addr + 1'b1;
        end
    end

endmodule
