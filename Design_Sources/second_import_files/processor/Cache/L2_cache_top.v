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
// Description: The input-output ports should match the datamem block of the RISC V core
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module L2_cache_top
    (
    input clk,
    input nrst,
    
    // Inputs from the RISCV core
	input [3:0]            i_dm_write,  // bytewise write
	input                  i_rd,
	input                  i_wr,
	input [`ADDR_BITS-1:0]  i_data_addr,
	input [31:0]           i_data,
	input                  i_ready_mm,

	
	input                  i_grant_core_0,
	input                  i_grant_core_1,
	input                  i_done_core_0,
	input                  i_done_core_1,
	// For Flush
	//input                  i_flush,    // start flush signal
	//output                 o_done_flush, 
	
	// Outputs
	output [127:0]          o_data,	// data output to the RISC-V core
	output                  o_all_done,
	output                  o_valid_data,
	
	// Outputs to the AXI interface
    output                  o_axi_rd,
    output                  o_axi_wr,
    output [31:0]           o_axi_rd_addr,
    output [31:0]           o_axi_wr_addr,
    input [127:0]           i_axi_read_block,
    output [127:0]          o_axi_write_block,
    input                   i_axi_read_done,
    input                   i_axi_write_done,
	
    // Cache specific output
    output                 o_stall,



    // Verification 
    // In lieu of flushing, let's create a port to check
    output                                tb_hit,
    output [31:0]                         tb_data_o
    );
    wire clk_inv = ~clk; // what



    // PARAMETERS ///////////////////////////////////////////////////////////////
    // one word = 32-bits or 4 bytes
    /* Transfered to constants.vh
    localparam OFFSET_BITS = 2;
    localparam BLOCK_SIZE = 16; // 16 bytes per one block (4 words), always
    localparam NUM_BLOCKS = `L2_CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS = NUM_BLOCKS / `L2_CACHE_WAY;
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS - 2;
    //////////////////////////////////////////////////////////////////////////////
    */
    
    // ADDRESS PARSING ///////////////////////////////////////////////////////////
    wire [`OFFSET_BITS-1:0]  offset;
    wire [`L2_TAG_BITS-1:0]     tags;
    wire [`L2_INDEX_BITS-1:0]   index;
    //////////////////////////////////////////////////////////////////////////////
    
    
    // WAY POINTERS //////////////////////////////////////////////////////////////
    wire [`L2_CACHE_WAY-1:0] hit_way;
    wire [`L2_CACHE_WAY-1:0] lru_way;   
    //////////////////////////////////////////////////////////////////////////////

    
    // CONTROL SIGNALS////////////////////////////////////////////////////////////
    // Tag array and data Array
    wire wetag;
    wire wr_data_en;
    wire hit;
    wire modify;
    wire refill_en;
    wire done_mm;
    wire done_evict;
    wire sample_en;
    wire sample_addr;
    wire evict_en;
    //wire [3:0] o_write_signal_ram;
    
    
    // Refills and eviction
    wire [`L2_TAG_BITS+1:0] LRU_set_tag_info;
    wire [`L2_TAG_BITS+1:0] set_tag_info_flush;
    wire [`ADDR_BITS-1:0] addr_to_memA;
    //wire [ADDR_BITS-5:0] evicted_base_addr;
    wire [127:0] data_block_from_mem;
    wire [127:0] data_block_to_mem;
    wire [127:0] data_flushed;
    wire [`L2_CACHE_WAY-1:0] flush_pointer;
    // change into little endian mode
    //wire [31:0] data_in_little_e = {i_data[7:0], i_data[15:8], i_data[23:16], i_data[31:24]};
    // Instantiate the Tag Array
    tag_array #(.TAG_BITS(`L2_TAG_BITS), .INDEX_BITS(`L2_INDEX_BITS), .CACHE_WAY(`L2_CACHE_WAY))
        tag_array(
            .clk(clk),                  .nrst(nrst),
            .i_wr_en(wetag),            .i_tag(tags),
            .i_index(index),            .i_LRU_set(lru_way),
            .i_invalidate(),            .i_modify(modify),
            .i_reserve_exclusive(), 
            .i_flush_pointer(flush_pointer),
            
            .o_way(hit_way),
            .o_hit(hit),
            .o_LRU_set_tag_info(LRU_set_tag_info),
            .o_tag_info_flush(set_tag_info_flush)
            
        );
    
    
    // Instantiate the Cache Controller
    L2_cache_controller #(.CACHE_WAY(`L2_CACHE_WAY), .ADDR_WIDTH(`ADDR_BITS), .TAG_BITS(`L2_TAG_BITS), .INDEX_BITS(`L2_INDEX_BITS), .OFFSET_BITS(`OFFSET_BITS))
        controller (
            .clk(clk),              .nrst(nrst),
            .i_addr(i_data_addr),   .i_hit(hit),
            .i_readymm(i_ready_mm),           .i_rd(i_rd),
            .i_wr(i_wr),                .i_way_accessed(hit_way),
            .i_LRU_set_tag_info(LRU_set_tag_info),
            .i_done_mm(i_axi_read_done),
            .i_tag_info_flush(set_tag_info_flush),
            //.i_flush(i_flush),
            .i_done_evict(i_axi_write_done),
            .i_grant_core_0(i_grant_core_0),
            .i_done_core_0(i_done_core_0),
            .i_grant_core_1(i_grant_core_1),
            .i_done_core_1(i_done_core_1),
            
            .o_tag(tags),           .o_index(index),
            .o_offset(offset),      .o_byte_offset(),
            .o_modify(modify),      .o_wetag(wetag),
            .o_LRU(lru_way),
            
            .o_wr_data_en(wr_data_en),
            .o_refill_en(o_axi_rd),
            //.o_sample_data(sample_en),
            //.o_sample_addr(sample_addr),
            .o_evict_en(o_axi_wr),
            .o_addr_evicted(o_axi_wr_addr),
            //.o_addr_evicted_f(evicted_base_addr_f),
            
            .o_all_done(o_all_done),
            .o_valid_data(o_valid_data),
            .o_stall(o_stall)
            //.o_done_flush(o_done_flush),
            //.o_flush_set_pointer(flush_pointer)
        );
    
    
    // Instantiate the Data Array
    L2_data_array #(.CACHE_WAY(`L2_CACHE_WAY), .INDEX_BITS(`L2_INDEX_BITS))
        data_array (
            .clk(clk),
            .i_wr(wr_data_en),
            .i_rd(i_rd),
            .i_index(index), .i_offset(offset),
            .i_dm_write(i_dm_write),
            .i_data_from_mem_valid(i_axi_read_done), // done refills 
            .i_data_from_core(i_data),
            .i_data_from_mem(i_axi_read_block), // data block refilled from mem
            .i_way(hit_way),
            .i_LRU(lru_way),
            .i_flush_pointer(flush_pointer),
            //.i_flush(i_flush),
            
            .o_data_to_core(o_data),
            .o_block_to_mem(o_axi_write_block), // data block to be evicted
            .o_data_flush(data_flushed),
            .tb_data(tb_data_o)
        );
    assign o_axi_rd_addr = { {32-(`ADDR_BITS){1'b0}} ,i_data_addr[`ADDR_BITS-1:4], 4'b0000};
    /*
    // Instantiate the Refill Controller
    refill_controller #(.ADDR_BITS(ADDR_BITS))
        refill_cont (
            .clk(clk),      .nrst(nrst),
            .i_base_addr(i_data_addr[ADDR_BITS-1:4]),  .i_data_from_mem(i_data_from_memA),
            .i_sample_signal(sample_addr),
            .i_refill_en(refill_en),  .ready_mm(i_ready_mm),
            
            .o_data_block(data_block_from_mem), .o_addr_to_mem(o_addr_to_memA),
            .o_done(done_mm)
        );
        
     //assign data_block_to_mem = (i_flush) ? data_flushed : data_block_to_mem_t;
     //assign evicted_addr = (i_flush) ? evicted_base_addr_f : evicted_base_addr;
     // Instantiate the Eviction Controller
     eviction_controller #(.ADDR_BITS(ADDR_BITS))
        evict_cont (
            .clk(clk),                          .nrst(nrst),
            .i_sample_signal(sample_en),        .i_evict_en(evict_en),
            .ready_mm(i_ready_mm),              .i_evicted_block(data_block_to_mem),
            .i_base_addr(evicted_base_addr),    .o_addr_to_bram(o_addr_to_memB),
            .o_data_to_bram(o_data_to_memB),       .o_done(done_evict),
            .o_write_signal(o_write_signal_ram)
        );
     
        // TO DO :
        // Change from Write back to Write Through
        // How would we do that
        
     */   
     // Instantiate the BRAM
     // for now
     // put this outside the l1 l2 connections
     /*
     dual_port_bram # (.ADDR_WIDTH(ADDR_BITS-2))
        bram(
            // PORT A - refills
            .clkA(clk),
            .enaA(1'b1),
            .weA(4'b0),
            .addrA(o_addr_to_memA),
            .doutA(i_data_from_memA),
            
            
            .clkB(clk),
            .enaB(1'b1),
            .o_write_signal_ram(o_write_signal_ram),
            .addrB(o_addr_to_memB),
            .dinB(o_data_to_memB)
            
        );
     */
     assign tb_hit = hit; 

endmodule
