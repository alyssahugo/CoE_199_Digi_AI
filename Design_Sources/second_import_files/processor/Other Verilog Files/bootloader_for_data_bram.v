`timescale 1ns / 1ps

module bootloader_for_data_bram #
(
    parameter integer WORD_COUNT       = 8192,
    parameter [31:0]  AXI_BASE_ADDRESS = 32'h0000_0000
)
(
    input  wire        clk,
    input  wire        nrst,
    output reg         done,

    // ROM source
    output reg [12:0]  bram_addr,
    input  wire [31:0] bram_data,
    output reg         bram_en,

    // AXI write address channel
    output reg [31:0]  m_awaddr,
    output reg [7:0]   m_awlen,
    output reg [2:0]   m_awsize,
    output reg [1:0]   m_awburst,
    output reg         m_awvalid,
    input  wire        m_awready,

    // AXI write data channel
    output reg [31:0]  m_wdata,
    output reg [3:0]   m_wstrb,
    output reg         m_wlast,
    output reg         m_wvalid,
    input  wire        m_wready,

    // AXI write response channel
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output reg         m_bready
);

    reg [12:0] word_index;
    reg [2:0]  state;
    reg        aw_done;
    reg        w_done;

    localparam S_IDLE  = 3'd0;
    localparam S_ROM1  = 3'd1;  // ROM latency cycle 1
    localparam S_ROM2  = 3'd2;  // ROM latency cycle 2, data valid here
    localparam S_AW_W  = 3'd3;
    localparam S_BRESP = 3'd4;
    localparam S_DONE  = 3'd5;

    always @(posedge clk) begin
        if (!nrst) begin
            done      <= 1'b0;

            bram_addr <= 13'd0;
            bram_en   <= 1'b0;

            m_awaddr  <= 32'd0;
            m_awlen   <= 8'd0;      // single-beat write
            m_awsize  <= 3'b010;    // 4 bytes
            m_awburst <= 2'b01;     // INCR
            m_awvalid <= 1'b0;

            m_wdata   <= 32'd0;
            m_wstrb   <= 4'b1111;
            m_wlast   <= 1'b1;      // single-beat write
            m_wvalid  <= 1'b0;

            m_bready  <= 1'b0;

            word_index <= 13'd0;
            state      <= S_IDLE;
            aw_done    <= 1'b0;
            w_done     <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done      <= 1'b0;
                    bram_en   <= 1'b1;
                    bram_addr <= word_index;

                    aw_done   <= 1'b0;
                    w_done    <= 1'b0;

                    state <= S_ROM1;
                end

                S_ROM1: begin
                    // 1st ROM latency cycle
                    state <= S_ROM2;
                end

                S_ROM2: begin
                    // 2nd ROM latency cycle complete; bram_data is valid now
                    bram_en   <= 1'b0;

                    m_awaddr  <= AXI_BASE_ADDRESS + ({19'd0, word_index} << 2);
                    m_awlen   <= 8'd0;
                    m_awsize  <= 3'b010;
                    m_awburst <= 2'b01;
                    m_awvalid <= 1'b1;

                    m_wdata   <= bram_data;
                    m_wstrb   <= 4'b1111;
                    m_wlast   <= 1'b1;
                    m_wvalid  <= 1'b1;

                    aw_done   <= 1'b0;
                    w_done    <= 1'b0;

                    state <= S_AW_W;
                end

                S_AW_W: begin
                    if (!aw_done && m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;
                        aw_done   <= 1'b1;
                    end

                    if (!w_done && m_wvalid && m_wready) begin
                        m_wvalid <= 1'b0;
                        w_done   <= 1'b1;
                    end

                    if ((aw_done || (m_awvalid && m_awready)) &&
                        (w_done  || (m_wvalid  && m_wready))) begin
                        m_bready <= 1'b1;
                        state    <= S_BRESP;
                    end
                end

                S_BRESP: begin
                    if (m_bvalid && m_bready) begin
                        m_bready <= 1'b0;

                        // OKAY response = 2'b00
                        if (m_bresp != 2'b00) begin
                            done  <= 1'b1;
                            state <= S_DONE;
                        end else if (word_index == WORD_COUNT - 1) begin
                            done  <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            word_index <= word_index + 1'b1;
                            state      <= S_IDLE;
                        end
                    end
                end

                S_DONE: begin
                    done      <= 1'b1;
                    bram_en   <= 1'b0;
                    m_awvalid <= 1'b0;
                    m_wvalid  <= 1'b0;
                    m_bready  <= 1'b0;
                end

                default: begin
                    state <= S_DONE;
                end
            endcase
        end
    end

endmodule