`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/11/2025 06:21:55 PM
// Design Name: 
// Module Name: tb_top
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


module tb_top();
    
    localparam CACHE_WAY = 2;
    localparam CACHE_SIZE = 1024;
    localparam ADDR_BITS = 12;
    
    reg clk, nrst;
    reg ready_mm;
    reg [4:0] counter;
    reg flush;
    
    
    // test consist of {read/write, address, data}
    // read = 0; write = 1;
    // so 1 + ADDR_BITS (12) + 32 bits = 45 bits
    localparam REQUEST_BITS = 1 + ADDR_BITS + 32;
    reg [ADDR_BITS + 32:0] test_requests[20:0];
    
    wire [31:0] data_out;
    wire done_signal;
    wire stall;
    wire [ADDR_BITS-1:0] data_addr;
    wire [31:0] data;
    wire wr;
    wire rd;
    wire done_flush;
    
    
    assign rd = ~test_requests[counter][ADDR_BITS + 32];
    assign wr = test_requests[counter][ADDR_BITS + 32];
    assign data = test_requests[counter][31:0];
    assign data_addr = test_requests[counter][REQUEST_BITS-2:32];
    
    cache_top # (.CACHE_WAY(CACHE_WAY), .CACHE_SIZE(CACHE_SIZE), .ADDR_BITS(ADDR_BITS))
        top_level (
            .clk(clk),      .nrst(nrst),
            .i_rd(rd),      .i_wr(wr),
            .i_ready_mm(ready_mm),
            .i_data_addr(data_addr),
            .i_data(data),
            .i_flush(flush),
            .i_dm_write(4'b1111),
            
            .o_data(data_out),  
            .o_all_done(done_signal),
            
            .o_stall(stall),
            .o_done_flush(done_flush)
            
        );

    always #10 clk = ~clk;
    
    reg gated_clk_core;

    always @(posedge clk or negedge clk) begin
        if (!stall)
            gated_clk_core <= clk;  // Pass through the clock
    end
       
    integer TEST_CASE = 10; //6 cases minus 1
    reg [9:0] ADDR_TB;
    reg complete;
    reg [9:0] pass;
    initial begin
        // Test requests
        // writes first, same block
        test_requests[0] = {1'b1,12'h000, 32'h11223344};
        test_requests[1] = {1'b1, 12'h004, 32'h11223344};
        test_requests[2] = {1'b1, 12'h008, 32'h11223344};
        test_requests[3] = {1'b1,12'h00C, 32'h11223344};
        test_requests[4] = {1'b1, 12'h010, 32'h11223344};
        test_requests[5] = {1'b1, 12'h014, 32'h11223344};
        test_requests[6] = {1'b1, 12'h018, 32'h11223344};
        test_requests[7] = {1'b1, 12'h01C, 32'h11223344};
        test_requests[8] = {1'b1, 12'h020, 32'h11223344};
        test_requests[9] = {1'b1, 12'h024, 32'h11223344};
        test_requests[10] = {1'b1, 12'h028, 32'h11223344};
        test_requests[11] = {1'b1, 12'h02C, 32'h11223344};
        
        
        clk = 0;
        gated_clk_core = 0;
        nrst = 0;
        complete <= 0;
        flush = 0;
        counter = 0;
        ready_mm = 0;
        ADDR_TB = 0;
        pass = 0;
        #200
        nrst = 1;
        #60
        ready_mm = 1;
    end
    
    always @ (posedge clk) begin
       if (done_signal ) begin
            if (counter < TEST_CASE) begin
                counter <= counter + 1;
            end  
            else begin
                $display("[%0t] Test cases completed.", $time);
                counter <= 0;
                flush <= 1;
            end
            
       end
       
       if (done_flush) begin
            complete <= 1;
            if (!complete) 
                begin
                    $display("[%0t] Flush  completed.", $time);        
                end
            if (complete) begin
                if ( cache_top.bram.ram_block[ADDR_TB] == 32'h44332211)
                    pass <= pass + 1;
                ADDR_TB <= ADDR_TB + 1;
            end
            if (ADDR_TB == TEST_CASE + 1) begin
                $display("Pass counter: %d", pass, " out of %d", TEST_CASE+1);
                $finish;
            end
        end
    end
endmodule
