`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/23/2024 06:16:25 PM
// Design Name: 
// Module Name: tag_mem
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


module L1_tag_mem #(
    parameter TAG_BITS = 5,
    parameter INDEX_BITS = 3
    )(
    input clk,
    input nrst,
    input                       i_wr_en,
    
    input   [TAG_BITS-1:0]      i_tag,
    input   [INDEX_BITS-1:0]    i_index,

    input                       i_am_LRU,
    
    input                       i_done_state,
    input                       i_active_op,
    
    // Snooping protocol  
    input                       i_reserve_exclusive,
    input                       i_to_shared,
    input                       i_invalidate,
    
    input   [TAG_BITS-1:0]      i_snoop_tags,
    input   [INDEX_BITS-1:0]    i_snoop_index,
    output                      o_snoop_hit,
    /*
    
    
    
    output [1:0]                o_snooping_mesi,
    output                      o_snoop_match,
    
    output [1:0]                o_own_mesi,
    input                       i_modify,
    
    */
    
    //output  [TAG_BITS + 1:0]    o_tag,
    //output [TAG_BITS + 1:0]     o_tag_flush,
    output                        o_hit
    );
    
    localparam NUM_SETS = 1 << INDEX_BITS;
    localparam TAG_BITS_WITH_LRU = TAG_BITS + 2;        //each entry: {2 bit MESI state + TAG}
    
    // 1D tag memory
    reg [TAG_BITS-1:0] tag_mem[NUM_SETS-1:0];
    reg [TAG_BITS-1:0] out_tag;
    reg [TAG_BITS-1:0] out_tag_snoop;
    
    
    
    // how about the MESI states tag?
    // We need to represent the MESI states
    // Invalid:     00
    // Shared:      01
    // Modified:    10
    // Exclusive:   11
    // bit 0 - stored in MESI_state_0;
    // bit 1 - stored in MESI_state_1;
    reg [NUM_SETS-1:0] MESI_state_0;
    reg [NUM_SETS-1:0] MESI_state_1;
    
    
    // Store the invalidated index here.
    // In case of invalidation while there's an active operation.
    // Essentially, if its a rd operation, let the read operation push through before invalidating
    // We solve this problem of stale data by being assured by the program (i.e. Atomic Instructions)
    // That is, please, be mindful of coding stuffs. If there's a shared data, always use locks and other atomic primitives
    reg [INDEX_BITS-1:0] pending_invalidate_index;
    reg pending_invalidate; 

    
    
    // ============ ASSIGN WIRES ====================//
    
    reg MESI_state_bit_0;
    reg MESI_state_bit_1;
    reg MESI_snoop_state_0;
    reg MESI_snoop_state_1;
    wire [1:0] MESI;
    wire [1:0] MESI_snoop;

    /*
    always @ (*) begin
        MESI_state_bit_0 = MESI_state_0[i_index];
        MESI_state_bit_1 = MESI_state_1[i_index];
        MESI_snoop_state_0 = MESI_state_0[i_snoop_index];
        MESI_snoop_state_1 = MESI_state_1[i_snoop_index];
    end
    */
    //assign MESI_state_bit_0 = MESI_state_0[i_index];
    //assign MESI_state_bit_1 = MESI_state_1[i_index];
    assign MESI = {MESI_state_bit_1, MESI_state_bit_0};
    assign MESI_snoop = { MESI_snoop_state_1, MESI_snoop_state_0};
    
    assign o_tag = (i_am_LRU) ? {MESI, out_tag} : 0;
    //assign o_tag_flush = {MESI,tag_mem[i_index]};
    
    assign valid = (MESI == 2'b00) ? 1'b0 : 1'b1;
    
    
    
    // Snooping
    assign o_snoop_match = (out_tag_snoop == i_snoop_tags) ? 1'b1 : 1'b0;
    assign o_snoop_valid = (MESI_snoop == 2'b00) ? 1'b0 : 1'b1;
    assign o_snoop_hit = o_snoop_valid && o_snoop_match;
    /*
    assign o_snooping_mesi = (o_snoop_match && o_snoop_valid) ? {MESI_state_1[i_snoop_index], MESI_state_0[i_snoop_index] } : 0;
    assign o_own_mesi = MESI;
    

    */
    integer i;
    initial begin
        for (i = 0; i < NUM_SETS; i = i+ 1) begin
            tag_mem[i] <= 0;
        end
    end
    wire match;

    reg potential_conflict;
    
    assign match = (out_tag == i_tag) ? 1'b1 : 1'b0;
    assign o_hit = (valid) ? (match ? 1'b1 : 1'b0) : 1'b0; 

    // ============ SYNCHRONOUS READ AND WRITE ================//
    
    always @(posedge clk) begin
        if (!nrst) begin
           MESI_state_0 <= 0;
           MESI_state_1 <= 0;
           pending_invalidate_index <= 0;
           pending_invalidate <= 0;
           out_tag <= 0;
        end
        else begin
            // READS
            out_tag <= tag_mem[i_index];
            out_tag_snoop <= tag_mem[i_snoop_index];
            MESI_state_bit_0 <= MESI_state_0[i_index];
            MESI_state_bit_1 <= MESI_state_1[i_index];
            MESI_snoop_state_0 <= MESI_state_0[i_snoop_index];
            MESI_snoop_state_1 <= MESI_state_1[i_snoop_index];
            
            // WRITES 
            if (i_wr_en) begin
                tag_mem[i_index] <= i_tag;
                if (i_reserve_exclusive) begin 
                    MESI_state_0[i_index] <= 1'b1;
                    MESI_state_1[i_index] <= 1'b1;
                end else begin
                // shared
                    MESI_state_0[i_index] <= 1'b1;
                    MESI_state_1[i_index] <= 1'b0;
                end
            end 
            else begin
                if (i_invalidate && o_snoop_hit) begin
                    if (potential_conflict) begin
                        pending_invalidate_index <= i_snoop_index;
                        pending_invalidate <= 1;
                    end else begin
                        MESI_state_0[i_snoop_index] <= 1'b0;
                        MESI_state_1[i_snoop_index] <= 1'b0;
                    end
                end
                
                
                if (i_done_state && pending_invalidate && o_snoop_hit)  begin // from the L1 Cache Controller
                    MESI_state_0[pending_invalidate_index] <= 1'b0;
                    MESI_state_1[pending_invalidate_index] <= 1'b0;
                    pending_invalidate <= 0;
                    pending_invalidate_index <= 0;
                end
                    
                if (i_to_shared && o_snoop_hit && !i_active_op) begin
                    MESI_state_0[i_snoop_index] <= 1'b1;
                    MESI_state_1[i_snoop_index] <= 1'b0;
                end
            end
        end
        
    end
    
    
    /*
    // Snooping commands
    always @ (posedge clk) begin
        if (!nrst) begin
            pending_invalidate_index <= 0;
            pending_invalidate <= 0;
        end
        // Invalidates
        else begin
            if (i_invalidate && o_snoop_hit) begin
                if (potential_conflict) begin
                    pending_invalidate_index <= i_snoop_index;
                    pending_invalidate <= 1;
                end else begin
                    MESI_state_0[i_snoop_index] <= 1'b0;
                    MESI_state_1[i_snoop_index] <= 1'b0;
                end
            end
            
            
            if (i_done_state && pending_invalidate && o_snoop_hit)  begin // from the L1 Cache Controller
                MESI_state_0[pending_invalidate_index] <= 1'b0;
                MESI_state_1[pending_invalidate_index] <= 1'b0;
                pending_invalidate <= 0;
                pending_invalidate_index <= 0;
            end
                
            if (i_to_shared && o_snoop_hit) begin
                MESI_state_0[i_snoop_index] <= 1'b1;
                MESI_state_1[i_snoop_index] <= 1'b0;
            end
        end
    end
    */
    // Handle Conflicts
    always @ (*) begin
        case (i_active_op) 
            1'b1: begin
                if (i_index == i_snoop_index) potential_conflict <= 1'b1;
            end
            
            1'b0: begin
                potential_conflict <= 1'b0;
            end
            
            default: potential_conflict <= 1'b0;
            
            
        endcase
    end
endmodule
