`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2025 10:40:46 AM
// Design Name: 
// Module Name: tb_bootloading
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


module tb_bootloading(

    );
    
    reg clk, nrst;
    
   
    wire uart_txd;
    wire [31:0] probe_mem_ALUout;
    wire [31:0] probe_datastore;
    rv32imc_single_wrapper UUT(
           .clk(clk),
           .nrst(nrst),
           .rs232_uart_rxd(1),
           .rs232_uart_txd(uart_txd),
           .probe_data_addr(probe_mem_ALUout),
           .probe_datastore(probe_datastore)
    );
    
    
    always #10 clk = ~clk;
    initial begin
        clk = 0;
        nrst = 0;
        #200
        nrst = 1;
        
    end
    

endmodule
