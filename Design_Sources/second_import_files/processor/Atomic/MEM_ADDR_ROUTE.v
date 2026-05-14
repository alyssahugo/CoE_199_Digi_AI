`timescale 1ns / 1ps
`include "constants.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/25/2025 11:15:00 AM
// Design Name: 
// Module Name: MEM_ADDR_ROUTE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: If address falls into cacheable regions, then redirect the address and request to L1 Data Cache
//              Else if address falls into non-cacheable region, direc the address to OCM
//              Non-cacheable data: flags, locks, and protocol memory registers
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MEM_ADDR_ROUTE
    (
    input [31:0] i_addr,
    input [31:0] i_data,
    input  i_is_atomic,
    input [3:0] i_dm_write,
    input  i_wr,
    input  i_rd,
    
    
    // port to L1 Data Cache
    output reg [`ADDR_BITS-1:0] o_addr_to_cache,
    output reg o_atomic_lock_to_cache, // prolly will be unused
    output reg [3:0] o_dm_write_to_cache,
    output reg o_wr_to_cache,
    output reg o_rd_to_cache,
    output reg [31:0] o_data_to_cache,
    
    // port to OCM
    output reg [31:0] o_addr_to_OCM,
    output reg [3:0] o_dm_write_to_OCM,
    output reg o_atomic_lock_to_OCM,
    output reg o_wr_to_OCM,
    output reg o_rd_to_OCM,
    output reg [31:0] o_data_to_OCM, 
    
    output o_to_OCM,
    output o_to_cache
    );
    
    // Regions
    localparam NON_CACHEABLE_REGION_BASE = 32'h0000_0000; // Non cacheable region; Force all writes to noncache path
    // So anything above this is cacheable???    
    //
    
    reg to_OCM;
    wire to_cache;
    
    
    assign to_cache = ~to_OCM;
    assign o_to_OCM = to_OCM;
    assign o_to_cache = to_cache;
    
    always @ (*) begin
        if (i_addr >= NON_CACHEABLE_REGION_BASE && (i_rd || i_wr || i_is_atomic)) begin
            to_OCM <= 1;
        end else 
            to_OCM <= 0;
    end
    always @ (*) begin
        if (to_OCM) begin
            o_addr_to_OCM <= i_addr;
            o_wr_to_OCM <= i_wr;
            o_rd_to_OCM <= i_rd;
            o_dm_write_to_OCM <= i_dm_write;
            o_data_to_OCM <= i_data;

            
            o_addr_to_cache <= 0;
            o_dm_write_to_cache <= 0;
            o_wr_to_cache <= 0;
            o_rd_to_cache <= 0;
            o_data_to_cache <= 0;

        end
        else if (to_cache) begin
            o_addr_to_cache <= i_addr;
            o_dm_write_to_cache <= i_dm_write;
            o_wr_to_cache <= i_wr;
            o_rd_to_cache <= i_rd;
            o_data_to_cache <= i_data;

            
            o_addr_to_OCM <= 0;
            o_wr_to_OCM <= 0;
            o_rd_to_OCM <= 0;
            o_dm_write_to_OCM <= 0;
            o_data_to_OCM <= 0;

        end
    end
    
    
endmodule
