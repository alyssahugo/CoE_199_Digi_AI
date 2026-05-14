`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2025 05:39:54 PM
// Design Name: 
// Module Name: bram_addr
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


module bram_addr
    #(
    parameter ADDR_WIDTH = 12
    )
    (
    input [ADDR_WIDTH-1:0] addr_in_1,
    input [ADDR_WIDTH-1:0] addr_in_2,
    output [ADDR_WIDTH-1:0] addr_out_1,
    output [ADDR_WIDTH-1:0] addr_out_2 
    );
    
    assign addr_out_1 = {2'b00,addr_in_1[ADDR_WIDTH-1:2]};
    assign addr_out_2 = {2'b00,addr_in_2[ADDR_WIDTH-1:2]};
endmodule
