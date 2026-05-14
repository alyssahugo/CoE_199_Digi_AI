`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2025 12:10:28 PM
// Design Name: 
// Module Name: 4_port_memory_construct
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Let's go full monke. This module contains two ideal two port BRAMs, which mirrors each other
//              That is, when we write on one port, we write on the other side
//              This is done so that we can achieve 4 port parallel reads.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module four_port_memory_construct #
    (
    parameter NUM_COL = 4,
    parameter COL_WIDTH = 8,
    parameter ADDR_WIDTH = 12, // Addr Width in bits :
     //2**ADDR_WIDTH = RAM Depth
    parameter DATA_WIDTH = NUM_COL*COL_WIDTH, // Data Width in bits
    
    parameter INITIAL_DATA = "testbench_datamem.mem"
    )
    (
    // Port A is for Refills
    input clkA,
    input enaA,
    input [NUM_COL-1:0] weA,
    input [ADDR_WIDTH-1:0] addrA,
    input [DATA_WIDTH-1:0] dinA,
    output reg [DATA_WIDTH-1:0] doutA,
    
    // Port B is for Evictions
    input clkB,
    input enaB,
    input [NUM_COL-1:0] weB,
    input [ADDR_WIDTH-1:0] addrB,
    input [DATA_WIDTH-1:0] dinB,
    output reg [DATA_WIDTH-1:0] doutB,
    
    // Port C is for Atomics
    input clkC,
    input enaC,
    input [NUM_COL-1:0] weC,
    input [ADDR_WIDTH-1:0] addrC,
    input [DATA_WIDTH-1:0] dinC,
    output reg [DATA_WIDTH-1:0] doutC,
    
    // Port D is for the Testbench
    input clkD,
    input enaD,
    input [NUM_COL-1:0] weD,
    input [ADDR_WIDTH-1:0] addrD,
    input [DATA_WIDTH-1:0] dinD,
    output reg [DATA_WIDTH-1:0] doutD
    
    
    );
    
     // CORE_MEMORY
    reg [DATA_WIDTH-1:0] ram_block_1 [(2**ADDR_WIDTH)-1:0];
    reg [DATA_WIDTH-1:0] ram_block_2 [(2**ADDR_WIDTH)-1:0];
    
    
    initial begin
        $readmemh(INITIAL_DATA, ram_block_1);
        $readmemh(INITIAL_DATA, ram_block_2);
        

    end
    
    integer i;
    // PORT-A Operation
    always @ (posedge clkA) begin
        if(enaA) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                if(weA[i]) begin
                    ram_block_1[addrA][i*COL_WIDTH +: COL_WIDTH] <= dinA[i*COL_WIDTH +: COL_WIDTH];
                    ram_block_2[addrA][i*COL_WIDTH +: COL_WIDTH] <= dinA[i*COL_WIDTH +: COL_WIDTH];
                end
            end
            doutA <= ram_block_1[addrA];
        end
    end
    
    // Port-B Operation:
    always @ (posedge clkB) begin
        if(enaB) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                if(weB[i]) begin
                    ram_block_1[addrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
                    ram_block_2[addrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
                end
            end
            doutB <= ram_block_1[addrB];
        end
    end
    
        // Port-C Operation:
    always @ (posedge clkC) begin
        if(enaC) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                if(weC[i]) begin
                    ram_block_1[addrC][i*COL_WIDTH +: COL_WIDTH] <= dinC[i*COL_WIDTH +: COL_WIDTH];
                    ram_block_2[addrC][i*COL_WIDTH +: COL_WIDTH] <= dinC[i*COL_WIDTH +: COL_WIDTH];
                end
            end
            doutC <= ram_block_2[addrC];
        end
    end
    
            // Port-C Operation:
    always @ (posedge clkD) begin
        if(enaD) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                if(weD[i]) begin
                    ram_block_1[addrD][i*COL_WIDTH +: COL_WIDTH] <= dinD[i*COL_WIDTH +: COL_WIDTH];
                    ram_block_2[addrD][i*COL_WIDTH +: COL_WIDTH] <= dinD[i*COL_WIDTH +: COL_WIDTH];
                end
            end
            doutD <= ram_block_2[addrD];
        end
    end
    
endmodule
