`timescale 1ns / 1ps

module qspi_inst_bootloader
#(
    parameter integer WORDS_TO_COPY       = 65536,

    // QSPI AXI-Lite register base address
    parameter [31:0] QSPI_BASE_ADDRESS    = 32'h44A0_0000,

    // Flash address where instmem.bin is stored in the MCS
    //   0x0010_0000 = ddr.bin
    //   0x0020_0000 = instmem.bin
    parameter [31:0] QSPI_FLASH_BASE      = 32'h0020_0000,
    parameter integer QSPI_BYTE_IN_MSB    = 0,

    parameter integer TIMEOUT_MAX         = 32'd1000000
)
(
    input  wire        clk,
    input  wire        nrst,

    output reg         done,
    output reg         bootload_done,

    // Output refill interface to instmem_xpm
    output reg         valid,
    output reg [31:0]  inst_refill,

    // AXI write address channel
    output reg  [31:0] m_awaddr,
    output reg  [7:0]  m_awlen,
    output reg  [2:0]  m_awsize,
    output reg  [1:0]  m_awburst,
    output reg         m_awvalid,
    input  wire        m_awready,

    // AXI write data channel
    output wire [31:0] m_wdata,
    output reg  [3:0]  m_wstrb,
    output reg         m_wlast,
    output reg         m_wvalid,
    input  wire        m_wready,

    // AXI write response channel
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output reg         m_bready,

    // AXI read address channel
    output reg  [31:0] m_araddr,
    output reg  [7:0]  m_arlen,
    output reg  [2:0]  m_arsize,
    output reg  [1:0]  m_arburst,
    output reg         m_arvalid,
    input  wire        m_arready,

    // AXI read data channel
    input  wire [31:0] m_rdata,
    input  wire [1:0]  m_rresp,
    input  wire        m_rlast,
    input  wire        m_rvalid,
    output reg         m_rready
);

    // -------------------------------------------------------------------------
    // AXI Quad SPI register offsets
    // -------------------------------------------------------------------------
    localparam [31:0] REG_SRR    = 32'h40;
    localparam [31:0] REG_SPICR  = 32'h60;
    localparam [31:0] REG_SPISR  = 32'h64;
    localparam [31:0] REG_DTR    = 32'h68;
    localparam [31:0] REG_DRR    = 32'h6C;
    localparam [31:0] REG_SSR    = 32'h70;

    localparam [31:0] CR_SPE     = 32'h0000_0002;
    localparam [31:0] CR_MASTER  = 32'h0000_0004;
    localparam [31:0] CR_TXRST   = 32'h0000_0020;
    localparam [31:0] CR_RXRST   = 32'h0000_0040;
    localparam [31:0] CR_MT_INH  = 32'h0000_0100;

    localparam [31:0] SR_RX_EMPTY = 32'h0000_0001;
    localparam [31:0] SR_TX_EMPTY = 32'h0000_0004;

    localparam [31:0] SSR_ASSERT_SLAVE0 = 32'h0000_0000;
    localparam [31:0] SSR_DEASSERT_ALL  = 32'h0000_0001;

    localparam [31:0] SPICR_IDLE = CR_SPE | CR_MASTER | CR_MT_INH;
    localparam [31:0] SPICR_GO   = CR_SPE | CR_MASTER;

    localparam [7:0] CMD_READ = 8'h03;

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    localparam [7:0]
        S_RESET             = 8'd0,

        // Generic AXI helpers
        S_AXI_WR_AW         = 8'd1,
        S_AXI_WR_W          = 8'd2,
        S_AXI_WR_B          = 8'd3,
        S_AXI_RD_AR         = 8'd4,
        S_AXI_RD_R          = 8'd5,

        // QSPI init
        S_INIT_SRR          = 8'd10,
        S_INIT_SSR          = 8'd11,
        S_INIT_FIFO_RST     = 8'd12,
        S_INIT_IDLE         = 8'd13,
        S_INIT_WAIT         = 8'd14,

        // Per-word QSPI transaction
        S_CHECK_DONE        = 8'd20,
        S_WORD_START        = 8'd21,
        S_QSPI_DEASSERT     = 8'd22,
        S_QSPI_FIFO_RST     = 8'd23,
        S_QSPI_IDLE         = 8'd24,
        S_QSPI_ASSERT       = 8'd25,
        S_QSPI_TX_START     = 8'd26,
        S_QSPI_TX_AFTER     = 8'd27,
        S_QSPI_GO           = 8'd28,
        S_POLL_TX_START     = 8'd29,
        S_POLL_TX_AFTER     = 8'd30,
        S_QSPI_STOP         = 8'd31,
        S_QSPI_DEASSERT2    = 8'd32,
        S_RX_POLL_START     = 8'd33,
        S_RX_POLL_AFTER     = 8'd34,
        S_RX_READ_START     = 8'd35,
        S_RX_READ_AFTER     = 8'd36,
        S_WAIT_AFTER_TX     = 8'd37,

        // instmem_xpm write pulse
        S_INST_WRITE        = 8'd40,
        S_INST_WRITE_DONE   = 8'd41,

        S_DONE              = 8'd50,
        S_ERROR             = 8'd51;

    reg [7:0] state;
    reg [7:0] return_state;

    reg warmup_done;

    reg [31:0] pending_addr;
    reg [31:0] pending_wdata;
    reg [3:0]  pending_wstrb;
    reg [31:0] read_data;

    assign m_wdata = pending_wdata;

    // Copy state
    reg [31:0] word_idx;
    reg [31:0] flash_addr;

    // SPI transfer state
    reg [3:0]  tx_idx;
    reg [3:0]  rx_idx;
    reg [7:0]  rx_b0;
    reg [7:0]  rx_b1;
    reg [7:0]  rx_b2;
    reg [7:0]  rx_b3;
    reg [31:0] assembled_word;
    reg [31:0] timeout_count;
    reg        error_flag;

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------
    function [31:0] qspi_byte_to_wdata;
        input [7:0] b;
        begin
            if (QSPI_BYTE_IN_MSB != 0)
                qspi_byte_to_wdata = {b, 24'h000000};
            else
                qspi_byte_to_wdata = {24'h000000, b};
        end
    endfunction

    function [7:0] qspi_rdata_to_byte;
        input [31:0] x;
        begin
            if (QSPI_BYTE_IN_MSB != 0)
                qspi_rdata_to_byte = x[31:24];
            else
                qspi_rdata_to_byte = x[7:0];
        end
    endfunction

    function [7:0] tx_byte_for_index;
        input [3:0] index;
        input [31:0] addr;
        begin
            case (index)
                4'd0: tx_byte_for_index = CMD_READ;
                4'd1: tx_byte_for_index = addr[23:16];
                4'd2: tx_byte_for_index = addr[15:8];
                4'd3: tx_byte_for_index = addr[7:0];
                default: tx_byte_for_index = 8'h00;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!nrst) begin
            state          <= S_RESET;
            return_state   <= S_RESET;

            done           <= 1'b0;
            bootload_done  <= 1'b0;
            error_flag     <= 1'b0;

            valid          <= 1'b0;
            inst_refill    <= 32'd0;

            m_awaddr       <= 32'd0;
            m_awlen        <= 8'd0;
            m_awsize       <= 3'b010;
            m_awburst      <= 2'b01;
            m_awvalid      <= 1'b0;

            pending_wdata  <= 32'd0;
            pending_wstrb  <= 4'b1111;
            m_wstrb        <= 4'b1111;
            m_wlast        <= 1'b0;
            m_wvalid       <= 1'b0;

            m_bready       <= 1'b0;

            m_araddr       <= 32'd0;
            m_arlen        <= 8'd0;
            m_arsize       <= 3'b010;
            m_arburst      <= 2'b01;
            m_arvalid      <= 1'b0;
            m_rready       <= 1'b0;

            pending_addr   <= 32'd0;
            read_data      <= 32'd0;

            word_idx       <= 32'd0;
            flash_addr     <= 32'd0;

            tx_idx         <= 4'd0;
            rx_idx         <= 4'd0;
            rx_b0          <= 8'd0;
            rx_b1          <= 8'd0;
            rx_b2          <= 8'd0;
            rx_b3          <= 8'd0;
            assembled_word <= 32'd0;
            timeout_count  <= 32'd0;
            warmup_done    <= 1'b0;

        end else begin
            case (state)


                S_RESET: begin
                    done          <= 1'b0;
                    bootload_done <= 1'b0;
                    error_flag    <= 1'b0;

                    valid         <= 1'b0;
                    inst_refill   <= 32'd0;

                    m_awvalid     <= 1'b0;
                    m_wvalid      <= 1'b0;
                    m_wlast       <= 1'b0;
                    m_bready      <= 1'b0;
                    m_arvalid     <= 1'b0;
                    m_rready      <= 1'b0;

                    word_idx      <= 32'd0;
                    timeout_count <= 32'd0;
                    warmup_done   <= 1'b0;

                    state <= S_INIT_SRR;
                end


                S_AXI_WR_AW: begin
                    m_awaddr  <= pending_addr;
                    m_awlen   <= 8'd0;
                    m_awsize  <= 3'b010;
                    m_awburst <= 2'b01;
                    m_awvalid <= 1'b1;

                    if (m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;

                        m_wstrb   <= pending_wstrb;
                        m_wlast   <= 1'b1;
                        m_wvalid  <= 1'b1;

                        state     <= S_AXI_WR_W;
                    end
                end

                S_AXI_WR_W: begin
                    if (m_wvalid && m_wready) begin
                        m_wvalid <= 1'b0;
                        m_wlast  <= 1'b0;
                        m_bready <= 1'b1;
                        state    <= S_AXI_WR_B;
                    end
                end

                S_AXI_WR_B: begin
                    if (m_bvalid && m_bready) begin
                        m_bready <= 1'b0;
                        state    <= return_state;
                    end
                end

                S_AXI_RD_AR: begin
                    m_araddr  <= pending_addr;
                    m_arlen   <= 8'd0;
                    m_arsize  <= 3'b010;
                    m_arburst <= 2'b01;
                    m_arvalid <= 1'b1;

                    if (m_arvalid && m_arready) begin
                        m_arvalid <= 1'b0;
                        m_rready  <= 1'b1;
                        state     <= S_AXI_RD_R;
                    end
                end

                S_AXI_RD_R: begin
                    if (m_rvalid && m_rready) begin
                        read_data <= m_rdata;
                        m_rready  <= 1'b0;
                        state     <= return_state;
                    end
                end

                // -------------------------------------------------------------
                // QSPI init sequence
                // -------------------------------------------------------------
                S_INIT_SRR: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SRR;
                    pending_wdata <= 32'h0000_000A;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_INIT_SSR;
                    state         <= S_AXI_WR_AW;
                end

                S_INIT_SSR: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SSR;
                    pending_wdata <= SSR_DEASSERT_ALL;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_INIT_FIFO_RST;
                    state         <= S_AXI_WR_AW;
                end

                S_INIT_FIFO_RST: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_IDLE | CR_TXRST | CR_RXRST;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_INIT_IDLE;
                    state         <= S_AXI_WR_AW;
                end

                S_INIT_IDLE: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_IDLE;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_INIT_WAIT;
                    state         <= S_AXI_WR_AW;
                end

                S_INIT_WAIT: begin
                    if (timeout_count >= 32'd4096) begin
                        timeout_count <= 32'd0;
                        state         <= S_CHECK_DONE;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                        state         <= S_INIT_WAIT;
                    end
                end

                // -------------------------------------------------------------
                // Main copy loop
                // -------------------------------------------------------------
                S_CHECK_DONE: begin
                    if (word_idx >= WORDS_TO_COPY) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_WORD_START;
                    end
                end

                S_WORD_START: begin
                    flash_addr    <= QSPI_FLASH_BASE + (word_idx << 2);
                    tx_idx        <= 4'd0;
                    rx_idx        <= 4'd0;
                    rx_b0         <= 8'd0;
                    rx_b1         <= 8'd0;
                    rx_b2         <= 8'd0;
                    rx_b3         <= 8'd0;
                    timeout_count <= 32'd0;
                    state         <= S_QSPI_DEASSERT;
                end

                S_QSPI_DEASSERT: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SSR;
                    pending_wdata <= SSR_DEASSERT_ALL;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_FIFO_RST;
                    state         <= S_AXI_WR_AW;
                end

                S_QSPI_FIFO_RST: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_IDLE | CR_TXRST | CR_RXRST;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_IDLE;
                    state         <= S_AXI_WR_AW;
                end

                S_QSPI_IDLE: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_IDLE;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_ASSERT;
                    state         <= S_AXI_WR_AW;
                end

                S_QSPI_ASSERT: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SSR;
                    pending_wdata <= SSR_ASSERT_SLAVE0;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_TX_START;
                    state         <= S_AXI_WR_AW;
                end

                // https://docs.amd.com/r/en-US/pg153-axi-quad-spi/Erase-Command-Sequence#:~:text=master%20inhibit%20bit.-,Read%20Data%20Command%20Sequence,commands%20vary%20with%20respect%20to%20the%20mode%20(Standard/Dual/Quad)%20used.,-Test%20Bench
                // 0: command 0x03
                // 1: addr[23:16]
                // 2: addr[15:8]
                // 3: addr[7:0]
                // 4..7: dummy clocks for 4 returned data bytes
                S_QSPI_TX_START: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_DTR;
                    pending_wdata <= qspi_byte_to_wdata(tx_byte_for_index(tx_idx, flash_addr));
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_TX_AFTER;
                    state         <= S_AXI_WR_AW;
                end

                S_QSPI_TX_AFTER: begin
                    if (tx_idx == 4'd7) begin
                        tx_idx <= 4'd0;
                        state  <= S_QSPI_GO;
                    end else begin
                        tx_idx <= tx_idx + 1'b1;
                        state  <= S_QSPI_TX_START;
                    end
                end

                S_QSPI_GO: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_GO;
                    pending_wstrb <= 4'b1111;
                    timeout_count <= 32'd0;
                    return_state  <= S_POLL_TX_START;
                    state         <= S_AXI_WR_AW;
                end

                S_POLL_TX_START: begin
                    pending_addr <= QSPI_BASE_ADDRESS + REG_SPISR;
                    return_state <= S_POLL_TX_AFTER;
                    state        <= S_AXI_RD_AR;
                end

                S_POLL_TX_AFTER: begin
                    if ((read_data & SR_TX_EMPTY) != 32'd0) begin
                        timeout_count <= 32'd0;
                        state         <= S_WAIT_AFTER_TX;
                    end else if (timeout_count >= TIMEOUT_MAX) begin
                        error_flag <= 1'b1;
                        state      <= S_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                        state         <= S_POLL_TX_START;
                    end
                end

                S_WAIT_AFTER_TX: begin
                    if (timeout_count >= 32'd256) begin
                        timeout_count <= 32'd0;
                        state         <= S_QSPI_STOP;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                        state         <= S_WAIT_AFTER_TX;
                    end
                end

                S_QSPI_STOP: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SPICR;
                    pending_wdata <= SPICR_IDLE;
                    pending_wstrb <= 4'b1111;
                    return_state  <= S_QSPI_DEASSERT2;
                    state         <= S_AXI_WR_AW;
                end

                S_QSPI_DEASSERT2: begin
                    pending_addr  <= QSPI_BASE_ADDRESS + REG_SSR;
                    pending_wdata <= SSR_DEASSERT_ALL;
                    pending_wstrb <= 4'b1111;
                    rx_idx        <= 4'd0;
                    timeout_count <= 32'd0;
                    return_state  <= S_RX_POLL_START;
                    state         <= S_AXI_WR_AW;
                end

                S_RX_POLL_START: begin
                    pending_addr <= QSPI_BASE_ADDRESS + REG_SPISR;
                    return_state <= S_RX_POLL_AFTER;
                    state        <= S_AXI_RD_AR;
                end

                S_RX_POLL_AFTER: begin
                    if ((read_data & SR_RX_EMPTY) == 32'd0) begin
                        state <= S_RX_READ_START;
                    end else if (timeout_count >= TIMEOUT_MAX) begin
                        error_flag <= 1'b1;
                        state      <= S_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                        state         <= S_RX_POLL_START;
                    end
                end

                S_RX_READ_START: begin
                    pending_addr <= QSPI_BASE_ADDRESS + REG_DRR;
                    return_state <= S_RX_READ_AFTER;
                    state        <= S_AXI_RD_AR;
                end

                S_RX_READ_AFTER: begin
                    case (rx_idx)
                        4'd4: rx_b0 <= qspi_rdata_to_byte(read_data);
                        4'd5: rx_b1 <= qspi_rdata_to_byte(read_data);
                        4'd6: rx_b2 <= qspi_rdata_to_byte(read_data);
                        4'd7: rx_b3 <= qspi_rdata_to_byte(read_data);
                        default: begin
                        end
                    endcase

                    if (rx_idx == 4'd7) begin
                        assembled_word <= {
                            rx_b0,
                            rx_b1,
                            rx_b2,
                            qspi_rdata_to_byte(read_data)
                        };
                        state <= S_INST_WRITE;
                    end else begin
                        rx_idx        <= rx_idx + 1'b1;
                        timeout_count <= 32'd0;
                        state         <= S_RX_POLL_START;
                    end
                end

                // -------------------------------------------------------------
                // instmem_xpm refill write
                // -------------------------------------------------------------
                S_INST_WRITE: begin
                    // First QSPI transaction after init can return old FF.
                    // Discard it once, then retry word_idx = 0.
                    if (!warmup_done) begin
                        warmup_done <= 1'b1;

                        // Do not write into instmem.
                        // Do not increment word_idx.
                        valid <= 1'b0;
                        state <= S_WORD_START;
                    end else begin
                        inst_refill <= assembled_word;
                        valid       <= 1'b1;
                        state       <= S_INST_WRITE_DONE;
                    end
                end

                S_INST_WRITE_DONE: begin
                    valid    <= 1'b0;
                    word_idx <= word_idx + 1'b1;
                    state    <= S_CHECK_DONE;
                end

                S_DONE: begin
                    done          <= 1'b1;
                    bootload_done <= 1'b1;
                    valid         <= 1'b0;

                    m_awvalid <= 1'b0;
                    m_wvalid  <= 1'b0;
                    m_wlast   <= 1'b0;
                    m_bready  <= 1'b0;
                    m_arvalid <= 1'b0;
                    m_rready  <= 1'b0;

                    state <= S_DONE;
                end

                S_ERROR: begin
                    // Do NOT release the core if instruction bootloading failed
                    done          <= 1'b0;
                    bootload_done <= 1'b0;
                    error_flag    <= 1'b1;
                    valid         <= 1'b0;

                    m_awvalid <= 1'b0;
                    m_wvalid  <= 1'b0;
                    m_wlast   <= 1'b0;
                    m_bready  <= 1'b0;
                    m_arvalid <= 1'b0;
                    m_rready  <= 1'b0;

                    state <= S_ERROR;
                end

                default: begin
                    state <= S_ERROR;
                end

            endcase
        end
    end
endmodule