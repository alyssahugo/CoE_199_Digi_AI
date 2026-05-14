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
// Description: The main L1 cache controller that will send appropriate control signals to the Tag array and data array
//              Write-Through Strategy
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module L1_cache_controller
    #
    (
    parameter CACHE_WAY = 2,
    parameter ADDR_WIDTH = 12,
    parameter TAG_BITS = 5,
    parameter INDEX_BITS = 3,
    parameter OFFSET_BITS = 2
    )
    (
    input clk,
    input nrst,
    
    
    input [ADDR_WIDTH-1:0]      i_addr,
    input                       i_hit,           //From the Tag Array
    input                       i_grant,       // Grant from arbitration
    input                       i_done_mm,
    input                       i_done_write,
    input                       i_rd,
    input                       i_wr,
    //input                       i_done_evict,
    
    // input for LRU
    //input [TAG_BITS+1:0]        i_LRU_set_tag_info,
    //input [TAG_BITS+1:0]        i_tag_info_flush,
    input  [CACHE_WAY-1:0]      i_way_accessed,
    
    output [TAG_BITS-1:0]       o_tag, 
    output [INDEX_BITS-1:0]     o_index, 
    output [1:0]                o_offset,
    output [1:0]                o_byte_offset,
    
    //output control signals
    output reg                  o_wr_data_en,
    output                      o_modify,
    output reg                  o_wetag,         // Write Enable for the tag array        
    //output reg                  o_mesi_state_to_exclusive,
    
    //output LRU information       
    output [CACHE_WAY-1:0]      o_LRU,        
    
    //output for Refills and Eviction
    /*
    output                      o_refill_en,
    output                      o_sample_data,
    output                      o_sample_addr,
    output                      o_evict_en,
    output [ADDR_WIDTH-5:0]     o_addr_evicted,
    */
    
    output reg                  o_stall,
    output                      o_cache_done,
    output reg                  o_req_block,
    output reg                  o_req_wr,
    output reg                  o_scu_req,
    output reg                  o_scu_wr,
    output reg  [ADDR_WIDTH-1:0] o_ext_addr
    
    );

    localparam NUM_INDEX = 2 ** INDEX_BITS;

    // Parse address
    
    assign o_byte_offset = i_addr[1:0];             // For bytewise writes
    assign o_offset = i_addr[3:2];      // should I just do 2 bits for 4 words per block?
    assign o_index =  i_addr[ADDR_WIDTH - TAG_BITS - 1: 4];
    assign o_tag = i_addr[ADDR_WIDTH - 1 : ADDR_WIDTH - TAG_BITS ];
    
        

    
    // Parse LRU tag info from tag array to check if modified
    // need the 2 MSB for the MESI protocol
    /*
    wire MESI_state_1;
    wire MESI_state_0;
    wire modified;
    assign MESI_state_1 = i_LRU_set_tag_info[TAG_BITS+1];
    assign MESI_state_0 = i_LRU_set_tag_info[TAG_BITS];
    */
 
    
    // MESI states
    // Invalid:     00
    // Shared:      01
    // Modified:    10
    // Exclusive:   11
    // bit 0 - stored in MESI_state_0;
    // bit 1 - stored in MESI_state_1;
    
    //assign modified = MESI_state_1 && ~MESI_state_0;

    
    // Assemble the base address for evicting;
    // Address = Tag + index + Offset + 00;
    //assign o_addr_evicted = { i_LRU_set_tag_info[TAG_BITS-1:0], i_addr[ADDR_WIDTH - TAG_BITS - 1: 4]};


    // Declaring States
    reg [3:0] state;
    localparam S_NORMAL = 4'd0;
    localparam S_CHECK_FOR_HITS = 4'd1; // Also functions as S_DONE state if hit 
    localparam S_WRITE = 4'd2;
    localparam S_SCU_REQ = 4'd3;
    localparam S_WAIT_FOR_GRANT = 4'd4;
    localparam S_WAIT_FOR_L2 = 4'd5;
    localparam S_REFILL = 4'd6;
    localparam S_DONE = 4'd7;
    

    

    

    
    
    // Control signals
    //reg evict_en_reg;    
    assign o_modify = ( i_wr && i_hit ) ? 1'b1 : 1'b0;                                  // Tag already EXISTS and VALID in the cache, update the MESI protocols only
             
    //assign o_refill_en = ( state == S_UPDATING ) ? 1'b1 : 1'b0;                         
    //assign o_sample_addr = (state == S_WAITING_FOR_MM) ? 1'b1 : 1'b0;
    //assign o_sample_data = ( ( state == S_WAITING_FOR_MM && ~i_hit && modified) ) ? 1'b1 : 1'b0;
    //assign o_evict_en = evict_en_reg;
    //assign o_all_done = ( state == S_DONE ) ? 1'b1 : 1'b0;
    //assign o_stall = (state == S_WAIT_FOR_GRANT || state == S_WAIT_FOR_L2 || (i_rd || i_wr) && !i_hit) ? 1'b1 : 1'b0;

    
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
    
    reg cache_done_r;
    assign o_cache_done = cache_done_r || ( (state == S_CHECK_FOR_HITS) && i_hit && i_rd );
    
    initial begin
            o_req_block = 0;
            o_req_wr = 0;
            state = S_NORMAL;
            cache_done_r = 0;
            o_stall = 0;
            o_scu_req = 0;
            o_scu_wr = 0;
            o_wetag = 0;
            o_ext_addr = 0;
            o_wr_data_en = 0;

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
            o_req_block <= 0;
            o_req_wr <= 0;
            state <= S_NORMAL;
            cache_done_r <= 0;
            //o_mesi_state_to_exclusive <= 0;
            o_stall <= 0;
            o_scu_req <= 0;
            o_scu_wr <= 0;
            o_wetag <= 0;
            o_ext_addr <= 0;
            o_wr_data_en <= 0;

        end
        else begin

            case (state)
                S_NORMAL: begin
                    if (i_rd || i_wr) begin
                        state <= S_CHECK_FOR_HITS;
                        o_stall <= 1;
                        
                    end
                    
                    /*
                    else if (i_wr) begin
                        o_req_block <= 1;
                        o_stall <= 1;
                        state <= S_SCU_REQ;
                        o_scu_req <= 1;
                        o_scu_wr <= i_wr;
                        o_ext_addr <= i_addr;
                    end
                    */
 
                   else state <= S_NORMAL;
                    //o_cache_done <= 0;
                end
                
                S_CHECK_FOR_HITS: begin
                    if (i_hit) begin
                        if (i_rd) begin
                            //o_stall <= 1;
                            
                            //state <= S_DONE;
                            
                            // Optimization:
                            state <= S_NORMAL; // GO back to Idle/Normal state;
                            
                            
                            //cache_done_r <= 1;
                            o_wetag <= 0;
                            hit_result <= 1;
                            o_stall <= 0;
                        end
                        else if (i_wr) begin
                            
                            o_req_wr <= 1; 
                            o_stall <= 1;
                            state <= S_SCU_REQ;
                            o_scu_req <= 1;
                            o_scu_wr <= i_wr;
                            o_ext_addr <= i_addr;
                            hit_result <= 1;
                        end
                        else begin
                            // MEM stage is flushed
                            state <= S_NORMAL; // go back to normal state
                            cache_done_r <= 0;
                            o_req_block <= 0;
                            //o_mesi_state_to_exclusive <= 0;
                            o_stall <= 0;
                        end
                     end
                     else begin
                        
                        o_req_block <= 1;
                        //o_stall <= 1;
                        state <= S_SCU_REQ;
                        o_ext_addr <= i_addr;
                        o_scu_req <= 1;
                        o_wetag <= 1; 
                        hit_result <= 0;
                        if (i_wr) begin
                            o_scu_wr <= 1;
                            o_req_wr <= 1;
                        end
                     end
                end
                
                
                S_SCU_REQ: begin
                    // New state for coordinating with the Snooping Control Unit
                    state <= S_WAIT_FOR_GRANT;
                    //if (!i_hit) o_wetag <= 1; 
                    //else o_wetag <= 0;
                    //o_wetag <= 0;
                    hit_result <= 0;
                end
                
                S_WAIT_FOR_GRANT: begin
                    o_wetag <= 0; 
                    if (i_grant) begin
                        //o_scu_req <= 1;
                        //o_scu_wr <= i_wr;
                        //o_ext_addr <= i_addr;
                        state <= S_WAIT_FOR_L2;
                          
                    end

                end

                
                S_WAIT_FOR_L2: begin
                    
                    //o_scu_req <= 0;
                    //o_scu_wr <= 0;
                    
                    if (i_rd) begin
                        if (i_done_mm) begin
                            o_scu_req <= 0;
                            o_scu_wr <= 0;
                            
                            state <= S_REFILL;
                        end
                    end
                    else if (i_wr) begin
                        if (i_done_write) begin
                            // We need to write through the L2 next
                            state <= S_WRITE;
                        end
                    end
                    /*
                    if (i_done_mm) begin
                        if (i_rd) begin
                            // the data is valid now
                            
                            o_scu_req <= 0;
                            o_scu_wr <= 0;
                            
                            state <= S_REFILL;
                        end
                        else if (i_wr) begin
                            // We need to write through the L2 next
                            state <= S_WRITE;
                            //o_mesi_state_to_exclusive <= 1;
                            
                        end
                        // change this before putting in core
                        
                        //state <= S_NORMAL;
                        
                        //state <= S_DONE;
                    end
                    */
                end
                
                S_REFILL: begin 
                    cache_done_r <= 1;
                    
                    state <= S_DONE;
                end
                
                S_DONE: begin
                    state <= S_NORMAL;
                    o_req_block <= 0;
                    o_req_wr <= 0;
                    cache_done_r <= 0;
                    //evict_en_reg <= 0;
                    //o_mesi_state_to_exclusive <= 0;
                    o_stall <= 0;
                    hit_result <= 0;
                    o_wr_data_en <= 0;
                end
                
                
                S_WRITE: begin
                    o_wr_data_en <= 1;
                    state <= S_DONE;
                    cache_done_r <= 1;
                    o_scu_req <= 0;
                    o_scu_wr <= 0;
                    //o_mesi_state_to_exclusive <= 0;
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
