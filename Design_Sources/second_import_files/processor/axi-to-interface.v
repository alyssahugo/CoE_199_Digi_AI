`timescale 1ns / 1ps


module axi_lite_to_interface #(
        parameter AWIDTH = 8
    ) (
        input aclk,                    // AXI global clock
        output clk_out,
        
        input aresetn,                 // AXI active-low global reset
        output nrst_out,
        
        // Write Address Channel
        input awvalid,                  // AXI [master] write address valid                            
        output awready,                  // AXI [slave] write address ready
        input [31:0] awaddr,           // AXI [master] write address
        // input [2:0] awprot,            // AXI [master] write protection type
        // Write Data Channel
        input wvalid,                  // AXI [master] write data valid
        output wready,                   // AXI [slave] write data ready
        input [31:0] wdata,            // AXI [master] write data
        input [3:0] wstrb,             // AXI [master] write strobes
                                        // -- byte enables
        // Write Response Channel
        output reg bvalid,                  // AXI [slave] write response valid
        input bready,                  // AXI [master] write response ready
        output [1:0] bresp,              // AXI [slave] write response
        
        // Read Address Channel
        input arvalid,                 // AXI [master] read address valid                            
        output arready,                  // AXI [slave] read address ready
        input [31:0] araddr,           // AXI [master] read address
        // input [2:0] arprot,            // AXI [master] read protection type     
        // Read Data Channel
        output reg rvalid,                  // AXI [slave] read data valid
        input rready,             // AXI [master] read data ready
        output reg[31:0] rdata,            // AXI [slave] read data
        output [1:0] rresp,             // AXI [slave] read response
        
        // Core Memory Interface        
        output reg i_ready,                  // Initiated memory transaction
        input i_gnt,                   // Completed write/issued read
        input i_valid,                 // Completed read
        
        output reg [31:0] i_wrdata,          // Write data input
        output reg [31:0] i_addr,            // Transaction Address
        output reg [3:0] i_wren,             // (Write) Byte Enables
        input [31:0] i_rddata          // Read data output
    );
    
    assign clk_out = aclk;
    assign nrst_out = aresetn;
    assign bresp = 'h0;
    assign wresp = 'h0;
    
    // Interface always ready to handle inbound transactions
    assign wready = 1;
    assign awready = 1;
    assign arready = 1;
    
    // Process inbound AXI handshakes
    reg busy;
    reg read;
    
    always@(posedge aclk) begin
        if(!aresetn) begin
            busy <= 0;
            read <= 0;
            rvalid <= 0;
            bvalid <= 0;
            rdata <= 'h0;
            
            i_ready <= 0;
            
            i_wrdata <= 'h0;
            i_addr <= 'h0;
            i_wren <= 'h0;
        end
        else begin
            if (!busy) begin
                // Inbound read
                if (arvalid) begin
                    busy <= 1;
                    read <= 1;
                    rvalid <= 0;
                    bvalid <= 0;
                    rdata <= 'h0;
                    
                    i_ready <= 1;
                    
                    i_wrdata <= 'h0;
                    i_addr <= araddr;
                    i_wren <= 'h0;
                end
                // Inbound write
                else if (wvalid && awvalid) begin
                    busy <= 1;
                    read <= 0;
                    rvalid <= 0;
                    bvalid <= 0;
                    rdata <= 'h0;
                    
                    i_ready <= 1;
                    
                    i_wrdata <= wdata;
                    i_addr <= awaddr;
                    i_wren <= wstrb;
                end
                else begin
                    busy <= 0;
                    read <= 0;
                    rvalid <= 0;
                    bvalid <= 0;
                    rdata <= 'h0;
                    
                    i_ready <= 0;
                    
                    i_wrdata <= 'h0;
                    i_addr <= 'h0;
                    i_wren <= 'h0;
                end
            end
            // active transaction
            else begin
                if (read) begin
                    if (i_valid) begin
                        busy <= 0;
                        read <= 0;
                        rvalid <= 1;
                        bvalid <= 0;
                        rdata <= i_rddata;
                        
                        i_ready <= 0;
                        
                        i_wrdata <= 'h0;
                        i_addr <= 'h0;
                        i_wren <= 'h0;
                    end
                    else begin
                        busy <= busy;
                        read <= read;
                        rvalid <= rvalid;
                        bvalid <= bvalid;
                        
                        i_ready <= i_ready;
                        
                        i_wrdata <= i_wrdata;
                        i_addr <= i_addr;
                        i_wren <= i_wren;
                    end
                end
                // write
                else begin
                    if (i_gnt) begin
                        busy <= 0;
                        read <= 0;
                        rvalid <= 0;
                        bvalid <= 1;
                        rdata <= 'h0;
                        
                        i_ready <= 0;
                        
                        i_wrdata <= 'h0;
                        i_addr <= 'h0;
                        i_wren <= 'h0;
                    end
                    else begin
                        busy <= busy;
                        read <= read;
                        rvalid <= rvalid;
                        bvalid <= bvalid;
                        
                        i_ready <= i_ready;
                        
                        i_wrdata <= i_wrdata;
                        i_addr <= i_addr;
                        i_wren <= i_wren;
                    end
                end
            end
        end
    end
    
endmodule
