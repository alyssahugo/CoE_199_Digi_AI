`timescale 1ns / 1ps
`include "constants.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/21/2025 07:41:59 PM
// Design Name: 
// Module Name: mux_for_tb
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


module mux_for_tb(
    input done,
    output reg [`ADDR_BITS-1:0] addr_o,
    input [`ADDR_BITS-1:0] addr_i_from_prog,
    input [`ADDR_BITS-1:0] addr_i_from_ak
    );
    
    always @ (*) begin
        if (done) 
            addr_o <= addr_i_from_ak;
        else
            addr_o <= addr_i_from_prog;
    end
    
    
endmodule
