`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2025 07:16:49 AM
// Design Name: 
// Module Name: tb_l2_axi
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


module tb_l2_axi(

    );
    
    reg clk, nrst;
    reg rd, wr;
    reg [3:0] dm_write;
    reg [11:0] data_addr;
    reg [31:0] data_i;
    
    wire [127:0] data_o;
    wire done;
    synthesis_check_top_modules
        UUT(
            .clk(clk),
            .nrst(nrst),
            .dm_write(dm_write),
            .rd(rd),
            .wr(wr),
            .data_addr(data_addr),
            .data_i(data_i),
            .data_o(data_o),
            .done(done)
        );
    /*
    wire [127:0] data_o;
    wire ready_mm;
    wire done;
    
    wire axi_rd, axi_wr;
    wire [31:0] axi_rd_addr;
    wire [31:0] axi_wr_addr;
    wire [127:0] axi_rd_block;
    wire [127:0] axi_wr_block;
    wire axi_rd_done;
    wire axi_wr_done;
    
    L2_cache_top #( .CACHE_WAY(2), .CACHE_SIZE(128), .ADDR_BITS(12) )
        UUT(
            .clk(clk),  .nrst(nrst),
            .i_dm_write(dm_write), 
            .i_rd(rd),
            .i_wr(wr),
            .i_data_addr(data_addr),
            .i_data(data_i),
            .i_ready_mm(1'b1),
            
            . o_data(data_o),	// data output to the RISC-V core
            .o_all_done(done),
            
            .o_axi_rd(axi_rd),
            .o_axi_wr(axi_wr),
            .o_axi_rd_addr(axi_rd_addr),
            .o_axi_wr_addr(axi_wr_addr),
            .i_axi_read_block(axi_rd_block),
            .o_axi_write_block(axi_wr_block),
            .i_axi_read_done(axi_rd_done),
            .i_axi_write_done(axi_wr_done)
	
        );
        
    wire awvalid, awready;
    wire [31:0] awaddr;
    wire [2:0] awsize;
    wire [1:0] awburst;
    wire [7:0] awlen;
    
    wire wvalid;
    wire wready;
    wire wlast;
    wire [31:0] wdata;
    wire [3:0] wstrb;
    
    wire bwready;
    wire bwvalid;
    wire [1:0] bresp;
    
    wire arvalid;
    wire arready;
    wire [31:0] araddr;
    wire [1:0] arburst;
    wire [2:0] arsize;
    wire [7:0] arlen;
    
    wire rvalid;
    wire rready;
    wire rlast;
    wire [1:0] rresp;
    wire [31:0] rdata;
    
    
    
    l2_axi_interface 
        interface (
        .clk(clk),  .nrst(nrst),
        .rd(axi_rd),      .wr(axi_wr),
        .rd_addr(axi_rd_addr), .wr_addr(axi_wr_addr),
        .data_i(axi_wr_block),  .data_o(axi_rd_block),
        
        .wr_done(axi_wr_done), .rd_done(axi_rd_done),
        
        // AXI PORTS
        
        .awvalid(awvalid),
        .awready(awready),
        .awaddr(awaddr),
        .awlen(awlen),      
        .awsize(awsize),    
        .awburst(awburst),
        
        .wvalid(wvalid),
        .wready(wready),
        .wlast(wlast),
        .wdata(wdata),
        .wstrb(wstrb),
        
        .bwready(bwready),
        .bwvalid(bwvalid),
        .bresp(bresp),
       
        .arvalid(arvalid),
        .arready(arready),
        .arburst(arburst),
        .arsize(arsize),
        .araddr(araddr),
        .arlen(arlen),
        
        .rvalid(rvalid),
        .rready(rready),
        .rlast(rlast),
        .rdata(rdata),
        .rresp(rresp)
        );
     
     //BRAM WIRES
     wire [11:0] bram_addr_a;
     wire bram_clk_a;
     wire [31:0] bram_wrdata_a;
     wire [31:0] bram_rddata_a;
     wire bram_en_a;
     wire [3:0] bram_we_a;
     
     wire [11:0] bram_addr_b;
     wire bram_clk_b; 
     wire [31:0] bram_wrdata_b;
     wire [31:0] bram_rddata_b;
     wire bram_en_b;
     wire [3:0] bram_we_b;
     
     axi_bram_ctrl_0 
        axi_bram(
            .s_axi_aclk(clk),
            .s_axi_aresetn(nrst),
            .s_axi_araddr(araddr),
            .s_axi_arburst(arburst),
            .s_axi_arlen(arlen),
            .s_axi_arready(arready),
            .s_axi_arsize(arsize),
            .s_axi_arvalid(arvalid),
            
            .s_axi_awaddr(awaddr),
            .s_axi_awburst(awburst),
            .s_axi_awlen(awlen),
            .s_axi_awready(awready),
            .s_axi_awsize(awsize),
            .s_axi_awvalid(awvalid),
            
            .s_axi_bready(bwready),
            .s_axi_bresp(bresp),
            .s_axi_bvalid(bwvalid),
            
            .s_axi_rready(rready),
            .s_axi_rdata(rdata),
            .s_axi_rlast(rlast),
            .s_axi_rresp(rresp),
            .s_axi_rvalid(rvalid),
            
            .s_axi_wdata(wdata),
            .s_axi_wlast(wlast),
            .s_axi_wready(wready),
            .s_axi_wstrb(wstrb),
            .s_axi_wvalid(wvalid),
            
            //bram side
            .bram_addr_a(bram_addr_a),
            .bram_clk_a(bram_clk_a),
            .bram_wrdata_a(bram_wrdata_a),
            .bram_rddata_a(bram_rddata_a),
            .bram_en_a(bram_en_a),
            .bram_rst_a(),
            .bram_we_a(bram_we_a),
            
            .bram_addr_b(bram_addr_b),
            .bram_clk_b(bram_clk_b),
            .bram_wrdata_b(bram_wrdata_b),
            .bram_rddata_b(bram_rddata_b),
            .bram_en_b(bram_en_b),
            .bram_rst_b(),
            .bram_we_b(bram_we_b)
        );  

    four_port_memory_construct # (.ADDR_WIDTH(12))
        memory (
            // PORT A - refills
            .clkA(bram_clk_a),
            .enaA(bram_en_a),
            .weA(bram_we_a),
            .addrA({2'b00,bram_addr_a[11:2]}),
            .doutA(bram_rddata_a),
            .dinA(bram_wrdata_a),
            
            // PORT B - Eviction
            .clkB(bram_clk_b),
            .enaB(bram_en_b),
            .weB(bram_we_b),
            .addrB({2'b00,bram_addr_b[11:2]}),
            .dinB(bram_wrdata_b),
            .doutB(bram_rddata_b),
            
            // PORT D
            .enaD(0),
            .enaC(0)
            
        );
     */   
     always #10 clk = ~clk;
     initial begin
        clk = 0;
        nrst = 0;
        rd = 0; 
        wr = 0;
        dm_write = 0;
        data_addr = 0;
        data_i = 0;
        #80
        nrst = 1;
        #100
        wr = 1;
        data_addr = 12'h004;
        dm_write = 4'b1111;
        data_i = 32'h01010122;
        #260
        wr = 0;
        rd = 0;
        #200
        rd = 1;
        data_addr = 12'h01C;
        #50
        rd =0;
        #200
        rd = 1;
        data_addr = 12'h044;
        #50
        rd = 0;       
        #250 
        rd = 1;
        data_addr = 12'h00C;
        #50
        rd = 0;
     end   
endmodule
