`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2025 06:01:08 PM
// Design Name: 
// Module Name: bootloader
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:     This simple bootloader serves as a FSM that connects a Block ROM containing the instruction data
//                  and the INSTMEM; At nrst, begins the transfer of the instruction to the INSTMEM. Additionally
//                  locks the RISC-V Core until the transfer of the entire program is completed.
//                  
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bootloader
    #(
    parameter ADDR_BITS = 16
    )
    (
    input clk,
    input nrst,
    output reg bootload_done,   // core_reset holds the nrst for core. Until the bootloading is finish, the bootloader will block nrst so the core wont start
    output reg [ADDR_BITS-1:0] inst_addr,
    output reg valid, 
    output reg ena
    );
    
    localparam TOTAL_INSTRUCTIONS = 2 ** ADDR_BITS;
    
    // Depending on the latency of the Block ROM
    // Block ROM has 2 clock cycle latency
    // Match the timing using FSM
    reg [1:0] state;
    reg [1:0] cleanup_latency;  // Same as the read latency delay so we can ensure that the last instruction is written.
    reg [ADDR_BITS-1:0] instruction_counter;
    reg done;
    
    // Currently, INSTMEM is stored at [WORD_WIDTH-1:0] instmem[0:`MEM_DEPTH-1] 
    // Where `MEM_DEPTH is 4096
    // so we have 4096 words
    // The plan is to read addresses from 0 to `MEM_DEPTH
    
    always @ (posedge clk) begin
        if (!nrst) begin
            state <= 0;
            inst_addr <= 0;
            instruction_counter <= 0;
            cleanup_latency <= 0;
            valid <= 0;
            ena <= 0;
            done <= 0;
            bootload_done <= 0;
        end else begin
            case (state) 
                0: begin
                    state <= 1;
                    ena <= 1;
                end
                
                1: begin
                    state <= 2;
                    
                end
                
                2: begin
                    valid <= 1;
                    if (inst_addr == TOTAL_INSTRUCTIONS - 1) begin
                        done <= 1;
                        
                    end
                    //inst_addr <= inst_addr + 1;
                    if (done) state <= 3;
                end
                
                3: begin
                    valid <= 0;
                    state <= 3; //stay here we dont need to go back to state 1 after bootloading our job is done
                end
            endcase
            
            
            //if (valid) begin
            //    inst_addr <= inst_addr + 1;
            //    
            //end
            
            if (inst_addr == TOTAL_INSTRUCTIONS-1) begin
                done <= 1;
                
            end
            
            if (!valid && done) begin
                bootload_done <= 1;
            end
            
            if (ena) begin
                inst_addr <= inst_addr + 1;
            end
            
        end
            
        
    end
    
    
    
    
endmodule
