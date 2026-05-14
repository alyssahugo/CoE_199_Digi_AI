`timescale 1ns / 1ps
`include "constants.vh"

// Adapted from Xilinx-provided template
module single_port_rom #(
    //---------------------------------------------------------------
    parameter ADDR_WIDTH = `PC_ADDR_BITS-2, // Addr Width in bits :
     //2**ADDR_WIDTH = RAM Depth
    parameter DATA_WIDTH = `WORD_WIDTH, // Data Width in bits
    
    parameter INITIAL_DATA = "instmem.mem"
    //--------------------------------------------------------------
     ) (
        input clkA,
        input enaA,
        input [ADDR_WIDTH-1:0] addrA,
        output reg [DATA_WIDTH-1:0] doutA
      
    );
    // CORE_MEMORY
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
    
    integer i;
    initial begin
        for (i = 0; i < (2**ADDR_WIDTH); i=i+1) begin
	       ram_block[i] = `DEFAULT_FILL;
	    end
        $readmemh(INITIAL_DATA, ram_block);
    end
    
    integer i;
    // PORT-A Operation
    always @ (posedge clkA) begin
        if(enaA) begin
            doutA <= ram_block[addrA];
        end
        else begin
            doutA <= 32'd0;
        end
    end
endmodule
