`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2025 10:22:13 AM
// Design Name: 
// Module Name: tb_l1_l2_caches
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


module tb_l1_l2_caches(

    );
 
    localparam CACHE_WAY = 2;
    localparam CACHE_SIZE = 1024;
    localparam ADDR_BITS = 12;
    
    reg clk, nrst;
    reg ready_mm;
    reg [4:0] counter;
    reg [4:0] checking_counter;
    
    
    // test consist of {read/write, address, data}
    // read = 0; write = 1;
    // so 1 + ADDR_BITS (12) + 32 bits = 45 bits
    localparam REQUEST_BITS = 1 + ADDR_BITS + 32;
    reg [ADDR_BITS + 32:0] test_requests[20:0];
    reg [31:0] ANSWERKEY[20:0];
    

    wire done_signal;
    wire stall;
    wire [ADDR_BITS-1:0] data_addr;
    wire [31:0] data;
    wire wr;
    wire rd;
    wire [31:0] data_o;
    wire tb_hit;
    wire [31:0] tb_data_cache;
    wire [31:0] tb_data_ram;
    
    reg tests_done;
    reg [ADDR_BITS-1:0] tb_addr;
    
    assign rd = ~test_requests[counter][ADDR_BITS + 32];
    assign wr = test_requests[counter][ADDR_BITS + 32];
    assign data = test_requests[counter][31:0];
    assign data_addr = test_requests[counter][REQUEST_BITS-2:32];
    
    l1_l2_caches_top #(.CACHE_WAY(CACHE_WAY), .CACHE_SIZE(CACHE_SIZE), .ADDR_BITS(ADDR_BITS))
        UUT(
            .clk(clk),     .nrst(nrst),
            .i_data(data), .i_addr(data_addr),
            .i_dm_write(4'b1111), .i_rd(rd),
            .i_wr(wr),
            
            .o_data(data_o),
            .all_done(done_signal),
            
            .is_checking(tests_done),
            .tb_addr(tb_addr),
            .tb_data_cache(tb_data_cache),
            .tb_data_ram(tb_data_ram),
            .tb_hit(tb_hit)
            
        );

    always #10 clk = ~clk;
    
    reg gated_clk_core;

    always @(posedge clk or negedge clk) begin
        if (!stall)
            gated_clk_core <= clk;  // Pass through the clock
    end
       
    integer TEST_CASES = 12;
    integer PASS = 0;
    
    
    
    initial begin
        // Test requests
        // writes first, same block
        test_requests[0] = {1'b1,12'h000, 32'hC0E19900};
        test_requests[1] = {1'b0, 12'h004, 32'h0};
        test_requests[2] = {1'b1, 12'h008, 32'hFFFF1111};
        test_requests[3] = {1'b1,12'h00C, 32'h1111FFFF};
        test_requests[4] = {1'b0, 12'h010, 32'h0};
        test_requests[5] = {1'b0, 12'h014, 32'h0};
        test_requests[6] = {1'b1, 12'h018, 32'hCCEECCEE};
        test_requests[7] = {1'b0, 12'h01C, 32'h0};
        test_requests[8] = {1'b0, 12'h000, 32'H0};
        
        test_requests[9] = {1'b0, 12'h000, 32'h0};
        test_requests[10] = {1'b0, 12'h000, 32'h0};
        test_requests[11] = {1'b0, 12'h000, 32'h0};
        
        
        ANSWERKEY[0] = 32'hC0E19900;
        ANSWERKEY[1] = 32'h1111000A;
        ANSWERKEY[2] = 32'hFFFF1111;
        ANSWERKEY[3] = 32'h1111FFFF;
        ANSWERKEY[4] = 32'h51100013;
        ANSWERKEY[5] = 32'h1645255F;
        ANSWERKEY[6] = 32'hCCEECCEE;
        ANSWERKEY[7] = 32'h317D255F;
        ANSWERKEY[8] = 32'h1F34255F;
        ANSWERKEY[9] = 32'h99999999;
        ANSWERKEY[10] = 32'h10101010;
        ANSWERKEY[11] = 32'h00000001;
        

        clk = 0;
        gated_clk_core = 0;
        tests_done = 0;
        checking_counter = 0;
        nrst = 0;
        tb_addr = 0;
        counter = 0;
        ready_mm = 0;
        #80
        nrst = 1;
        #60
        ready_mm = 1;
    end
    
    
    always @ (posedge clk) begin
       
       if (done_signal) 
        if (counter == TEST_CASES - 1) begin
            tests_done <= 1;
        end else begin
            counter <= counter + 1; 
        end
    end

    // check the contents of the cache and the bram
    always @ (posedge clk) begin
        if (tests_done) begin
            if (tb_hit) begin
                if (tb_data_cache == ANSWERKEY[tb_addr >> 2]) begin
                    PASS = PASS + 1;
                    checking_counter = checking_counter + 1;
                    $display(" CACHE HIT! Expected: %h. Actual: %h. -----------PASS", ANSWERKEY[tb_addr >> 2], tb_data_cache);
                    tb_addr = tb_addr + 4;
                    
                end 
                else begin
                    $display(" CACHE HIT! Expected: %h. Actual: %h. -----------FAIL", ANSWERKEY[tb_addr >> 2], tb_data_cache);
                    tb_addr = tb_addr + 4;
                    checking_counter = checking_counter + 1;
                end
            end else begin
                // check the BRAM
                 if (tb_data_ram == ANSWERKEY[tb_addr >> 2]) begin
                    PASS = PASS + 1;
                    checking_counter = checking_counter + 1;
                    $display("Expected: %h. Actual: %h. -----------PASS", ANSWERKEY[tb_addr >> 2], tb_data_ram);
                    tb_addr = tb_addr + 4;
                    
                end else begin
                     $display("Expected: %h. Actual: %h. -----------FAIL", ANSWERKEY[tb_addr >> 2], tb_data_ram);
                    tb_addr = tb_addr + 4;
                    checking_counter = checking_counter + 1;
                end
            end
        end
        if (checking_counter == TEST_CASES-1) begin
            $display("Passed %d out of %d tests", PASS, TEST_CASES);
            $finish;
        end
    end
endmodule
