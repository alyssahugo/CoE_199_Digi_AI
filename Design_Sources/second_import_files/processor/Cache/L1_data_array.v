`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/31/2024 09:18:27 AM
// Design Name: 
// Module Name: data_array
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: The top-level containing all data_mem_way depending on the number of ways. Interfaced with the cache controller and
//              outside the cache  (refills and eviction controllers)
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module L1_data_array
    #(
    parameter CACHE_WAY = 4,
    parameter INDEX_BITS = 3
    )
    (
    input   clk,
    input                       i_rd,
    input                       i_wr,
    input [INDEX_BITS-1:0]      i_index,
    input [1:0]                 i_offset,
    input [3:0]                 i_dm_write,
    input                       i_data_from_mem_valid,
    input [31:0]                i_data_from_core,
    input [127:0]               i_data_from_mem,
    input [CACHE_WAY-1:0]       i_way,              // one hot encoding from Tag Array to point which way has data block
    input [CACHE_WAY-1:0]       i_LRU,
    input                       i_flush,
    input [CACHE_WAY-1:0]       i_flush_pointer,
    
    output reg [31:0] o_data_to_core,
    output reg [127:0] o_block_to_mem,
    output reg [127:0] o_data_flush
    
    );
    
    reg [31:0] r_data_to_core;
    
    //reg [31:0] data_to_core;
    wire [127:0] out_blocks[CACHE_WAY-1:0]; // lots of wires 
    wire [31:0] data_out_from_way[CACHE_WAY-1:0];
    //assign o_data_to_core = data_to_core;
    genvar i;
    generate
        for (i = 0; i < CACHE_WAY; i = i + 1) begin: L1_data_mem_way
            L1_data_mem_way # (.INDEX_BITS(INDEX_BITS)) 
                data_mem_way_n (
                    .clk(clk),
                    .i_wr(i_wr),
                    .i_index(i_index),  .i_offset(i_offset),
                    .i_dm_write(i_dm_write),
                    .i_data_from_core(i_data_from_core), 
                    .i_data_from_mem_valid(i_data_from_mem_valid),
                    .i_data_from_mem(i_data_from_mem),
                    .i_am_LRU(i_LRU[i]),
                    .i_hit(i_way[i]),
                    .i_flush(i_flush),
                    .o_out_way(data_out_from_way[i]),
                    .o_block(out_blocks[i])
                );
        end
    endgenerate
    
    integer j;
    reg found_hit;
    always@(*) begin
        found_hit = 0;
        o_data_to_core = 0;
        for (j = 0; j < CACHE_WAY; j = j + 1) begin
            if (i_way[j] && !found_hit) begin
                found_hit = 1;
                o_data_to_core = data_out_from_way[j];
            end
        end
    end
    
    integer k;
    reg found_lru;
    always@(*) begin
        found_lru = 0;
        for (k = 0; k < CACHE_WAY; k = k + 1) begin
            if (i_LRU[k] && !found_lru) begin
                found_lru = 1;
                o_block_to_mem = out_blocks[k];
            end
        end
    end
    /*
    integer l;
    always@(*) begin
        for (l = 0; l < CACHE_WAY; l = l + 1 ) begin
            if (i_flush_pointer[l]) begin
                o_data_flush <= out_blocks[l];
            end
        end
    end
    */

    //always @ (posedge clk) r_data_to_core <= data_to_core; // methink we need to remove this to remove the pipeline
endmodule
