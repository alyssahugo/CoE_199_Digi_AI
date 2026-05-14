`timescale 1ns / 1ps

`include "constants.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2025 03:39:02 PM
// Design Name: 
// Module Name: arbitration_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A blocking arbitration unit with a basic round robin arbitration policy.
//              Blocks the an L1 cache's access to the L2 which helps ensure consistency and enforce memory ordering
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module arbitration_unit
    #
    (
    parameter ADDR_BITS = 12
    )
    (
    input clk,
    input nrst,
    
    
    // Core 1 signals and data
    input i_req_core_1, 
    input i_wr_req_core_1,
    input i_wr_core_1,
    input i_rd_core_1,
    input i_done_core_1,
    output reg o_grant_core_1,
    input [31:0] i_data_core_1,
    input [3:0] i_dm_write_core_1,
    input [`ADDR_BITS-1:0] i_addr_1,

    
    // Core 2 signals and data
    input i_req_core_2,
    input i_wr_req_core_2,
    input i_wr_core_2,
    input i_rd_core_2,
    input i_done_core_2,
    output reg o_grant_core_2,
    input [31:0] i_data_core_2,
    input [3:0] i_dm_write_core_2,
    input [`ADDR_BITS-1:0] i_addr_2,
    
    // output to L2 Cache
    output reg [`ADDR_BITS-1:0] o_addr,
    output reg o_wr,
    output reg o_rd,
    output reg [3:0] o_dm_write,
    output reg [31:0] o_data
    );
    
     // Implement an arbitration module
    // Signals
    // req_core_n - request signal from Core 1 or 2
    // grant_core_n - grant signal to Core 1 or 2
    // done_core_n - done signal from Core 1 or 2 
    
    // Arbitration strategy: Round Robin style (easiest and simplest)
    // per clock cycle, if there are no requests, cycle through the two cores giving each a fair chance
    
    reg current_grant; // 0 - grant core 1;     1 - grant core 2
    
    initial begin
    
        current_grant <= 0;
    
    end
    
    always @ (posedge clk) begin
        if (!nrst) begin
            current_grant <= 0;
            o_grant_core_1 <= 0;
            o_grant_core_2 <= 0;
            o_addr <= 0;
            o_wr <= 0;
            o_rd <= 0;
            o_dm_write <= 0;
            o_data <= 0;
            
            
        end else begin
        
            case (current_grant) 
                0: begin 
                    // Core 1 has grant
                    if (i_req_core_1 || i_wr_req_core_1) begin // core 1 is requesting while core 1 is given grant
                        
                        o_grant_core_1 <= 1;
                        o_grant_core_2 <= 0;
                        o_addr <= i_addr_1;
                        o_dm_write <= i_dm_write_core_1;
                        o_data <= i_data_core_1;
                        o_wr <= i_wr_req_core_1;
                        o_rd <= i_req_core_1;
                        
                        
                        if (i_done_core_1) begin
                            current_grant <= 1;
                            
                            o_grant_core_1 <= 0;
                            o_wr <= 0;
                            o_rd <= 0;
                        end
                    end else if (i_req_core_2 || i_wr_req_core_2) begin
                        // Core 2 requests instead,
                        o_grant_core_2 <= 1;
                        o_grant_core_1 <= 0;
                        
                        o_addr <= i_addr_2;
                        o_dm_write <= i_dm_write_core_2;
                        o_data <= i_data_core_2;
                        o_wr <= i_wr_req_core_2;
                        o_rd <= i_req_core_2;
                        current_grant <= 1;
                    end else begin 
                        // No cores are requesting
                        current_grant <= current_grant;
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 0;
                        o_wr <= 0;
                        o_rd <= 0;
                        o_addr <= o_addr;
                        o_dm_write <= o_dm_write;
                        o_data <= o_data;

                    end
                   
                end
                
                
                1: begin
                    // Core 2 has grant
                    if (i_req_core_2 || i_wr_req_core_2) begin

                        o_grant_core_2 <= 1;
                        o_grant_core_1 <= 0;
                        o_addr <= i_addr_2;
                        o_dm_write <= i_dm_write_core_2;
                        o_data <= i_data_core_2;
                        o_wr <= i_wr_req_core_2;
                        o_rd <= i_req_core_2;
                        
                        if (i_done_core_2) begin
                           
                            current_grant <= 0;
                            o_grant_core_2 <= 0;
                            o_wr <= 0;
                            o_rd <= 0;
                        end
                    end else if (i_req_core_1 || i_wr_req_core_1) begin
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 1;
                        current_grant <= 0;
                        
                        o_addr <= i_addr_1;
                        o_dm_write <= i_dm_write_core_1;
                        o_data <= i_data_core_1;
                        o_wr <= i_wr_req_core_1;
                        o_rd <= i_req_core_1;
                    end else begin
                        current_grant <= current_grant;
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 0;
                        o_wr <= 0;
                        o_rd <= 0;
                        o_addr <= o_addr;
                        o_dm_write <= o_dm_write;
                        o_data <= o_data;

                    end
                    

                end
            endcase
        end
    end
endmodule
