`timescale 1ns / 1ps

module snoop_controller 
    # (
    parameter ADDR_BITS = 12,
    parameter CACHE_WAY = 4,
    parameter CACHE_SIZE = 4096, // bytes
    parameter OFFSET_BITS = 2,
    parameter BLOCK_SIZE = 16, // 16 bytes per one block (4 words), always
    parameter NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE,
    parameter NUM_SETS = NUM_BLOCKS / CACHE_WAY,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS - 2
    )
    (
    input wire clk,
    input wire nrst,
    input wire read,                 // Read signal 
    input wire write,                // Write signal
    input wire hit,                  // Hit signal (1 = hit, 0 = miss)
    input [1:0] MESI_in_hold,       // carries address MESI state
    input [1:0] own_MESI_in_hold,
    
    input wire ccu_req_in,           // Signal for internal state transitions and snoop handling
    input wire data_check,           // Response from another cache (1 = has data, 0 = no data)
    
    //From other cache
    input wire ext_read,       // Snoop hit due to a read
    input wire ext_write,      // Snoop hit due to a write
    //input wire scu_req_in,           // Signal for external snoop request handling   
    input [ADDR_BITS-1:0]   ext_addr,
    output data_response,
    output [TAG_BITS-1:0] snooping_tags,
    output  [INDEX_BITS-1:0] snooping_index,
    output invalidate,
    output reserve_exclusive,
    output shared,


    
    output snoop,                //to dcache controller for snoop_complete
    output reg [1:0] MESI_state,          // state: 00 = Invalid, 01 = Shared, 10 = Exclusive, 11 = Modified
    
    output data_request,       // Response to snoop check (1 = has data, 0 = no data)
    output  snoop_hit_read_out,   // Snoop read hit indication
    output  snoop_hit_write_out,  // Snoop write hit indication
    output  scu_req_out,       // Snoop request output for external handling
    output  mem_req_out,
    output  reg snoop_tag_ok  //Ok signal to validate that snoop tag is correct
);
    

    // State encoding
    localparam INVALID   = 2'b00;
    localparam SHARED    = 2'b01;
    localparam EXCLUSIVE = 2'b11;
    localparam MODIFIED  = 2'b10;
    
    wire dcache_req_snoop;
    wire external_req_snoop;
    
    wire dcache_req_MESI;
    wire external_req_MESI;
    
    assign snoop = dcache_req_snoop || external_req_snoop;
    //assign MESI_state = dcache_req_MESI || external_req_MESI; // this will cause either 11 or 00 lang since OR siya eh
    
    
    // Parse the incoming addr from the other cache
    wire scu_req_in;

    assign snooping_index =  ext_addr[ADDR_BITS - TAG_BITS - 1: 4];
    assign snooping_tags = ext_addr[ADDR_BITS - 1 : ADDR_BITS - TAG_BITS ];
    assign scu_req_in = ext_read || ext_write;
    
    
    always @(*) begin
        if (!nrst) begin
                MESI_state <= 0;
                snoop_tag_ok <= 0;
        end else begin
            if (external_req_snoop) begin
                MESI_state <= external_req_MESI;
                snoop_tag_ok <= 1;
            end else if (dcache_req_snoop) begin
                MESI_state <= dcache_req_MESI;
                snoop_tag_ok <= 1;
            end else begin
                MESI_state <= 0;
                snoop_tag_ok <= 0;
            end
        end
    end
    
    
    DCache_Request dcache_req (
    .clk(clk),
    .nrst(nrst),
    .read(read),            
    .hit(hit),                 
    .MESI_in_hold(own_MESI_in_hold),  
    
    .ccu_req_in(ccu_req_in),         
    .data_check(data_check),         
    
    .snoop(dcache_req_snoop),               
    .MESI_state(dcache_req_MESI),        
    
    .data_request(data_request),      
    .snoop_hit_read_out(snoop_hit_read_out),  
    .snoop_hit_write_out(snoop_hit_write_out), 
    .scu_req_out(scu_req_out),       
    .mem_req_out(mem_req_out),
    
    .exclusive(reserve_exclusive)
);

    External_Request external_req (
    .clk(clk),
    .nrst(nrst),
    .MESI_in_hold(MESI_in_hold),   
    
    .snoop_hit_read(ext_read),       
    .snoop_hit_write(ext_write),      
    .scu_req_in(scu_req_in),           

    //.snoop(external_req_snoop),
    .MESI_state(external_req_MESI),  
    
    .invalidate(invalidate),
    .shared(shared),
    .response(data_response)        
);


endmodule
