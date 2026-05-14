`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2025 06:19:45 PM
// Design Name: 
// Module Name: simple_axi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:     A simple RTL model to test the waters and my knowledge of the AXI4 protocol
//                  Hopefully this simple AXI master will do a single read and single write transaction 
//                  and connect this to an AXI compliant IP
//                  Address bits = 12
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module l2_axi_interface_new(
    // L2 Ports
    input clk,
    input nrst,
    input rd,
    input wr,
    input [31:0] rd_addr,
    input [31:0] wr_addr,
    input L2_done,
    output [127:0] data_o, // output block
    input [127:0] data_i, // Input block
    
    // done signals for the cache
    output  rd_done,
    output  wr_done,
    
    
    // AXI4 Channels
    // WRITE ADDRESS AW CHANNEL

    output reg      M_AXI_AWVALID,
    input           M_AXI_AWREADY,
    output reg [31:0]   M_AXI_AWADDR,
    output reg [7:0] M_AXI_AWLEN,      // for burst
    output reg [2:0] M_AXI_AWSIZE,     // 32 bits is 4 bytes
    output reg [1:0]    M_AXI_AWBURST,    // INCR (incremental burst) is 0x01
    
    // WRITE DATA CHANNEL
    output reg      M_AXI_WVALID,
    input           M_AXI_WREADY,
    output reg      M_AXI_WLAST,
    output [31:0]   M_AXI_WDATA,
    output reg [3:0]M_AXI_WSTRB,
    
    
    // WRITE RESPONSE CHANNEL
    output reg      M_AXI_BREADY,
    input           M_AXI_BVALID,
    input [1:0]     M_AXI_BRESP,
    
    // READ ADDRESS CHANNEL
    output reg      M_AXI_ARVALID,
    input           M_AXI_ARREADY,
    output reg [1:0] M_AXI_ARBURST,
    output reg [2:0] M_AXI_ARSIZE,
    output reg [31:0]   M_AXI_ARADDR,
    output reg [7:0] M_AXI_ARLEN,
    
    // READ DATA CHANNEL
    input           M_AXI_RVALID,
    output reg      M_AXI_RREADY,
    input [31:0]    M_AXI_RDATA,
    input [1:0]     M_AXI_RRESP,
    input           M_AXI_RLAST
    
    
    );
    
    
    
    // The FSM
    // New idea: Separate the READ and WRITE FSMs
    // READS FSM
    // S_READ_IDLE -> when no read transactions; Deassert all valid signals;
    // S_READ_PREP -> RD signal is asserted. Prepare the address, data and other information on some buffer. Assume bursts, so prepm_axi_are the data
    // S_READ_WAIT_FOR_VALID -> RD transaction; set araddr with the valid signals and other information signals; wait for handshake
    // S_IDLE_WRITE - > when no write transactions;
    // S_READ_GRANT -> Assert the RREADY signal;  wait for RVALID; Each beat store data in a buffer; wait for RLAST to get out of this state
    // S_READ_DONE -> RLAST signal received; handshaked receieved; Clean up state, remove ready signals
    // S_READ_ERROR -> Something went wrong; do not go to idle state; Go back to PREP stage
    
    
    // WRITES FSM
    // S_IDLE_WRITE -> when no write transactions;
    // S_WRITE_PREP -> WR signal is asserted. Same with READ_PREP
    // S_WRITE_WAIT_FOR_VALID -> WR transaction; set m_axi_awaddr with the valid signals and other information signals
    // S_WRITE_GRANT -> Assert the valid signals per data; use a counter?
    // S_WRITE_BRESP -> WLAST signal sent; ready handshake receieved; Assert M_AXI_BREADY to receieve the M_AXI_BRESP
    // S_WRITE_DONE -> M_AXI_BRESP received; 
    // S_WRITE_ERROR -> something went wrong; Do NOT go to S_DONE; repeat the transaction (i.e. go back to PREP stage)

    
    // Now, HOW SHOULD WE HANDLE FAILS?
    // PLAN A: repeat the transaction if SLVERR. -> Entire transaction? Not just the error?
    // At least in writes, since we can't know the status of individual beats
    // At reads, we can know, but then we can't repeat it alone, so we really need to repeat the entire transaction
    // If we instead received DECERR, we're screwed
    
    
    reg [3:0] r_state;
    reg [3:0] w_state; 
    
    localparam S_READ_IDLE = 4'd0;
    localparam S_READ_PREP = 4'd1;
    localparam S_READ_WAIT_FOR_VALID = 4'd2;
    localparam S_READ_GRANT = 4'd3;
    localparam S_READ_DONE = 4'd4; 
    localparam S_READ_ERROR = 4'd5;
    
    
    localparam S_WRITE_IDLE = 4'd0;
    localparam S_WRITE_PREP = 4'd1; 
    localparam S_WRITE_WAIT_FOR_READY = 4'd2; 
    localparam S_WRITE_GRANT = 4'd3; 
    localparam S_WRITE_BRESP = 4'd4; 
    localparam S_WRITE_DONE = 4'd5; 
    localparam S_WRITE_ERROR = 4'd6; 

    
    reg [31:0] read_address_buffer;
    reg [31:0] write_address_buffer;  
    reg [1:0] write_data_resp;
    
    // Parse the input block
    reg [31:0] write_data [4:0];
    
    // The read FIFO 
    reg [31:0] read_buffer[3:0];
    
    // READ FSM
    reg [1:0] r_burst_counter;
    reg [3:0] delay_rready;
    always @ (posedge clk) begin
        if (!nrst) begin
            r_state <= 0;
            read_address_buffer <= 0;
            M_AXI_ARVALID <= 0;
            M_AXI_ARSIZE <= 0;
            M_AXI_ARLEN <= 0;
            M_AXI_RREADY <= 0;
            M_AXI_ARBURST <= 0;
            M_AXI_ARADDR <= 0;
            r_burst_counter <= 0;
            delay_rready <= 0;
            
            read_buffer[0] <= 0;
            read_buffer[1] <= 0;
            read_buffer[2] <= 0;
            read_buffer[3] <= 0;
        end
        else begin
            case (r_state)
            
                S_READ_IDLE: begin
                    if (rd) begin
                        M_AXI_ARADDR <= rd_addr;
                        M_AXI_ARBURST <= 2'b01;
                        M_AXI_ARLEN <= 3;
                        M_AXI_ARSIZE <= 3'b010;
                        M_AXI_ARVALID <= 1;
                        r_state <= S_READ_WAIT_FOR_VALID; 
                    end
                 
                end
                
                S_READ_WAIT_FOR_VALID: begin
                        if (M_AXI_ARREADY && M_AXI_ARVALID) begin
                            r_state <= S_READ_GRANT;
                            M_AXI_ARVALID <= 0;
                        end 
                end
            
                S_READ_GRANT: begin
                    M_AXI_RREADY <= 1;
                    if (M_AXI_RREADY && M_AXI_RVALID) begin
                        read_buffer[r_burst_counter] <= M_AXI_RDATA;
                        r_burst_counter <= r_burst_counter + 1;
                        if (M_AXI_RLAST && (M_AXI_RRESP == 2'b00)) begin
                            //read_data_buffer <= M_AXI_RDATA;
                            r_state <= S_READ_DONE; // Let's not put error handling first
                            M_AXI_RREADY <= 0;
                        end
                    end 
                end
                
                 S_READ_DONE: begin
                    // cleanup; making sure that all ready and valid signals are gone
                    M_AXI_RREADY <= 0;
                    M_AXI_ARVALID <= 0;
                    r_state <= S_READ_IDLE;
                    r_burst_counter <= 0;
                    delay_rready <= 0;
                 end
            endcase
        end
    end
    assign data_o = {read_buffer[3],read_buffer[2],read_buffer[1],read_buffer[0]};
    assign rd_done = (r_state == S_READ_DONE);
    // WRITES FSM
    reg [2:0] w_burst_counter;
    always @ (posedge clk) begin
        if (!nrst) begin
            write_address_buffer <= 0;
            M_AXI_AWADDR <= 0;
            M_AXI_AWVALID <= 0;
            M_AXI_AWLEN <= 0;
            M_AXI_AWSIZE <= 0;
            M_AXI_WVALID <= 0;
            M_AXI_WLAST <= 0;
            M_AXI_BREADY <= 0;
            write_data_resp <= 0;
            w_state <= 0;
            M_AXI_AWBURST <= 0;
            w_burst_counter <= 0;
            
            write_data[0] <= 0;
            write_data[1] <= 0;
            write_data[2] <= 0;
            write_data[3] <= 0;
            write_data[4] <= 0; 
            write_data[5] <= 0;
        end
        else begin
            case (w_state) 
                S_WRITE_IDLE: begin
                    if (wr) begin
                        M_AXI_AWADDR <= wr_addr;
                        write_data[0] <= data_i[31:0];
                        write_data[1] <= data_i[63:32];
                        write_data[2] <= data_i[95:64];
                        write_data[3] <= data_i[127:96];
                        write_data[4] <= 32'h0;
                        write_data[5] <= 32'h0;
                        
                        M_AXI_AWLEN <= 3; // 3 + 1 = 4 words
                        M_AXI_AWSIZE <= 3'b010;
                        M_AXI_AWBURST <= 2'b01;
                        M_AXI_AWVALID  <= 1;
                        
                        // NEW
                        // You can also put the data in the write channel already!
                        M_AXI_WSTRB <= 4'b1111;
                        M_AXI_WVALID <= 1;
                        w_state <= S_WRITE_WAIT_FOR_READY;
                    end
                end
                
                S_WRITE_WAIT_FOR_READY: begin
                    if (M_AXI_AWVALID && M_AXI_AWREADY) begin
                        M_AXI_AWVALID <= 0;
                        //w_state <= S_WRITE_GRANT;
                    end
                    
                    // initial ready simulatenoues to the addresse
                    if (M_AXI_WVALID && M_AXI_WREADY) begin
                        w_burst_counter <= w_burst_counter + 1;
                         if (w_burst_counter == 2) begin
                            M_AXI_WLAST <= 1;
                        end 
                        else if (w_burst_counter == 3) begin
                            w_state <= S_WRITE_BRESP;
                            M_AXI_WSTRB <= 0;
                            M_AXI_WVALID <= 0;
                            M_AXI_WLAST <= 0;
                        end
                    end                   
                end
                
                S_WRITE_BRESP: begin
                  M_AXI_BREADY <= 1;
                    if (M_AXI_BREADY && M_AXI_BVALID) begin
                        write_data_resp <= M_AXI_BRESP;
                        w_state <= S_WRITE_DONE;
                        M_AXI_BREADY <= 0;
                    end
                end
                
                S_WRITE_DONE: begin
                    M_AXI_WVALID <= 0;
                    M_AXI_AWVALID <= 0;
                    M_AXI_BREADY <= 0;
                    M_AXI_WSTRB <= 0;
                    w_burst_counter <= 0;
                    if (L2_done)
                        w_state <= S_WRITE_IDLE;
                 end
            endcase
        end
    end
    assign M_AXI_WDATA = write_data[w_burst_counter];
    assign wr_done = (w_state == S_WRITE_DONE);
endmodule
