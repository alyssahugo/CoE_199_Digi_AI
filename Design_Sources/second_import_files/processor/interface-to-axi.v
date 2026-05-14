`timescale 1ns / 1ps

// Data Memory Interface to AXI4-Lite Channel
// Partial implementation excl. error-handling support
// Only 1 transaction at a time is allowed

module interface_to_axi_lite #(
        parameter AWIDTH = 8
    ) (
        input clk,
        output aclk,                    // AXI global clock
        
        input nrst,
        output aresetn,                 // AXI active-low global reset
        
        // Write Address Channel
        output reg awvalid,                 // AXI [master] write address valid                            
        input awready,                  // AXI [slave] write address ready
        output [31:0] awaddr,           // AXI [master] write address
        output [2:0] awprot,            // AXI [master] write protection type       -- default output: 000
        // Write Data Channel
        output reg wvalid,                  // AXI [master] write data valid
        input wready,                   // AXI [slave] write data ready
        output [31:0] wdata,            // AXI [master] write data
        output [3:0] wstrb,             // AXI [master] write strobes
                                        // -- byte enables
        // Write Response Channel
        input bvalid,                  // AXI [slave] write response valid
        output bready,                  // AXI [master] write response ready
        input [1:0] bresp,              // AXI [slave] write response
        
        // Read Address Channel
        output reg arvalid,                 // AXI [master] read address valid                            
        input arready,                  // AXI [slave] read address ready
        output [31:0] araddr,           // AXI [master] read address
        output [2:0] arprot,            // AXI [master] read protection type       -- default output: 000
        // Read Data Channel
        input rvalid,                  // AXI [slave] read data valid
        output reg rready,             // AXI [master] read data ready
        input [31:0] rdata,            // AXI [slave] read data
        input [1:0] rresp,             // AXI [slave] read response
        
        // Core Memory Interface        
        input i_ready,                  // Initiated memory transaction
        output reg i_gnt,                   // Completed write/issued read
        output reg i_valid,                 // Completed read
        
        input [31:0] i_wrdata,          // Write data input
        input [31:0] i_addr,            // Transaction Address
        input [3:0] i_wren,             // (Write) Byte Enables
        output [31:0] i_rddata          // Read data output
    );
    
    reg active;
    reg [3:0] wren_hold;
    wire write_op = active ? |{wren_hold} : |{i_wren};
    reg [31:0] wrdata_hold;
    reg [31:0] addr_hold;
    reg [31:0] rddata_hold;
    
    // default outputs -- ignore protection modes
    assign awprot = 'b000;
    assign arprot = 'b000;
    assign bready = 1;                  // Ignore all slave responses (temp.)
    
    // Signal pass-through
    assign aclk = clk;
    assign aresetn = nrst;
    // Write channels
    assign awaddr = write_op ? addr_hold : 'h0;
    assign wdata = write_op ? wrdata_hold : 'h0;
    assign wstrb = write_op ? wren_hold : 'h0;
    // Read channels                   
    assign araddr = ~write_op ? addr_hold : 'h0;           // AXI [master] read address
    
    // Process memory transactions
    always@(posedge clk) begin
        if (!nrst) begin
            active <= 0;
            wren_hold <= 'h0;
            wrdata_hold <= 'h0;
            rddata_hold <= 'h0;
            addr_hold <= 'h0;
            
            awvalid <= 0;
            wvalid <= 0;
            
            arvalid <= 0;
            rready <= 0;
            
            i_gnt <= 0;
            i_valid <= 0;
        end
        else begin
            if (active) begin
                // Write operations wait for (any) write response
                if (write_op) begin
                    i_gnt <= 0;             // 1 cycle assert for datamem interface only
                    // AXI4 write spec --> 1 cycle assert if ready
                    if (wready) begin
                        wvalid <= 0; 
                    end
                    if (awready) begin
                        awvalid <= 0;
                    end
                    if (bvalid) begin
                        // break off, bready already asserted by default
                        wvalid <= 0;
                        awvalid <= 0;
                        active <= 0;
                        wren_hold <= 'h0;
                        wrdata_hold <= 'h0;
                        addr_hold <= 'h0;
                        
                    end
                end
                // Read operations wait for (any) read response
                else if (~write_op && rvalid) begin
                    // AXI4 read spec --> 1 cycle assert if ready by default
                    if (arready) begin
                        arvalid <= 0;
                    end
                    // If read data ready, finish transaction
                    if (rvalid) begin
                        rready <= 0;
                        arvalid <= 0;
                        active <= 0;
                        addr_hold <= 'h0;
                        
                        rddata_hold <= rdata;
                        i_valid <= 1;
                    end
                end
                // Leave everything as-is otherwise
            end
            else begin
                // New memory transaction
                if (i_ready) begin
                    active <= 1;
                    addr_hold <= i_addr; 
                    if (write_op) begin
                        wren_hold <= i_wren;
                        wrdata_hold <= i_wrdata;
                        awvalid <= 1;
                        wvalid <= 1;
                        i_gnt <= 1;
                        i_valid <= 0;
                    end
                    else begin
                        arvalid <= 1;
                        rready <= 1;
                        
                        rddata_hold <= 'h0;
                        
                        i_gnt <= 1;
                        i_valid <= 0;
                    end
                end
                // Stay idle
                else begin
                    active <= 0;
                    wren_hold <= 'h0;
                    wrdata_hold <= 'h0;
                    rddata_hold <= 'h0;
                    addr_hold <= 'h0;
                    
                    awvalid <= 0;
                    wvalid <= 0;
                    
                    arvalid <= 0;
                    rready <= 0;
                    
                    i_gnt <= 0;
                    i_valid <= 0;
                end
            end
        end
    end
    
    
endmodule
