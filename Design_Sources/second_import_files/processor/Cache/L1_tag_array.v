`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/26/2024 12:39:02 PM
// Design Name: 
// Module Name: tag_array
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


module L1_tag_array #
    (
    parameter TAG_BITS = 20,
    parameter INDEX_BITS = 3,
    parameter CACHE_WAY = 2
    )
    
    (
    input clk,
    input nrst,
    
    input                               i_wr_en,            // Enable tag writes
    
    input [TAG_BITS-1:0]                i_tag,
    input [INDEX_BITS-1:0]              i_index,
    
    input [CACHE_WAY-1:0]               i_LRU_set,                  //  Expects a One hot encoding from the PLRU module
    
    input                               i_active_op,
    input                               i_done_state,

    // MESI protocol
    input [TAG_BITS-1:0]                i_snooping_tags,
    input [INDEX_BITS-1:0]              i_snooping_index,
    input                               i_invalidate,
    input                               i_reserve_exclusive,
    input                               i_to_shared,
    /*
    
    
    input                               i_modify,
    output reg [1:0]                    o_snooping_mesi,
    output reg [1:0]                    o_own_mesi,
    */
    
    output wire [CACHE_WAY-1:0]         o_way,              // one hot encoding to tell which way was accessed to the Data Array
    output                              o_hit,
    output                              o_snoop_hit
    //output wire [TAG_BITS + 1:0]        o_LRU_set_tag_info,  // to Cache controller in case of eviction
    //output reg [TAG_BITS+1:0]           o_tag_info_flush
    );
    
    
    // generate the correct number tag memory
    // based on the CACHE_WAY parameter
    wire [CACHE_WAY-1:0] hit_bus; // the packed outputs of the tag_mems
    //wire [TAG_BITS+1:0] tag_output_mems[CACHE_WAY-1:0]; // output wires of tag infos for each tag mem
    //wire [TAG_BITS+1:0] tag_output_flush[CACHE_WAY-1:0];
    
    
    reg [TAG_BITS + 1:0] lru_tag;
    
    assign o_way = hit_bus;
    assign o_LRU_set_tag_info = lru_tag;
    assign o_hit = |hit_bus;
    
    //assign o_LRU_set_tag_info = LRU_set_tag_info;
    
    // Snooping protocol
    //wire [CACHE_WAY-1:0] snoop_match_bus;
    wire [CACHE_WAY-1:0] snoop_hit;
    //wire [1:0] snoop_mesi [CACHE_WAY-1:0];
    //wire [1:0] own_mesi [CACHE_WAY-1:0];
    assign o_snoop_hit = |snoop_hit;
    
    genvar i;
    
    generate
        // i feel like this got more complicated when i was trying to simplify things

        for (i = 0; i < CACHE_WAY; i = i + 1) begin: tag_mem_way
            
            L1_tag_mem #(.TAG_BITS(TAG_BITS), .INDEX_BITS(INDEX_BITS))
                small_tag_mem(
                    .clk(clk),  .nrst(nrst),
                    .i_wr_en(i_wr_en && i_LRU_set[i]), .i_tag(i_tag), .i_index(i_index),
                    .i_active_op(i_active_op),
                    .i_am_LRU(i_LRU_set[i]),
                    .o_hit(hit_bus[i]),
                    .i_invalidate(i_invalidate),
                    .i_reserve_exclusive(i_reserve_exclusive),
                    .i_to_shared(i_to_shared),
                    
                    .i_done_state(i_done_state),
                    .i_snoop_tags(i_snooping_tags),
                    .i_snoop_index(i_snooping_index),
                    
                    .o_snoop_hit(snoop_hit[i])
                    //.o_tag(tag_output_mems[i]), 
                    /*
                    
                    
                    .i_modify(i_modify && hit_bus[i]), 
                    
                    
                    //.o_snoop_match(snoop_match_bus[i]),
                    
                    .o_snooping_mesi(snoop_mesi[i])
                    .o_own_mesi(own_mesi[i])
                    //.o_tag_flush(tag_output_flush[i])
                    */
                );
                
        end
        
        
        
    endgenerate
    /*
    integer j;
    reg found;
    always @ (*) begin
        lru_tag = 0;
        found = 1'b0;
        for (j=0; j < CACHE_WAY; j = j + 1) begin
            if (i_LRU_set[j] == 1'b1 && !found) begin
                found = 1'b1;
                lru_tag = tag_output_mems[j];

            end 
        end
    end
    
    integer k;
    reg found_snoop;
    always @(*) begin
        found_snoop = 0;
        o_snooping_mesi = 0;
        for (k = 0; k < CACHE_WAY; k = k + 1) begin
            if (snoop_hit[k] == 1 && !found_snoop) begin
                o_snooping_mesi = snoop_mesi[k];
                found_snoop = 1;
            end
        end
    end
    
    integer l;
    always @ (*) begin
        o_own_mesi = 0;
        for (l = 0; l < CACHE_WAY; l = l + 1) begin
            if (hit_bus[l] == 1) o_own_mesi <= own_mesi[l];
        end
    end
    /*
    integer k;
    always @ (*) begin
        for (k=0; k < CACHE_WAY; k = k + 1) begin
            if (i_flush_pointer[k]) begin
                o_tag_info_flush = tag_output_flush[k];
            end 
        end
    end
    */
    
endmodule
