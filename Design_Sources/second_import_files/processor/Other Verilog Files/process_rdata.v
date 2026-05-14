`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/28/2025 07:59:48 AM
// Design Name: 
// Module Name: process_rdata
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


module process_rdata(
    input [31:0] data_i,
    output [31:0] data_o
    );
    
    assign data_o = {data_i[7:0], data_i[15:8], data_i[23:16], data_i[31:24]};
endmodule
