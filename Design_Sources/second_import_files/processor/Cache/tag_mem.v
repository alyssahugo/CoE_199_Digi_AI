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


module tag_mem #(
    parameter TAG_BITS = 5,
    parameter INDEX_BITS = 3
    )(
    input clk,
    input nrst,
    input                       i_wr_en,
    input   [TAG_BITS-1:0]      i_tag,
    input   [INDEX_BITS-1:0]    i_index,
    input                       i_modify,
    input                       i_to_shared,
    input                       i_am_LRU,
    
    // Snooping protocol  
    /*
    input   [TAG_BITS-1:0]      i_snoop_tags,
    input   [INDEX_BITS-1:0]    i_snoop_index,
    input                       i_invalidate,
    input                       i_reserve_exclusive,
    output [1:0]                o_snooping_mesi,
    output                      o_snoop_match,
    output                      o_snoop_hit,
    output [1:0]                o_own_mesi,
    */
    output  [TAG_BITS + 1:0]    o_tag,
    //output [TAG_BITS + 1:0]     o_tag_flush,
    output                      o_hit
    );
    
    localparam NUM_SETS = 1 << INDEX_BITS;
    localparam TAG_BITS_WITH_LRU = TAG_BITS + 2;        //each entry: {2 bit MESI state + TAG}
    
    // 1D tag memory
    reg [TAG_BITS-1:0] tag_mem[NUM_SETS-1:0];
    reg [TAG_BITS-1:0] out_tag;
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


    
    
    // ============ ASSIGN WIRES ====================//
    
    reg MESI_state_bit_0;
    reg MESI_state_bit_1;
    wire [1:0] MESI;
    wire [1:0] MESI_snoop;
    wire valid;
    wire match;



    assign MESI = {MESI_state_bit_1, MESI_state_bit_0};
    //assign MESI_snoop = {MESI_state_1[i_snoop_index] ,MESI_state_0[i_snoop_index]};
    
    assign o_tag = (i_am_LRU) ? {MESI, out_tag} : 0;
    //assign o_tag_flush = {MESI,tag_mem[i_index]};
    
    assign valid = (MESI == 2'b00) ? 1'b0 : 1'b1;
    assign match = (out_tag == i_tag) ? 1'b1 : 1'b0;
    assign o_hit = (valid) ? (match ? 1'b1 : 1'b0) : 1'b0;
    
    // Snooping
    //assign o_snoop_valid = (MESI_snoop == 2'b00) ? 1'b0 : 1'b1;
    //assign o_snoop_hit = o_snoop_valid && o_snoop_match;
    //assign o_snoop_match = (tag_mem[i_snoop_index] == i_snoop_tags) ? 1'b1 : 1'b0;
    //assign o_snooping_mesi = (o_snoop_match && o_snoop_valid) ? {MESI_state_1[i_snoop_index], MESI_state_0[i_snoop_index] } : 0;
    //assign o_own_mesi = MESI;
    integer i;
    initial begin
        MESI_state_0 <= 0;
        MESI_state_1 <= 0;
        for (i = 0; i < NUM_SETS; i = i+ 1) begin
            tag_mem[i] <= 0;
        end
    end
    
    // ============ SYNCHRONOUS WRITE ================//
    
    always @(posedge clk) begin
        if (!nrst) begin
           MESI_state_0 <= 0;
           MESI_state_1 <= 0;

           
        end
        else begin
            out_tag <= tag_mem[i_index];
            MESI_state_bit_0 <= MESI_state_0[i_index];
            MESI_state_bit_1 <= MESI_state_1[i_index];
            if (i_wr_en && i_am_LRU) begin
                tag_mem[i_index] <= i_tag;
                //shared
                MESI_state_0[i_index] <= 1'b1;
                MESI_state_1[i_index] <= 1'b0;
            end
            
            else if (i_modify) begin
                MESI_state_0[i_index] <= 1'b0;
                MESI_state_1[i_index] <= 1'b1;
            end 
        end
    end
    
    
    
    
endmodule
