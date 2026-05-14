`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 08:40:04 AM
// Design Name: 
// Module Name: mcycles
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

module mcycles (
    input clk,
    input nrst,
    
  // Uncomment the following to set interface specific parameter on the bus interface.
  //  (* X_INTERFACE_PARAMETER = "CLK_DOMAIN <value>,PHASE <value>,MAX_BURST_LENGTH <value>,NUM_WRITE_OUTSTANDING <value>,NUM_READ_OUTSTANDING <value>,SUPPORTS_NARROW_BURST <value>,READ_WRITE_MODE <value>,BUSER_WIDTH <value>,RUSER_WIDTH <value>,WUSER_WIDTH <value>,ARUSER_WIDTH <value>,AWUSER_WIDTH <value>,ADDR_WIDTH <value>,ID_WIDTH <value>,FREQ_HZ <value>,PROTOCOL <value>,DATA_WIDTH <value>,HAS_BURST <value>,HAS_CACHE <value>,HAS_LOCK <value>,HAS_PROT <value>,HAS_QOS <value>,HAS_REGION <value>,HAS_WSTRB <value>,HAS_BRESP <value>,HAS_RRESP <value>" *)
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
  input [3:0] s_awaddr, // Write address
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWLEN" *)
  input [7:0] s_awlen, // Burst length 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWSIZE" *)
  input [2:0] s_awsize, // Burst size 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWBURST" *)
  input [1:0] s_awburst, // Burst type 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
  input s_awvalid, // Write address valid 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
  output reg s_awready, // Write address ready 
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
  input [31:0] s_wdata, // Write data 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
  input [3:0] s_wstrb, // Write strobes 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WLAST" *)
  input s_wlast, // Write last beat
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
  input s_wvalid, // Write valid 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
  output reg s_wready, // Write ready 
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
  output reg [1:0] s_bresp, // Write response
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
  output reg s_bvalid, // Write response valid
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
  input s_bready, // Write response ready
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
  input [3:0] s_araddr, // Read address
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARLEN" *)
  input [7:0] s_arlen, // Burst length 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARSIZE" *)
  input [2:0] s_arsize, // Burst size 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARBURST" *)
  input [1:0] s_arburst, // Burst type 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
  input s_arvalid, // Read address valid 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
  output reg s_arready, // Read address ready 
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
  output reg [31:0] s_rdata, // Read data 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
  output reg [1:0] s_rresp, // Read response 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RLAST" *)
  output reg s_rlast, // Read last beat 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
  output reg s_rvalid, // Read valid 
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
  input s_rready // Read ready 
//  additional ports here


);

//  user logic here
    
    // Registers that we can read:
    // Clock Counter (at offset 0x0)
    reg [31:0] clock_counter;
    
    // Cycles counter
    always @ (posedge clk) begin
        if (!nrst) begin
            clock_counter <= 0;
        end
        else begin
            clock_counter <= clock_counter + 1;
        end
    end
    
    
    
    // FSM for Reads
    reg [2:0] state;
    localparam S_IDLE = 3'd0;           // Idle state, waits for a request from an AXI Master
    localparam S_REQ = 3'd1;            // A read request is accepted. Check appropriate register to put into output port (for now its just the clock counter)
    localparam S_READY_OUTPUT = 3'd2;   // The proper register reading is latched unto the output. Wait for ready signal from the requesting Master, assert valid signal
    localparam S_DONE = 3'd4;           // Cleanup. Deassert valid signals, reload ready signals
    
    reg [31:0] addr_in;
    reg [31:0] output_reg;
    
    always @ (posedge clk) begin
        if (!nrst) begin
            state <= S_IDLE;
            addr_in <= 0;
            output_reg <= 0;
            s_arready <= 0;
            s_rdata <= 0;
            s_rresp <= 0;
            s_rlast <= 0;
            s_rvalid <= 0;
        end
        else begin
        
            case (state)
            
                S_IDLE: begin
                    if (s_arvalid && s_arready) begin // Ready Valid Handshake
                        s_arready <= 0;
                        state <= S_REQ;
                        addr_in <= s_araddr;
                    end else begin
                        state <= S_IDLE;
                        s_arready <= 1;
                        s_rvalid <= 0;
                        addr_in <= 0;
                    end
                end
                
                S_REQ: begin
                    // Check what register we are reading
                    // Last 4 bits (offset)
                    if (addr_in[4:0] == 0)  begin // A core is requesting to read the current clock cycle
                        output_reg <= clock_counter;
                        state <= S_READY_OUTPUT;
                    end
                    else begin // we need to ensure that we are going to complete the transaction (no deadlocks)
                        output_reg <= 0;
                        state <= S_READY_OUTPUT;
                    end
                    
                end
                
                S_READY_OUTPUT: begin
                    s_rdata <= output_reg;
                    s_rresp <= 2'b00;
                    s_rlast <= 1;
                    s_rvalid <= 1;
                    if (s_rvalid && s_rready) begin
                        state <= S_DONE;
                        s_rvalid <= 0;
                        s_rlast <= 0;
                    end 
                    
                end
                
                S_DONE: begin
                    s_rvalid <= 0;
                    s_rlast <= 0;
                    s_arready <= 1;
                    state <= S_IDLE;
                end 
                
            endcase
            
        end
    end
    
    // FSM for "writes"
    // Writes are technically not allowed for this implementation
    // Not like there's anything useful to do in writing data here
    // But I still would like to capture these writes and do some dummy responses so that the cores would not deadlock
    // in case of a misroute
    reg [2:0] w_state;
    localparam W_IDLE = 3'd0;
    localparam W_REQ = 3'd1;
    localparam W_RESP = 3'd2;
    localparam W_DONE = 3'd3;
    
    
    always @ (posedge clk) begin
        if (!nrst) begin
            w_state <= W_IDLE;
            s_awready <= 0;
            s_wready <= 0;
            s_bresp <= 0;
            s_bvalid <= 0;
            
        end
        else begin
            case (w_state)
                W_IDLE: begin
                    s_wready <= 1;
                    if (s_awvalid && s_awready) begin
                        s_awready <= 0;
                        w_state <= W_REQ;
                    end else begin
                        s_awready <= 1;
                    end
                end
                
                W_REQ: begin
                    // I'm just going to assert wready 
                    // But not do anything lols
                    s_wready <= 1;
                    if (s_wready && s_wvalid && s_wlast) begin
                        s_wready <= 0;
                        w_state <= W_RESP;
                    end
                end
                
                W_RESP: begin
                    s_bresp <= 2'b00;
                    s_bvalid <= 1;
                    if (s_bvalid && s_bready) begin
                        s_bvalid <= 0;
                        w_state <= W_DONE;
                    end
                end
                
                W_DONE: begin
                    s_bvalid <= 0;
                    s_wready <= 1;
                    s_awready <= 1; 
                    w_state <= W_IDLE;
                end
                
            endcase
        end
    end
endmodule
