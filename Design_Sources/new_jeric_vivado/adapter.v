`timescale 1ns / 1ps

/* May 12, 2026

This adapter receives AXI write bursts from SmartConnect and converts
each accepted 32-bit WDATA beat into one SPAD write:

Assumptions:
   - AXI data width = 32 bits
   - SPAD_N = 4 byte lanes
   - SPAD write address is word-indexed
   
If software programs DMA DST = adapter_base + local_byte_offset,
then this adapter converts local byte address to SPAD word address
by using address bits [ADDR_LSB +: TOP_ADDR_WIDTH].

*/

module axi_spad_write_adapter #(
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,

    parameter TOP_ADDR_WIDTH  = 16,
    parameter SPAD_DATA_WIDTH = 32,
    parameter SPAD_N          = 4,

    // 32-bit word = 4 bytes, so byte-address to word-address shift is 2
    parameter ADDR_LSB        = 2
)(
    input  wire                         aclk,
    input  wire                         aresetn,
    // Write channels
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [7:0]                   s_axi_awlen,
    input  wire [2:0]                   s_axi_awsize,
    input  wire [1:0]                   s_axi_awburst,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                         s_axi_wlast,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    output wire [1:0]                   s_axi_bresp,
    output reg                          s_axi_bvalid,
    input  wire                         s_axi_bready,

    // Reads are safely ignored/returns zero
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [7:0]                   s_axi_arlen,
    input  wire [2:0]                   s_axi_arsize,
    input  wire [1:0]                   s_axi_arburst,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                   s_axi_rresp,
    output reg                          s_axi_rlast,
    output reg                          s_axi_rvalid,
    input  wire                         s_axi_rready,

    /*
     DMA SPAD select
       000 = weights
       001 = ifmaps / inputs
       010 = bias
       011 = scale
       100 = shift
    */
    input  wire [2:0]                   i_spad_sel,


    output reg  [SPAD_DATA_WIDTH-1:0]    o_data_in,
    output reg  [TOP_ADDR_WIDTH-1:0]     o_write_addr,
    output reg  [SPAD_N-1:0]             o_write_mask,
    output reg  [2:0]                   o_spad_select,
    output reg                          o_write_en
);



    // ------------------------------------------------------
    // Write FSM
    // ------------------------------------------------------
    localparam WR_IDLE = 2'd0;
    localparam WR_DATA = 2'd1;
    localparam WR_RESP = 2'd2;

    reg [1:0] wr_state;

    reg [TOP_ADDR_WIDTH-1:0] wr_base_word_addr;
    reg [TOP_ADDR_WIDTH-1:0] wr_beat_count;
    reg [7:0]                wr_awlen_latched;
    reg [2:0]                wr_spad_sel_latched;

    // Convert AXI byte address into local SPAD word address.
    //
    // Because the adapter address region should be aligned, using these lower
    // address bits gives the offset inside the adapter region.
    // See solution scratch
    function [TOP_ADDR_WIDTH-1:0] axi_addr_to_spad_word_addr;
        input [AXI_ADDR_WIDTH-1:0] axi_addr;
        begin
            axi_addr_to_spad_word_addr =
                axi_addr[ADDR_LSB + TOP_ADDR_WIDTH - 1 : ADDR_LSB];
        end
    endfunction

    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_DATA);

    assign s_axi_bresp = 2'b00;

   // Counts the beat
    wire wr_last_by_count;
    assign wr_last_by_count =
        (wr_beat_count == {{(TOP_ADDR_WIDTH-8){1'b0}}, wr_awlen_latched});

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state            <= WR_IDLE;
            wr_base_word_addr   <= {TOP_ADDR_WIDTH{1'b0}};
            wr_beat_count       <= {TOP_ADDR_WIDTH{1'b0}};
            wr_awlen_latched    <= 8'd0;
            wr_spad_sel_latched <= 3'd0;

            s_axi_bvalid        <= 1'b0;

            o_data_in           <= {SPAD_DATA_WIDTH{1'b0}};
            o_write_addr        <= {TOP_ADDR_WIDTH{1'b0}};
            o_write_mask        <= {SPAD_N{1'b0}};
            o_spad_select       <= 3'd0;
            o_write_en          <= 1'b0;
        end else begin
            // Default: one-cycle pulse only when accepting WDATA.
            o_write_en <= 1'b0;

            case (wr_state)
                // Wait and latch address
                WR_IDLE: begin
                    s_axi_bvalid <= 1'b0;

                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_base_word_addr   <= axi_addr_to_spad_word_addr(s_axi_awaddr); // call the function to convert address
                        wr_beat_count       <= {TOP_ADDR_WIDTH{1'b0}}; // to be incremented
                        wr_awlen_latched    <= s_axi_awlen;
                        wr_spad_sel_latched <= i_spad_sel;
                        wr_state            <= WR_DATA;
                    end
                end

                // Write to SPAD
                WR_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        // One 32-bit DMA beat becomes one 32-bit SPAD word write
                        o_data_in     <= s_axi_wdata[SPAD_DATA_WIDTH-1:0]; // Like Marie's proposed idea
                        o_write_addr  <= wr_base_word_addr + wr_beat_count;
                        o_write_mask  <= s_axi_wstrb[SPAD_N-1:0];
                        o_spad_select <= wr_spad_sel_latched;
                        o_write_en    <= 1'b1;

                        wr_beat_count <= wr_beat_count + {{(TOP_ADDR_WIDTH-1){1'b0}}, 1'b1}; // increment beat count

                        // AXI burst complete when WLAST arrives
                        if (s_axi_wlast || wr_last_by_count) begin
                            s_axi_bvalid <= 1'b1;
                            wr_state     <= WR_RESP;
                        end
                    end
                end
                // Response after writing, set back to IDLE
                WR_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: begin
                    wr_state     <= WR_IDLE;
                    s_axi_bvalid <= 1'b0;
                end

            endcase
        end
    end

/////////////////////////////////////////////////////////////
    // Read channel that ignores/returns zero
    localparam RD_IDLE = 1'b0;
    localparam RD_DATA = 1'b1;

    reg       rd_state;
    reg [7:0] rd_len_latched;
    reg [7:0] rd_beat_count;

    assign s_axi_arready = (rd_state == RD_IDLE);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state       <= RD_IDLE;
            rd_len_latched <= 8'd0;
            rd_beat_count  <= 8'd0;

            s_axi_rdata    <= {AXI_DATA_WIDTH{1'b0}};
            s_axi_rresp    <= 2'b00;
            s_axi_rlast    <= 1'b0;
            s_axi_rvalid   <= 1'b0;
        end else begin
            case (rd_state)

                RD_IDLE: begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rlast  <= 1'b0;

                    if (s_axi_arvalid && s_axi_arready) begin
                        rd_len_latched <= s_axi_arlen;
                        rd_beat_count  <= 8'd0;

                        s_axi_rdata  <= {AXI_DATA_WIDTH{1'b0}};
                        s_axi_rresp  <= 2'b00;
                        s_axi_rlast  <= (s_axi_arlen == 8'd0);
                        s_axi_rvalid <= 1'b1;
                        rd_state     <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (rd_beat_count == rd_len_latched) begin
                            s_axi_rvalid <= 1'b0;
                            s_axi_rlast  <= 1'b0;
                            rd_state     <= RD_IDLE;
                        end else begin
                            rd_beat_count <= rd_beat_count + 8'd1;
                            s_axi_rdata   <= {AXI_DATA_WIDTH{1'b0}};
                            s_axi_rresp   <= 2'b00;
                            s_axi_rlast   <= ((rd_beat_count + 8'd1) == rd_len_latched);
                            s_axi_rvalid  <= 1'b1;
                        end
                    end
                end

                default: begin
                    rd_state     <= RD_IDLE;
                    s_axi_rvalid <= 1'b0;
                    s_axi_rlast  <= 1'b0;
                end

            endcase
        end
    end



    wire unused_read_inputs;
    assign unused_read_inputs =
        (^s_axi_araddr) |
        (^s_axi_arsize) |
        (^s_axi_arburst);

    wire unused_write_inputs;
    assign unused_write_inputs =
        (^s_axi_awsize) |
        (^s_axi_awburst);

endmodule