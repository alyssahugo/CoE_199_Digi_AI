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


module core_nreset_new(    
    input bootload_inst_done,
    input bootload_data_done,
    input init_calib_complete,
    output core_nreset
    );

    assign core_nreset =
        bootload_inst_done &
        bootload_data_done &
        init_calib_complete;

endmodule
