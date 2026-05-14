`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/27/2024 12:17:34 PM
// Design Name: 
// Module Name: cache_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: The main cache controller that will send appropriate control signals to the Tag array and data array
//      
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module L2_cache_controller
    #
    (
    parameter CACHE_WAY = 8,
    parameter ADDR_WIDTH = 14,
    parameter TAG_BITS = 5,
    parameter INDEX_BITS = 3,
    parameter OFFSET_BITS = 2
    )
    (
    input clk,
    input nrst,
    
    
    input [ADDR_WIDTH-1:0]      i_addr,
    input                       i_hit,           //From the Tag Array
    input                       i_readymm,       // Grant from arbitration
    input                       i_done_mm,
    input                       i_rd,
    input                       i_wr,
    input                       i_done_evict,
    input                       i_grant_core_0,
    input                       i_grant_core_1,
    input                       i_done_core_0,
    input                       i_done_core_1,
    
    // input for LRU
    input [TAG_BITS+1:0]        i_LRU_set_tag_info,
    input [TAG_BITS+1:0]        i_tag_info_flush,
    input  [CACHE_WAY-1:0]      i_way_accessed,
    
    output [TAG_BITS-1:0]       o_tag, 
    output [INDEX_BITS-1:0]     o_index, 
    output [1:0]                o_offset,
    output [1:0]                o_byte_offset,
    
    //output control signals
    output  reg                 o_wr_data_en,
    output                      o_modify,
    output                      o_wetag,         // Write Enable for the tag array        
    
    //output LRU information       
    output [CACHE_WAY-1:0]      o_LRU,        
    
    //output for Refills and Eviction
    output                      o_refill_en,
    //output                      o_sample_data,
    output                      o_sample_addr,
    output                      o_evict_en,
    output [31:0]               o_addr_evicted,     // Needs to be 32 bits for the AXI
    //output [ADDR_WIDTH-5:0]     o_addr_evicted_f,
    
    output                      o_stall,
    output                      o_all_done,
    output                      o_valid_data,
    
    
    // Flush
    input                       i_flush,
    output                      o_done_flush,
    output [CACHE_WAY-1:0]      o_flush_set_pointer
    );

    localparam NUM_INDEX = 2 ** INDEX_BITS;


    // FLUSH MECHANISM STUFFS ///////////////////////////////////////////////////////////////
    // COMMENT OUT IF NOT NEEDED ///////////////////////////////////////////////////////////
    reg [INDEX_BITS-1:0] r_flush_index;
    reg [CACHE_WAY-1:0] r_flush_set_pointer;
    reg [$clog2(CACHE_WAY)-1:0] r_way_counter;

    wire MESI_state_1_f;
    wire MESI_state_0_f;
    wire modified_f;
    assign MESI_state_1_f = i_tag_info_flush[TAG_BITS+1];
    assign MESI_state_0_f = i_tag_info_flush[TAG_BITS];
    assign modified_f = MESI_state_1_f && ~MESI_state_0_f;
    //assign o_addr_evicted_f = {i_tag_info_flush[TAG_BITS-1:0], r_flush_index};

    //assign o_done_flush = (state == S_FLUSH_DONE);
    // assign o_flush_set_pointer = r_flush_set_pointer;

    
    // Parse address

    assign o_byte_offset = i_addr[1:0];             // For bytewise writes
    assign o_offset = i_addr[3:2];      // should I just do 2 bits for 4 words per block?
    assign o_index = i_addr[ADDR_WIDTH - TAG_BITS - 1: 4];
    assign o_tag = i_addr[ADDR_WIDTH - 1 : ADDR_WIDTH - TAG_BITS ];

        

    
    // Parse LRU tag info from tag array to check if modified
    // need the 2 MSB for the MESI protocol
    wire MESI_state_1;
    wire MESI_state_0;
    wire modified;
    assign MESI_state_1 = i_LRU_set_tag_info[TAG_BITS+1];
    assign MESI_state_0 = i_LRU_set_tag_info[TAG_BITS];
    wire sample_data;
 
    
    // MESI states
    // Invalid:     00
    // Shared:      01
    // Modified:    10
    // Exclusive:   11
    // bit 0 - stored in MESI_state_0;
    // bit 1 - stored in MESI_state_1;
    
    assign modified = MESI_state_1 && ~MESI_state_0;

    
    // Assemble the base address for evicting;
    // Address = Tag + index + Offset + 00;
    // Address bit = 12;
    // total bit = 32;
    
    assign o_addr_evicted = {{(32-ADDR_WIDTH){1'b0}} ,i_LRU_set_tag_info[TAG_BITS-1:0], i_addr[ADDR_WIDTH - TAG_BITS - 1: 4], 4'b0};


    // Declaring States
    reg [3:0] state;
    
    localparam S_NORMAL = 4'd0;
    localparam S_CHECK_FOR_HITS = 4'd1;
    localparam S_WRITE = 4'd2;
    localparam S_READ = 4'd3;
    localparam S_UPDATING = 4'd4;
    localparam S_WAITING_FOR_MM = 4'd5;
    localparam S_DONE_REFILL = 4'd6;
    localparam S_DONE = 4'd7; // For Testbench only
    

    

    

    
    
    // Control signals
    reg evict_en_reg;    
    assign o_modify = ( i_wr && i_hit && !(state == S_NORMAL) ) ? 1'b1 : 1'b0;                                  // Tag already EXISTS and VALID in the cache, update the MESI protocols only
    assign o_wetag = ( state == S_UPDATING && !i_hit) ? 1'b1 : 1'b0;              // It doesnt matter if its a read or write MISS, we'll be writing the tag in the cache anways
    assign o_refill_en = ( state == S_UPDATING ) ? 1'b1 : 1'b0;                         
    assign o_sample_addr = (state == S_WAITING_FOR_MM) ? 1'b1 : 1'b0;
    assign sample_data = ( ( state == S_WAITING_FOR_MM && ~i_hit && modified) ) ? 1'b1 : 1'b0;
    assign o_evict_en = evict_en_reg;
    assign o_valid = (state == S_DONE_REFILL) ? 1'b1 : 1'b0;
    assign o_all_done = ( state == S_DONE ) ? 1'b1 : 1'b0;
    assign o_valid_data = ( (state == S_DONE) && i_rd) ? 1'b1 : 1'b0;
    assign o_stall = (state == S_UPDATING || state == S_WAITING_FOR_MM || (i_rd || i_wr) && !i_hit) ? 1'b1 : 1'b0;

    
    // Generate the proper LRU module 
    generate 
        
        case (CACHE_WAY) 
            8: begin
                eightway_PLRU PLRU_module(.nrst(nrst), .i_way_accessed(i_way_accessed), .i_hit(i_hit), .o_LRU(o_LRU));
            end
            
            4: begin
                fourway_LRU PLRU_module(.nrst(nrst), .i_way_accessed(i_way_accessed), .i_hit(i_hit), .o_LRU(o_LRU));
            end
            
            2: begin
                twoway_LRU PLRU_module(.nrst(nrst), .i_way_accessed(i_way_accessed), .i_hit(i_hit), .o_LRU(o_LRU));
            end
            default: begin  
                 eightway_PLRU PLRU_module(.nrst(nrst), .i_way_accessed(i_way_accessed), .i_hit(i_hit), .o_LRU(o_LRU));
            end
        endcase
        
    endgenerate
    
    initial begin
        state <= S_NORMAL;
        r_flush_index <= 0;
        r_flush_set_pointer <= 1;
    end
    
    // FOR EFFICIENCY TRACKING - REMOVE WHEN IMPLEMENTING TO SAVE RESOURCES ///////
    reg prev_read;
    reg prev_write;
    reg prev_hit;
    reg hit_result;
     
    wire read_edge;
    wire write_edge;
    wire access_edge;
    wire hit_edge;
    ////////////////////////////////////////////////////////////////////////////////
    
    
    // =========== FSM =======================//
    always @(posedge clk) begin
        if (!nrst) begin
            state <= S_NORMAL;
            r_flush_index <= 0;
            r_way_counter <= 0;
            r_flush_set_pointer <= 1;
            evict_en_reg <= 0;
            o_wr_data_en <= 0;
        end
        else begin

            case (state)
                S_NORMAL: begin
                    o_wr_data_en <= 0;
                    evict_en_reg <= 0;
                    if (i_rd || i_wr) begin
                        state <= S_CHECK_FOR_HITS;
                        //o_stall <= 1;
                        
                    end
                    /*
                    if (i_rd) begin
                        if (i_hit) begin 
                            state <= S_DONE; /// change this ok?
                        end
                        else state <= S_WAITING_FOR_MM;
                    end
                    
                    if (i_wr) begin
                        if (i_hit) begin 
                            state <= S_DONE; /// change this ok?
                        end
                        else state <= S_WAITING_FOR_MM;
                    end 
                    */
                    
                end
                
                S_CHECK_FOR_HITS: begin
                     if (i_rd) begin
                        if (i_hit) begin 
                            state <= S_DONE; /// change this ok?
                            hit_result <= 1;
                        end
                        else state <= S_WAITING_FOR_MM;
                    end
                    
                    if (i_wr) begin
                        if (i_hit) begin 
                            o_wr_data_en <= 1;
                            state <= S_DONE; /// change this ok?
                            hit_result <= 1;
                        end
                        else begin
                            state <= S_WAITING_FOR_MM;
                            hit_result <= 0;
                        end
                    end 
                end

                S_WAITING_FOR_MM: begin
                    hit_result <= 0;
                    if (i_readymm) state <= S_UPDATING;
                    
                    if (sample_data) evict_en_reg <= 1'b1;
                end
                

                S_UPDATING: begin
                    
                    if (i_done_mm) begin
                        // change this before putting in core
                        
                        //state <= S_NORMAL;
                        
                        state <= S_DONE_REFILL;
                        
                        evict_en_reg <= 0;
                    end
                end
                
                S_DONE_REFILL: begin 
                    state <= S_DONE; 
                    o_wr_data_en <= 1;
                end
                
                S_DONE: begin
                    hit_result <= 0;
                    o_wr_data_en <= 0;
                    if ( (i_grant_core_0 && i_done_core_0) || (i_grant_core_1 && i_done_core_1) ) begin
                    // don't wait for L1?
                        state <= S_NORMAL;
                        evict_en_reg <= 0;
                        
                    end
                end
                
                default: state <= S_NORMAL;
            endcase
            
            

        end
        
        
        
        
    end
    
     // // FOR EFFICIENCY TRACKING
    integer hit_counter;   
    integer memory_access_counter;
     
    initial begin
       hit_counter = 0;
       memory_access_counter = 0;
    end
     

    assign read_edge = i_rd & ~prev_read;
    assign write_edge = i_wr & ~prev_write;
    assign access_edge = read_edge || write_edge;
    assign hit_edge = hit_result & ~prev_hit;
     
    always @ (posedge clk) begin
       if (!nrst) begin
           prev_read <= 0;
           prev_write <= 0;
           prev_hit <= 0;
           hit_result <= 0;
        end
        else begin
            prev_read <= i_rd;
            prev_write <= i_wr;
            prev_hit <= hit_result;
            if (access_edge) begin
                memory_access_counter = memory_access_counter + 1;
            end
            
            if (hit_edge) begin
                hit_counter = hit_counter + 1;
            end
        end
        
     end
    
endmodule
