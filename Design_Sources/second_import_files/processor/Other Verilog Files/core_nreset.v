`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2025 07:30:03 PM
// Design Name: 
// Module Name: core_nreset
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


module core_nreset(
    input bootload_inst_done,
    input bootload_data_done,
    output core_nreset
    );
    
    assign core_nreset = bootload_inst_done & bootload_data_done;
    
endmodule
