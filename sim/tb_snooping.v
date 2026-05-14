`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2025 07:19:45 PM
// Design Name: 
// Module Name: tb_snooping
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


module tb_snooping(

    );
    localparam CACHE_WAY = 2;
    localparam CACHE_SIZE = 128;
    localparam ADDR_BITS = 12;
    
    reg clk, nrst;
    reg [ADDR_BITS-1:0] ext_addr;
    
    reg ext_wr, ext_rd;
    
    wire done_signal;
    wire [31:0] data_o;
    
    reg tests_done;
    
    reg [31:0] counter;
    reg [31:0] checking_counter;
    integer TEST_CASES = 12;
   // test consist of {data_check, read/write, address, data}
    // read = 0; write = 1;
    // so 1 + ADDR_BITS (12) + 32 bits = 45 bits
    localparam REQUEST_BITS = 1 + 1 + ADDR_BITS + 32;
    reg [1 + ADDR_BITS + 32:0] test_requests[20:0];
    reg [31:0] ANSWERKEY[20:0];
    
    wire rd, wr, data_check;
    wire [31:0] data;
    wire [ADDR_BITS-1:0] data_addr;
    assign data_check = test_requests[counter][REQUEST_BITS-1];
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
            
            .ext_addr(ext_addr),
            .ext_wr(ext_wr),
            .ext_rd(ext_rd),
            .i_data_check(data_check),
            
            .is_checking(0)
            //.tb_addr(tb_addr),
            //.tb_data_cache(tb_data_cache),
            //.tb_data_ram(tb_data_ram),
            //.tb_hit(tb_hit)
            
        );
     always #10 clk = ~clk;
     initial begin
        clk = 0;
        nrst = 0;
        counter = 0;
        checking_counter = 0;
        ext_rd = 0;
        ext_wr = 0;
        test_requests[0] = {1'b0, 1'b1,12'h000, 32'hC0E19900};
        test_requests[1] = {1'b0, 1'b0, 12'h010, 32'h0};
        test_requests[2] = {1'b1, 1'b1, 12'h008, 32'hFFFF1111};
        test_requests[3] = {1'b0, 1'b1,12'h00C, 32'h1111FFFF};
        test_requests[4] = {1'b1, 1'b0, 12'h010, 32'h0};
        test_requests[5] = {1'b0, 1'b0, 12'h014, 32'h0};
        test_requests[6] = {1'b1, 1'b1, 12'h018, 32'hCCEECCEE};
        test_requests[7] = {1'b1, 1'b0, 12'h01C, 32'h0};
        test_requests[8] = {1'b0, 1'b0, 12'h020, 32'H0};
        
        test_requests[9] = {1'b0, 1'b0, 12'h024, 32'h0};
        test_requests[10] = {1'b0, 1'b0, 12'h028, 32'h0};
        test_requests[11] = {1'b0, 1'b0, 12'h02C, 32'h0};
        #80 
        nrst = 1;

     end
     
      always @ (posedge clk) begin
       
           if (done_signal) 
            if (counter == TEST_CASES - 1) begin
                tests_done <= 1;
                //$display(UUT.L1_cache.tag_array.tag_mem_way[0].small_tag_mem.MESI_state_0);
                //$display(UUT.L1_cache.tag_array.tag_mem_way[0].MESI_state_1);
            end else begin
                counter <= counter + 1; 
            end
    end
    
endmodule
