`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/24/2025 08:42:03 AM
// Design Name: 
// Module Name: bootloader_for_data
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:     A DMA core that connects a nonvolatile Block ROM to the DDR via an AXI interface 
//                  The idea is that we can store initial data to the Block ROM, transfer the data to its corresponding address in DDR
//                  
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bootloader_for_data
    #(
    parameter FIFO_BUFFER_SIZE = 256,
    parameter DDR_BASE_ADDRESS = 32'h8000_0000,
    parameter LOOP_COUNT = 32'h1
    )
    (
    input clk,
    input nrst,
    output reg done,
    
    // Block ROM ports
    output reg [9:0] bram_addr,  // 10-bits for 1 KB?
    input [31:0] bram_data,  //
    output reg bram_en,
    
    // AXI Ports
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
    output reg [31:0] m_awaddr, // Write address (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output reg [7:0] m_awlen, // Burst length (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output reg [2:0] m_awsize, // Burst size (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output reg [1:0] m_awburst, // Burst type (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output reg m_awvalid, // Write address valid (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input m_awready, // Write address ready (optional)
    

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output [31:0] m_wdata, // Write data (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output reg [3:0] m_wstrb, // Write strobes (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output reg m_wlast, // Write last beat (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output reg m_wvalid, // Write valid (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input m_wready, // Write ready (optional)
    

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input [1:0] m_bresp, // Write response (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input m_bvalid, // Write response valid (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output reg m_bready, // Write response ready (optional)
      

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output reg [31:0] m_araddr, // Read address (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
    output reg [7:0] m_arlen, // Burst length (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
    output reg [2:0] m_arsize, // Burst size (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
    output reg [1:0] m_arburst, // Burst type (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    output reg m_arvalid, // Read address valid (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input m_arready, // Read address ready (optional)
      

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input [31:0] m_rdata, // Read data (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input [1:0] m_rresp, // Read response (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
    input m_rlast, // Read last beat (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input m_rvalid, // Read valid (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output reg m_rready
    
    );
    
    // Parametrizable FIFO buffer
    reg [31:0] fifo_buffer [0:FIFO_BUFFER_SIZE-1];
    reg [31:0] fifo_out;
    // Write pointer and read pointer
    reg [$clog2(FIFO_BUFFER_SIZE)-1:0] write_ptr;
    reg [$clog2(FIFO_BUFFER_SIZE)-1:0] read_ptr;
    reg full;
    reg empty;
    
    // FIFO occupancy counter
    reg [31:0] fifo_count;
    
    // Counter storage
    reg [31:0] store_counter;
    
    // Delay counter
    reg [1:0] delay_counter; // Counter for the read latency in BRAM;
    
    // Registers
    reg valid_data;
    reg [2:0] i;
    
    
    // MAIN FSM
    reg [2:0] state;
    localparam S_START = 3'd0;
    localparam S_BRAM_READ = 3'd1;
    localparam S_AXI_START = 3'd2;
    localparam S_AXI_WRITE = 3'd3; 
    localparam S_AXI_RESP = 3'd4;
    localparam S_DONE = 3'd5;
    
    // FIFO Buffer
    always @ (posedge clk) begin
        if (!nrst) begin
            full <= 0;
            empty <= 1;
            //fifo_out <= 0;
            fifo_count <= 0;
        end else begin
              // Update full and empty flags
              full <= (fifo_count >= FIFO_BUFFER_SIZE-1);
              empty <= (fifo_count == 0);
         end
         

    end
    
    // Main FSM
    always @ (posedge clk) begin
        if (!nrst) begin
            state <= 0;
            done <= 0;
            bram_addr <= 0;
            bram_en <= 0;
            valid_data <= 0;
            write_ptr <= 0;
            read_ptr <= 0;
            delay_counter <= 0;
            i <= 0;
            
            // AXI STUFFS
            m_awaddr <= 0;
            m_awlen <= 0;
            m_awsize <= 0;
            m_awburst <= 0;
            m_awvalid <= 0;
            
            m_wvalid <= 0;
            m_wstrb <= 0;
            m_wlast <= 0;
            
            m_bready <= 0;
            
            
            m_araddr <= 0;
            m_arlen <= 0;
            m_arsize <= 0;
            m_arburst <=0;
            m_arvalid <= 0;
            
            m_rready <= 0;
            
        end else begin

            case (state)
            
                S_START: begin
                    // Prepare all necessary Block RAM signals
                    bram_en <= 1;
                    bram_addr <= i * 256;
                    state <= S_BRAM_READ;
                end
                
                S_BRAM_READ: begin
                    if (delay_counter == 1) begin 
                        delay_counter <= delay_counter + 1;
                        valid_data <= 1;
                    end else if (delay_counter == 2) begin
                        delay_counter <= 2;
                        
                    end else delay_counter <= delay_counter + 1;
                    
                    

                    if (valid_data && !full) begin
                        fifo_buffer[write_ptr] <= bram_data;
                        write_ptr <= write_ptr + 1;
                        fifo_count <= fifo_count + 1;
                        
                    end else if (full) begin
                        state <= S_AXI_START;
                        bram_en <= 0;
                    end
                end
                
                S_AXI_START: begin
                    // This state sends the base address
                    // The length
                    // The burst type
                    // Also we can assert the first valid data here
                    m_awaddr <= DDR_BASE_ADDRESS +  i * 32'h400;
                    m_awlen <= 8'd255; // Max value
                    m_awsize <= 3'b010;
                    m_awburst <= 2'b01;
                    m_awvalid <= 1;
                    
                    if (m_awready && m_awvalid) begin
                        state <= S_AXI_WRITE;
                        m_awvalid <= 0;
                    end

                end
                
                S_AXI_WRITE: begin
                    // Assert valid for first data
                    //m_wdata <= fifo_buffer[read_ptr];
                    m_wvalid <= 1;
                    m_wstrb <= 4'b1111;
                    
                    if (m_wvalid && m_wready) begin
                        read_ptr <= read_ptr + 1;
                    end
                    
                    if (read_ptr == 254) begin
                        m_wlast <= 1;
                    end
                    
                    if (m_wlast) begin
                        m_wlast <= 0;
                        state <= S_AXI_RESP;
                        m_wvalid <= 0;
                    end
                    //m_wdata <= fifo_buffer[read_ptr];
                    //if (m_wvalid && m_wready) begin
                    //    read_ptr <= read_ptr + 1;
                    //end
                end
                
                S_AXI_RESP: begin
                    m_bready <= 1;
                    if (m_bready && m_bvalid) begin 
                        // No error handling lol
                        // We ball
                        m_bready <= 0;
                        i <= i + 1;
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    // Cleanup
                     m_awvalid <= 0;
                     m_wvalid <= 0;
                     valid_data <= 0;
                     write_ptr <= 0;
                     read_ptr <= 0;
                     delay_counter <= 0;
                     fifo_count <= 0;
                     // Loop back if we still have data
                     if (i < LOOP_COUNT)  begin
                        state <= S_START;
                     end
                     else
                        done <= 1;
                end
                
            endcase
            
            if (bram_en) begin
                bram_addr <= bram_addr + 1;
            end
            
        end
    end
    
    always @ (negedge clk) begin
        // the negedge clk is for the output of the FIFO buffer
        fifo_out <= fifo_buffer[read_ptr];
    end
    assign m_wdata = fifo_out;
    
endmodule
