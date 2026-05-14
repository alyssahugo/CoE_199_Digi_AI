`timescale 1ns / 1ps

`include "constants.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2025 09:16:09 AM
// Design Name: 
// Module Name: cache_top
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


module L1_cache_top
    /*
    #(
    
    parameter CACHE_WAY = 4,
    parameter CACHE_SIZE = 4096, // bytes
    parameter ADDR_BITS = 12,
    parameter OFFSET_BITS = 2,
    parameter BLOCK_SIZE = 16, // 16 bytes per one block (4 words), always
    parameter NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE,
    parameter NUM_SETS = NUM_BLOCKS / CACHE_WAY,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS - 2
    
    )
    */
    (
    input clk,
    input nrst,
    
    // Inputs from the RISCV core
	input [3:0]            i_dm_write,  // bytewise write
	input                  i_rd,
	input                  i_wr,
	input [`ADDR_BITS-1:0]  i_data_addr,
	input [31:0]           i_data,
	
	// Inputs from the L2 Cache
	input [127:0]          i_data_block_from_L2,
	input                  i_grant,    // grant from arbitration
	input                  i_data_valid,
	input                  i_data_wvalid,

	
	// Outputs to Core
	output [31:0]          o_data,	// data output to the RISC-V core
	output                 o_all_done,
	
	// Inputs and Outputs to the Snooping Controller of Other Core
	input  [`TAG_BITS-1:0]        i_ext_tags,
	input  [`INDEX_BITS-1:0]      i_ext_index,
	input                        i_ext_invalidate,
	input                        i_ext_reserve_exclusive,
	input                        i_ext_to_shared,
	
	//input                        i_data_check,
	

	output [`ADDR_BITS-1:0]       o_ext_addr,
	output                       o_scu_req,
	output                       o_scu_wr,
	output                       o_scu_hit,
	
	
	// Outputs to the L2 cache
	// pass the request
	output [3:0] o_dm_write,
	output o_wr,
	//output o_rd,
	output [31:0] o_wrdata_to_L2,
	output [`ADDR_BITS-1:0] o_addr,

    // Cache specific output
    output                 o_stall,
    output                 o_req_block,
    output                 o_req_wr

    );

    
    
    // PARAMETERS ///////////////////////////////////////////////////////////////
    // one word = 32-bits or 4 bytes
    /*
    localparam OFFSET_BITS = 2;
    localparam BLOCK_SIZE = 16; // 16 bytes per one block (4 words), always
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS = NUM_BLOCKS / CACHE_WAY;
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS - 2;
    */
    //////////////////////////////////////////////////////////////////////////////
    

    // ADDRESS PARSING ///////////////////////////////////////////////////////////
    wire [`OFFSET_BITS-1:0]  offset;
    wire [`TAG_BITS-1:0]     tags;
    wire [`INDEX_BITS-1:0]   index;
    // Send to snooping bus

    //////////////////////////////////////////////////////////////////////////////
    
    
    // WAY POINTERS //////////////////////////////////////////////////////////////
    wire [`CACHE_WAY-1:0] hit_way;
    wire [`CACHE_WAY-1:0] lru_way;   
    //////////////////////////////////////////////////////////////////////////////

    
    // CONTROL SIGNALS////////////////////////////////////////////////////////////
    // Tag array and data Array
    wire wetag;
    wire wr_data_en;
    wire hit;
    //wire modify;
    //wire to_shared;
    //wire ccu_to_exclusive;
    //wire refill_en;
    wire done_mm;
    //wire done_evict;
    //wire sample_en;
    //wire sample_addr;
    //wire evict_en;
    //wire [3:0] weB;
    
    
    
    // Refills and eviction
    /*
    wire [TAG_BITS+1:0] LRU_set_tag_info;
    wire [TAG_BITS+1:0] set_tag_info_flush;
    wire [ADDR_BITS-1:0] addr_to_memA;
    wire [ADDR_BITS-1:0] addr_to_memB;
    //wire [ADDR_BITS-5:0] evicted_base_addr;
    //wire [ADDR_BITS-5:0] evicted_base_addr_f;
    //wire [ADDR_BITS-5:0] evicted_addr;
    wire [31:0] data_from_memA;
    wire [31:0] data_to_memB;
    wire [127:0] data_block_from_mem;
    wire [127:0] data_block_to_mem_t;
    wire [127:0] data_block_to_mem;
    wire [127:0] data_flushed;
    wire [CACHE_WAY-1:0] flush_pointer;
    */
    // change into little endian mode
    //wire [31:0] data_in_little_e = {i_data[7:0], i_data[15:8], i_data[23:16], i_data[31:24]};
    
    // Snooping control signals
    //wire [TAG_BITS-1:0] snooping_tags;
    //wire [INDEX_BITS-1:0] snooping_index;
    wire snoop_invalidate;
    wire snoop_exclusive;
    //wire snoop_shared;
    //wire [1:0] MESI_in_hold;
    //wire [1:0] own_MESI;
    

    
    // ASSIGN OUTPUTS for passing to L2 /////////////////////////////////////////////////////
    assign o_dm_write = i_dm_write;
    assign o_wr = i_wr;
    assign o_wrdata_to_L2 = i_data;
    assign o_addr = i_data_addr;
    
    // Instantiate the Tag Array
    L1_tag_array #(.TAG_BITS(`TAG_BITS), .INDEX_BITS(`INDEX_BITS), .CACHE_WAY(`CACHE_WAY))
        tag_array(
            .clk(clk),                  .nrst(nrst),
            .i_wr_en(wetag),            .i_tag(tags),
            .i_index(index),            .i_LRU_set(lru_way),
            .i_active_op(i_wr || i_rd),
            .i_done_state(o_all_done),
            .i_snooping_tags(i_ext_tags),
            .i_snooping_index(i_ext_index),
            .i_invalidate(i_ext_invalidate),  
            .i_reserve_exclusive(i_ext_reserve_exclusive), 
            .i_to_shared(i_ext_to_shared),
            // snooping control signals
            /*
            .i_modify(modify),
           
            .i_reserve_exclusive( (!i_wr && snoop_exclusive) || ccu_to_exclusive), 
            .o_snooping_mesi(MESI_in_hold),
            .o_own_mesi(own_MESI),
            //.i_flush_pointer(flush_pointer),
            */
            
            
            .o_way(hit_way),
            .o_hit(hit),
            .o_snoop_hit(o_scu_hit)

            //.o_LRU_set_tag_info(LRU_set_tag_info)
            //.o_tag_info_flush(set_tag_info_flush)
            
        );
    
    
    // Instantiate the Cache Controller
    L1_cache_controller #(.CACHE_WAY(`CACHE_WAY), .ADDR_WIDTH(`ADDR_BITS), .TAG_BITS(`TAG_BITS), .INDEX_BITS(`INDEX_BITS), .OFFSET_BITS(`OFFSET_BITS))
        controller (
            .clk(clk),              .nrst(nrst),
            .i_addr(i_data_addr),   .i_hit(hit),
            .i_grant(i_grant),           .i_rd(i_rd),
            .i_wr(i_wr),                .i_way_accessed(hit_way),
            //.i_LRU_set_tag_info(LRU_set_tag_info),
            .i_done_mm(i_data_valid),
            .i_done_write(i_data_wvalid),
            //.i_tag_info_flush(set_tag_info_flush),
            //.i_flush(i_flush),
            //.i_done_evict(done_evict),
            
            .o_tag(tags),           .o_index(index),
            .o_offset(offset),      .o_byte_offset(),
            .o_modify(modify),      .o_wetag(wetag),
            //.o_mesi_state_to_exclusive(ccu_to_exclusive),
            .o_LRU(lru_way),
            .o_wr_data_en(wr_data_en),
            
            /*
            .o_refill_en(refill_en),
            .o_sample_data(sample_en),
            .o_sample_addr(sample_addr),
            .o_evict_en(evict_en),
            .o_addr_evicted(evicted_base_addr),
            .o_addr_evicted_f(evicted_base_addr_f),
            */
            
            //.o_all_done(),
            .o_stall(o_stall),
            .o_req_block(o_req_block),
            .o_req_wr(o_req_wr),
            .o_cache_done(o_all_done),
            .o_ext_addr(o_ext_addr),
            .o_scu_wr(o_scu_wr),
            .o_scu_req(o_scu_req)
            //.o_done_flush(o_done_flush),
            //.o_flush_set_pointer(flush_pointer)
        );
    
    
    // Instantiate the Data Array
    L1_data_array #(.CACHE_WAY(`CACHE_WAY), .INDEX_BITS(`INDEX_BITS))
        data_array (
            .clk(clk), 
            .i_wr(wr_data_en),
            .i_rd(i_rd),
            .i_index(index), .i_offset(offset),
            .i_dm_write(i_dm_write),
            .i_data_from_mem_valid(o_req_block && i_data_valid && i_grant ),
            .i_data_from_core(i_data),
            .i_data_from_mem(i_data_block_from_L2),
            .i_way(hit_way),
            .i_LRU(lru_way),

            .o_data_to_core(o_data)
            //.o_block_to_mem(data_block_to_mem_t),
            //.o_data_flush(data_flushed)
        );
    
    
     // Snooping controller
     /*
     // Work in Progress. Changing stuffs to make it implementable
     snoop_controller #(.ADDR_BITS(ADDR_BITS), .CACHE_WAY(CACHE_WAY), .CACHE_SIZE(CACHE_SIZE))
        scu (
            .clk(clk), .nrst(nrst),
            .ccu_req_in(i_rd || i_wr),
            .read(i_rd),
            .own_MESI_in_hold(own_MESI),
            //.write(),
            .ext_read(i_ext_rd),
            .ext_write(i_ext_wr),
            .ext_addr(i_ext_addr),
            .data_check(i_data_check),
            
            .MESI_in_hold(MESI_in_hold),
            
            .snooping_tags(snooping_tags),
            .snooping_index(snooping_index),
            .invalidate(snoop_invalidate),
            .reserve_exclusive(snoop_exclusive),
            .shared(snoop_shared), 
            .data_response(o_snoop_response),
            .snoop_tag_ok()
            
        );
     */

endmodule
