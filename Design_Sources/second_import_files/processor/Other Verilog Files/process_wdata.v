`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2025 10:03:58 AM
// Design Name: 
// Module Name: process_wdata
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A test module to see if i can preprocess the wdata before connecting it to the slave AXI
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module process_wdata(
    input [31:0] data_i,
    output [31:0] data_o
    );
    
    
    assign data_o =  {28'h0, data_i[31:24]};
endmodule
