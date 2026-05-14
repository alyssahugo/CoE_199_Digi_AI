`timescale 1ns / 1ps

`include "constants.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2025 07:41:46 PM
// Design Name: 
// Module Name: scu
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


module scu
    /*# (
    // we really should change this in a more elegant way
    parameter CACHE_WAY = 4,
    parameter CACHE_SIZE = 1024, // bytes
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
    
    // Core 0
    input [`ADDR_BITS-1:0] core_addr_0,
    input core_scu_req_0,                   // Core requests a block to L2
    input core_wr_0,
    input core_snoop_hit_0,             // Data check. If 1, Data exists on core and is valid
    output reg [`TAG_BITS-1:0] core_tag_0,
    output reg [`INDEX_BITS-1:0] core_index_0,
    output reg invalidate_to_core_0,
    output reg reserve_excluisve_0,
    output reg to_shared_0,
    input core_0_done,
    
    // Core 1
    input [`ADDR_BITS-1:0] core_addr_1,
    input core_scu_req_1,                   // Core requests a block to L2
    input core_wr_1,
    input core_snoop_hit_1,             // Data check. If 1, Data exists on core and is valid
    output reg [`TAG_BITS-1:0] core_tag_1,
    output reg [`INDEX_BITS-1:0] core_index_1,
    output reg invalidate_to_core_1,
    output reg reserve_excluisve_1,
    output reg to_shared_1,
    input core_1_done
    );

 
    
    reg mesi_scu_req_0;
    reg mesi_scu_wr_0;
    reg mesi_scu_req_1;
    reg mesi_scu_wr_1;
    
    // We need to represent the MESI states
    // Invalid:     00
    // Shared:      01
    // Modified:    10
    // Exclusive:   11
    
    // TWO STAGE PIPELINE
    // REQ_ stage
    // MESI_ stage
    // The REQ_ stage is staging the input to be passed to the MESI_ state
    // The MESI_ stage sends the appropriate MESI commands like invalidattion;

    // Core 0 Pipeline
    /*
    always @ (posedge clk) begin
        if (!nrst) begin
            core_tag_0 <= 0;
            core_index_0 <= 0;
            mesi_scu_req_0 <= 0;
            mesi_scu_wr_0 <= 0;
        end
        else begin
            // REQ_ stage
            core_tag_0 <= core_addr_0[`ADDR_BITS - 1 : `ADDR_BITS - `TAG_BITS ];
            core_index_0 <=  core_addr_0[`ADDR_BITS - `TAG_BITS - 1: 4];
            mesi_scu_req_0 <= core_scu_req_0;
            mesi_scu_wr_0 <= core_wr_0;   
        end
    end
    */
    /*
     // Core 1 Pipeline
    always @ (posedge clk) begin
        if (!nrst) begin
            core_tag_1 <= 0;
            core_index_1 <= 0;
            mesi_scu_req_1 <= 0;
            mesi_scu_wr_1 <= 0;
            
            invalidate_to_core_1 <= 0;
            reserve_excluisve_1 <= 0;
            to_shared_1 <= 0;
        end
        else begin
            // REQ_ stage
            core_tag_1 <= core_addr_1[`ADDR_BITS - 1 : `ADDR_BITS - `TAG_BITS ];
            core_index_1 <=  core_addr_1[`ADDR_BITS - `TAG_BITS - 1: 4];
            mesi_scu_req_1 <= core_scu_req_1;
            mesi_scu_wr_1 <= core_wr_1;   
        end
    end
    */
    //Core 0 FSM
    reg [1:0] core_0_state;
    reg core_1_snoop_hit_reg;
    localparam S_IDLE = 2'd0;
    localparam S_PLACE_ADDR = 2'd1;
    localparam S_SNOOP_FOR_HITS = 2'd2;
    localparam S_DONE = 2'd3;
    
    always @ (posedge clk) begin
        if (!nrst) begin
            core_0_state <= S_IDLE;
            core_1_snoop_hit_reg <= 0;
            core_tag_0 <= 0;
            core_index_0 <= 0;
            mesi_scu_req_0 <= 0;
            mesi_scu_wr_0 <= 0;
            invalidate_to_core_1 <= 0;
            reserve_excluisve_1 <= 0;
            to_shared_1 <= 0;
        end
        else begin
            case (core_0_state)
                S_IDLE: begin
                    invalidate_to_core_1 <= 0;
                    reserve_excluisve_1 <= 0;
                    to_shared_1 <= 0;
                    mesi_scu_req_0 <= 0;
                    mesi_scu_wr_0 <= 0;
                    core_1_snoop_hit_reg <= 0;
                    if (core_scu_req_0) begin
                        core_tag_0 <= core_addr_0[`ADDR_BITS - 1 : `ADDR_BITS - `TAG_BITS ];
                        core_index_0 <=  core_addr_0[`ADDR_BITS - `TAG_BITS - 1: 4];
                        mesi_scu_req_0 <= core_scu_req_0;
                        mesi_scu_wr_0 <= core_wr_0;  
                        core_0_state <= S_PLACE_ADDR;
                    end
                end
                
                S_PLACE_ADDR: begin
                    core_0_state <= S_SNOOP_FOR_HITS;
                end
                
                S_SNOOP_FOR_HITS: begin
                    core_1_snoop_hit_reg <= core_snoop_hit_1;
                    core_0_state <= S_DONE;
                end
                
                S_DONE: begin
                    if (core_1_snoop_hit_reg) begin
                        if (mesi_scu_req_0 && !mesi_scu_wr_0) begin
                            to_shared_1 <= 1;
                        end
                        if (mesi_scu_req_0 && mesi_scu_wr_0) begin
                            invalidate_to_core_1 <= 1;
                        end
                    end
                    else 
                        reserve_excluisve_1 <= 1;
                        
                    if (core_0_done) begin
                        core_0_state <= S_IDLE;
                    end 
                    
                end
                
            endcase
        end
    end
    
    //Core 1 FSM
    reg [1:0] core_1_state;
    reg core_0_snoop_hit_reg;

    
    always @ (posedge clk) begin
        if (!nrst) begin
            core_1_state <= S_IDLE;
            core_0_snoop_hit_reg <= 0;
            core_tag_1 <= 0;
            core_index_1 <= 0;
            mesi_scu_req_1 <= 0;
            mesi_scu_wr_1 <= 0;
            invalidate_to_core_0 <= 0;
            reserve_excluisve_0 <= 0;
            to_shared_0 <= 0;
        end
        else begin
            case (core_1_state)
                S_IDLE: begin
                    invalidate_to_core_0 <= 0;
                    reserve_excluisve_0 <= 0;
                    to_shared_0 <= 0;
                    mesi_scu_req_1 <= 0;
                    mesi_scu_wr_1 <= 0;
                    core_0_snoop_hit_reg <= 0;
                    if (core_scu_req_1) begin
                        core_tag_1 <= core_addr_1[`ADDR_BITS - 1 : `ADDR_BITS - `TAG_BITS ];
                        core_index_1 <=  core_addr_1[`ADDR_BITS - `TAG_BITS - 1: 4];
                        mesi_scu_req_1 <= core_scu_req_1;
                        mesi_scu_wr_1 <= core_wr_1;  
                        core_1_state <= S_PLACE_ADDR;
                    end
                end
                
                S_PLACE_ADDR: begin
                    core_1_state <= S_SNOOP_FOR_HITS;
                end
                
                S_SNOOP_FOR_HITS: begin
                    core_0_snoop_hit_reg <= core_snoop_hit_0;
                    core_1_state <= S_DONE;
                end
                
                S_DONE: begin
                    if (core_0_snoop_hit_reg) begin
                        if (mesi_scu_req_1 && !mesi_scu_wr_1) begin
                            to_shared_0 <= 1;
                        end
                        else if (mesi_scu_req_1 && mesi_scu_wr_1) begin
                            invalidate_to_core_0 <= 1;
                        end
                    end
                    else 
                        reserve_excluisve_0 <= 1;
                        
                    if (core_1_done) begin
                        core_1_state <= S_IDLE;
                    end 
                    
                end
                
            endcase
        end
    end
    // MESI_ stage
    // COmbinatorial part
    /*
    assign invalidate_to_core_1 = ( mesi_scu_wr_0 && core_1_snoop_hit_reg);
    assign to_shared_1 = (!mesi_scu_wr_0 && mesi_scu_req_0 && core_1_snoop_hit_reg);
    assign reserve_excluisve_1 = ( mesi_scu_req_1 && !core_snoop_hit_0);
    
    assign invalidate_to_core_0 = ( mesi_scu_wr_1 && core_snoop_hit_0);
    assign reserve_excluisve_0 = ( mesi_scu_req_0 && !core_snoop_hit_1);
    assign to_shared_0 = (!mesi_scu_wr_1 && mesi_scu_req_1 && core_snoop_hit_0);
    */
endmodule
