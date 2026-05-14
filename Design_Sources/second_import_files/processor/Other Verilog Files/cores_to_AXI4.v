`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 08:32:10 AM
// Design Name: 
// Module Name: cores_to_AXI4
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:     Interface the cores to the AXI Interconnects and other AXI Slaves, such as the UART
//                  This also works for Atomic Memory Accesses as the NonCacheable path
//
// 
// Dependencies:    Assumes that the cores properly routes itself to enter the non cacheable path
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cores_to_AXI4
    (
    input clk,
    input nrst,
    
    // Core 1 signals and data
    input i_wr_1,
    input i_rd_1,
    input i_req_core_1,
    input i_done_core_1,
    output reg o_grant_core_1,
    input [31:0] i_data_core_1,
    input [3:0] i_dm_write_core_1,
    input [31:0] i_addr_1,

    
    // Core 2 signals and data
    input i_wr_2,
    input i_rd_2,
    input i_req_core_2,
    input i_done_core_2,
    output reg o_grant_core_2,
    input [31:0] i_data_core_2,
    input [3:0] i_dm_write_core_2,
    input [31:0] i_addr_2,
    
    // done signals of the AXI
    // output  rd_done,
    // output  wr_done,
    
    output [31:0] o_data,
    output reg valid_data,
    output reg valid_write_data,
    
    // AXI4 Channels
    // WRITE ADDRESS AW CHANNEL

    output reg      M_AXI_AWVALID,
    input           M_AXI_AWREADY,
    output [31:0]   M_AXI_AWADDR,
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
    output [31:0]   M_AXI_ARADDR,
    output reg [7:0] M_AXI_ARLEN,   // Fixed length of 0 + 1;
    
    // READ DATA CHANNEL
    input           M_AXI_RVALID,
    output reg      M_AXI_RREADY,
    input [31:0]    M_AXI_RDATA,
    input [1:0]     M_AXI_RRESP,
    input           M_AXI_RLAST,
    
    output [31:0] probe_m_axi_rdata,
    output        probe_m_axi_rvalid,
    output        probe_m_axi_arvalid,
    output        probe_m_axi_arready,
    output [31:0] probe_m_axi_araddr
    
    );
    
    // ARBITRATION UNIT ////////////////////////////////
    
    reg current_grant; // 0 - grant core 1;     1 - grant core 2
    reg [31:0] in_addr_bus;
    reg [31:0] in_data_bus;
    reg [3:0] in_dm_write_bus;
    reg [31:0] out_data_bus;
    reg rd;
    reg wr;
    initial begin
    
        current_grant <= 0;
    
    end
    
    always @ (posedge clk) begin
        if (!nrst) begin
            current_grant <= 0;
            o_grant_core_1 <= 0;
            o_grant_core_2 <= 0;
            
            in_addr_bus <= 0;
            in_data_bus <= 0;
            in_dm_write_bus <= 0;
            out_data_bus <= 0;
            rd <= 0;
            wr <= 0;
        end else begin
        
            case (current_grant) 
                0: begin 
                    // Core 1 has grant
                    if (i_req_core_1 && !i_done_core_1) begin // core 1 is requesting while core 1 is given grant
                        
                        o_grant_core_1 <= 1;
                        o_grant_core_2 <= 0;
                        in_addr_bus <= i_addr_1;
                        in_data_bus <= i_data_core_1;
                        in_dm_write_bus <= i_dm_write_core_1;
                        rd <= i_rd_1;
                        wr <= i_wr_1;
                        if (i_done_core_1) begin
                            current_grant <= 1;
                            o_grant_core_1 <= 0;
                            rd <= 0;
                            wr <= 0;
                        end
                    end else if (i_req_core_2 && !i_done_core_2) begin
                        // Core 2 requests instead,
                        o_grant_core_2 <= 1;
                        o_grant_core_1 <= 0;
                        in_addr_bus <= i_addr_2;
                        in_data_bus <= i_data_core_2;
                        in_dm_write_bus <= i_dm_write_core_2;
                        rd <= i_rd_2;
                        wr <= i_wr_2;
                        current_grant <= 1;
    
                    end else begin 
                        // No cores are requesting
                        current_grant <= current_grant;
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 0;
                        in_addr_bus <= in_addr_bus;
                        in_data_bus <= in_data_bus;
                        in_dm_write_bus <= 0;
                        rd <= 0;
                        wr <= 0;
                    end
                   
                end
                
                
                1: begin
                    // Core 2 has grant
                    if (i_req_core_2 && !i_done_core_2) begin

                        o_grant_core_2 <= 1;
                        o_grant_core_1 <= 0;
                        
                        in_addr_bus <= i_addr_2;
                        in_data_bus <= i_data_core_2;
                        in_dm_write_bus <= i_dm_write_core_2;
                        rd <= i_rd_2;
                        wr <= i_wr_2;
                        if (i_done_core_2) begin
                            current_grant <= 0;
                            o_grant_core_2 <= 0;
                            rd <= 0;
                            wr <= 0;
                        end
                    end else if (i_req_core_1 && !i_done_core_1) begin
                        in_addr_bus <= i_addr_1;
                        in_data_bus <= i_data_core_1;
                        in_dm_write_bus <= i_dm_write_core_1;
                        rd <= i_rd_1;
                        wr <= i_wr_1;
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 1;
                        current_grant <= 0;
                    end else begin
                        current_grant <= current_grant;
                        o_grant_core_2 <= 0;
                        o_grant_core_1 <= 0;
                        in_addr_bus <= in_addr_bus;
                        in_data_bus <= in_data_bus;
                        in_dm_write_bus <= 0;
                        rd <= 0;
                        wr <= 0;
                    end
                    

                end
            endcase
        end
    end
    
    // AXI Unit
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
    //reg [31:0] write_data [3:0];
    
    // The read FIFO 
    //reg [31:0] read_buffer[3:0];
    reg [31:0] rdata_buffer;
    
    // READ FSM
    reg [1:0] r_burst_counter;
    reg [3:0] delay_rready;
    always @ (posedge clk) begin
        if (!nrst) begin
            r_state <= 0;
            rdata_buffer <= 0;
            read_address_buffer <= 0;
            M_AXI_ARVALID <= 0;
            M_AXI_ARSIZE <= 0;
            M_AXI_ARLEN <= 0;
            M_AXI_RREADY <= 0;
            M_AXI_ARBURST <= 0;        
            delay_rready <= 0;
            valid_data <= 0;
        end
        else begin
            case (r_state)
                 S_READ_IDLE: begin
                    if ( rd ) begin
                        r_state <= S_READ_WAIT_FOR_VALID;
                        read_address_buffer <= in_addr_bus;
                        M_AXI_ARVALID <= 1;
                        M_AXI_ARBURST <= 2'b01;
                        // manually set the details:
                        M_AXI_ARLEN <= 0; // 0 + 1 = 4 words burst 
                        M_AXI_ARSIZE <= 3'b010; // 4 bytes
                    end
                    
                 end
                 
                 S_READ_PREP: begin
                    // Do something here wait
                 end
                 
                 S_READ_WAIT_FOR_VALID: begin
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                        r_state <= S_READ_GRANT;
                        M_AXI_ARVALID <= 0; // in the L2-AXI interface this deasserts after one cycle. here lets deassert immediately after handshake
                    end
                    
                 end
                 
                 S_READ_GRANT: begin 
                    M_AXI_RREADY <= 1;
                    
                    // wait for the valid signal
                    if (M_AXI_RREADY && M_AXI_RVALID) begin
                        // we can put a FIFO buffer here. 
                        rdata_buffer <= M_AXI_RDATA;
                        if (M_AXI_RLAST && (M_AXI_RRESP == 2'b00)) begin
                            rdata_buffer <= M_AXI_RDATA;
                            valid_data <= 1;
                            r_state <= S_READ_DONE; // Let's not put error handling first
                            M_AXI_RREADY <= 0;
                        end
                    end
                 end
                 
                 S_READ_DONE: begin
                    // cleanup; making sure that all ready and valid signals are gone
                    M_AXI_RREADY <= 0;
                    M_AXI_ARVALID <= 0;
                    //r_state <= S_READ_IDLE;
                    valid_data <= 0;
                    if (i_done_core_1 || i_done_core_2)
                        r_state <= S_READ_IDLE;

                 end
            endcase
        end
    end
    
    assign M_AXI_ARADDR = read_address_buffer;
    
    assign o_data = rdata_buffer;
    //assign rd_done = (r_state == S_READ_DONE);
    
    // WRITES FSM

    always @ (posedge clk) begin
        if (!nrst) begin
            write_address_buffer <= 0;
            M_AXI_AWVALID <= 0;
            M_AXI_AWLEN <= 0;
            M_AXI_AWSIZE <= 0;
            M_AXI_WVALID <= 0;
            M_AXI_WLAST <= 0;
            M_AXI_BREADY <= 0;
            write_data_resp <= 0;
            w_state <= 0;
            M_AXI_AWBURST <= 0;
            M_AXI_WSTRB <= 0;
            valid_write_data <= 0;

        end
        else begin
            case (w_state)
                S_WRITE_IDLE: begin
                    if (wr) begin
                        w_state <= S_WRITE_WAIT_FOR_READY;
                        write_address_buffer <= in_addr_bus;
                        
                        M_AXI_AWLEN <= 0; // 3 + 1 = 4 words
                        M_AXI_AWSIZE <= 3'b010;
                        M_AXI_AWBURST <= 2'b01;
                        M_AXI_AWVALID  <= 1;
                        valid_write_data <= 0;
                    end
                end
                
                S_WRITE_WAIT_FOR_READY: begin
                    if (M_AXI_AWVALID && M_AXI_AWREADY) begin
                        M_AXI_AWVALID <= 0; // Same here
                        w_state <= S_WRITE_GRANT;
                    end
                end
                
                S_WRITE_GRANT: begin
                    //write_data_buffer <= write_data[burst_counter];
                    
                    M_AXI_WSTRB <= in_dm_write_bus;
                    M_AXI_WVALID <= 1;
                    M_AXI_WLAST <= 1;
                    //wlast <= 1;
                    if (M_AXI_WVALID && M_AXI_WREADY) begin
                        w_state <= S_WRITE_BRESP;
                        M_AXI_WSTRB <= 4'b0;
                        M_AXI_WVALID <= 0; ////// 
                        M_AXI_WLAST <= 0;
                    end
                end
                
                S_WRITE_BRESP: begin
                   
                    M_AXI_BREADY <= 1;
                    if (M_AXI_BREADY && M_AXI_BVALID) begin
                        write_data_resp <= M_AXI_BRESP;
                        w_state <= S_WRITE_DONE;
                        M_AXI_BREADY <= 0;
                        valid_write_data <= 1;
                    end
                    

                end
                
                
                S_WRITE_DONE: begin
                    M_AXI_WVALID <= 0;
                    M_AXI_AWVALID <= 0;
                    M_AXI_BREADY <= 0;
                    //w_state <= S_WRITE_IDLE;
                    M_AXI_WSTRB <= 0;
                    valid_write_data <= 0;
                    if (i_done_core_1 || i_done_core_2)
                        w_state <= S_WRITE_IDLE;
                end
            endcase
        end
    end
    assign M_AXI_AWADDR = write_address_buffer;
    assign M_AXI_WDATA = in_data_bus;
    //assign wr_done = (w_state == S_WRITE_DONE);
    assign probe_m_axi_rdata   = M_AXI_RDATA;
    assign probe_m_axi_rvalid  = M_AXI_RVALID;
    assign probe_m_axi_arvalid = M_AXI_ARVALID;
    assign probe_m_axi_arready = M_AXI_ARREADY;
    assign probe_m_axi_araddr  = M_AXI_ARADDR;
    
    
endmodule
