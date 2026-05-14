//`timescale 1ns / 1ps

//module new_data_bootloader
//#(
//    parameter integer WORDS_TO_COPY   = 84744,
//    parameter [31:0] DDR_BASE_ADDRESS = 32'h8000_0000,
//    parameter integer BRAM_ADDR_WIDTH = 17
//)
//(
//    input  wire                        clk,
//    input  wire                        nrst,
//    output reg                         done,

//    // BRAM/ROM source
//    output reg  [BRAM_ADDR_WIDTH-1:0]  bram_addr,
//    input  wire [31:0]                 bram_data,
//    output reg                         bram_en,

//    // AXI write address channel
//    output reg  [31:0]                 m_awaddr,
//    output reg  [7:0]                  m_awlen,
//    output reg  [2:0]                  m_awsize,
//    output reg  [1:0]                  m_awburst,
//    output reg                         m_awvalid,
//    input  wire                        m_awready,

//    // AXI write data channel
//    output wire [31:0]                 m_wdata,
//    output reg  [3:0]                  m_wstrb,
//    output reg                         m_wlast,
//    output reg                         m_wvalid,
//    input  wire                        m_wready,

//    // AXI write response channel
//    input  wire [1:0]                  m_bresp,
//    input  wire                        m_bvalid,
//    output reg                         m_bready,

//    // AXI read channel (unused here)
//    output reg  [31:0]                 m_araddr,
//    output reg  [7:0]                  m_arlen,
//    output reg  [2:0]                  m_arsize,
//    output reg  [1:0]                  m_arburst,
//    output reg                         m_arvalid,
//    input  wire                        m_arready,

//    input  wire [31:0]                 m_rdata,
//    input  wire [1:0]                  m_rresp,
//    input  wire                        m_rlast,
//    input  wire                        m_rvalid,
//    output reg                         m_rready
//);

//    localparam [2:0]
//        S_IDLE       = 3'd0,
//        S_BRAM_REQ   = 3'd1,
//        S_BRAM_WAIT1 = 3'd2,
//        S_BRAM_WAIT2 = 3'd3,
//        S_AW         = 3'd4,
//        S_W          = 3'd5,
//        S_B          = 3'd6;

//    reg [2:0] state;

//    reg [31:0] buffer [0:WORDS_TO_COPY-1];
//    reg [15:0] load_count;
//    reg [15:0] send_count;

//    assign m_wdata = buffer[send_count];

//    integer k;
//    always @(posedge clk) begin
//        if (!nrst) begin
//            state      <= S_IDLE;
//            done       <= 1'b0;

//            bram_addr  <= {BRAM_ADDR_WIDTH{1'b0}};
//            bram_en    <= 1'b0;

//            m_awaddr   <= 32'd0;
//            m_awlen    <= 8'd0;
//            m_awsize   <= 3'b010;   // 4 bytes
//            m_awburst  <= 2'b01;    // INCR
//            m_awvalid  <= 1'b0;

//            m_wstrb    <= 4'b1111;
//            m_wlast    <= 1'b0;
//            m_wvalid   <= 1'b0;

//            m_bready   <= 1'b0;

//            m_araddr   <= 32'd0;
//            m_arlen    <= 8'd0;
//            m_arsize   <= 3'd0;
//            m_arburst  <= 2'd0;
//            m_arvalid  <= 1'b0;
//            m_rready   <= 1'b0;

//            load_count <= 16'd0;
//            send_count <= 16'd0;

//            for (k = 0; k < WORDS_TO_COPY; k = k + 1)
//                buffer[k] <= 32'd0;
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    done       <= 1'b0;
//                    bram_en    <= 1'b1;
//                    bram_addr  <= {BRAM_ADDR_WIDTH{1'b0}};
//                    load_count <= 16'd0;
//                    send_count <= 16'd0;
//                    state      <= S_BRAM_REQ;
//                end

//                // Present BRAM address
//                S_BRAM_REQ: begin
//                    bram_en <= 1'b1;
//                    state   <= S_BRAM_WAIT1;
//                end

//                // Wait 1st cycle of BRAM latency
//                S_BRAM_WAIT1: begin
//                    state <= S_BRAM_WAIT2;
//                end

//                // Wait 2nd cycle, then capture valid BRAM data
//                S_BRAM_WAIT2: begin
//                    buffer[load_count] <= bram_data;

//                    if (load_count == WORDS_TO_COPY - 1) begin
//                        bram_en   <= 1'b0;
//                        m_awaddr  <= DDR_BASE_ADDRESS;
//                        m_awlen   <= WORDS_TO_COPY - 1; // beats - 1
//                        m_awsize  <= 3'b010;            // 4 bytes/beat
//                        m_awburst <= 2'b01;             // INCR
//                        m_awvalid <= 1'b1;
//                        state     <= S_AW;
//                    end else begin
//                        load_count <= load_count + 1'b1;
//                        bram_addr  <= load_count + 1'b1;
//                        state      <= S_BRAM_REQ;
//                    end
//                end

//                S_AW: begin
//                    if (m_awvalid && m_awready) begin
//                        m_awvalid  <= 1'b0;
//                        m_wvalid   <= 1'b1;
//                        m_wstrb    <= 4'b1111;
//                        m_wlast    <= (WORDS_TO_COPY == 1);
//                        send_count <= 16'd0;
//                        state      <= S_W;
//                    end
//                end

//                S_W: begin
//                    if (m_wvalid && m_wready) begin
//                        if (send_count == WORDS_TO_COPY - 1) begin
//                            m_wvalid <= 1'b0;
//                            m_wlast  <= 1'b0;
//                            m_bready <= 1'b1;
//                            state    <= S_B;
//                        end else begin
//                            send_count <= send_count + 1'b1;
//                            m_wlast    <= (send_count == WORDS_TO_COPY - 2);
//                        end
//                    end
//                end

//                S_B: begin
//                    if (m_bvalid && m_bready) begin
//                        m_bready <= 1'b0;
//                        done     <= 1'b1;
//                        state    <= S_B;
//                    end
//                end

//                default: begin
//                    state <= S_IDLE;
//                end
//            endcase
//        end
//    end

//endmodule

`timescale 1ns / 1ps

module new_data_bootloader
#(
    parameter integer WORDS_TO_COPY   = 86176,
    parameter [31:0] DDR_BASE_ADDRESS = 32'h8000_0000,
    parameter integer BRAM_ADDR_WIDTH = 17,
    parameter integer BURST_WORDS     = 32
)
(
    input  wire                        clk,
    input  wire                        nrst,
    output reg                         done,

    // BRAM/ROM source
    output reg  [BRAM_ADDR_WIDTH-1:0]  bram_addr,
    input  wire [31:0]                 bram_data,
    output reg                         bram_en,

    // AXI write address channel
    output reg  [31:0]                 m_awaddr,
    output reg  [7:0]                  m_awlen,
    output reg  [2:0]                  m_awsize,
    output reg  [1:0]                  m_awburst,
    output reg                         m_awvalid,
    input  wire                        m_awready,

    // AXI write data channel
    output wire [31:0]                 m_wdata,
    output reg  [3:0]                  m_wstrb,
    output reg                         m_wlast,
    output reg                         m_wvalid,
    input  wire                        m_wready,

    // AXI write response channel
    input  wire [1:0]                  m_bresp,
    input  wire                        m_bvalid,
    output reg                         m_bready,

    // AXI read channel (unused here)
    output reg  [31:0]                 m_araddr,
    output reg  [7:0]                  m_arlen,
    output reg  [2:0]                  m_arsize,
    output reg  [1:0]                  m_arburst,
    output reg                         m_arvalid,
    input  wire                        m_arready,

    input  wire [31:0]                 m_rdata,
    input  wire [1:0]                  m_rresp,
    input  wire                        m_rlast,
    input  wire                        m_rvalid,
    output reg                         m_rready
);

    localparam [2:0]
        S_IDLE       = 3'd0,
        S_BRAM_REQ   = 3'd1,
        S_BRAM_WAIT1 = 3'd2,
        S_BRAM_WAIT2 = 3'd3,
        S_AW         = 3'd4,
        S_W          = 3'd5,
        S_B          = 3'd6;

    reg [2:0] state;

    reg [31:0] buffer [0:BURST_WORDS-1];

    reg [31:0] global_word_idx;   // total words already copied
    reg [15:0] load_count;        // index while filling burst buffer
    reg [15:0] send_count;        // index while sending burst buffer
    reg [15:0] burst_words_this;  // words in current burst

    assign m_wdata = buffer[send_count];

    integer k;

    always @(posedge clk) begin
        if (!nrst) begin
            state            <= S_IDLE;
            done             <= 1'b0;

            bram_addr        <= {BRAM_ADDR_WIDTH{1'b0}};
            bram_en          <= 1'b0;

            m_awaddr         <= 32'd0;
            m_awlen          <= 8'd0;
            m_awsize         <= 3'b010;   // 4 bytes
            m_awburst        <= 2'b01;    // INCR
            m_awvalid        <= 1'b0;

            m_wstrb          <= 4'b1111;
            m_wlast          <= 1'b0;
            m_wvalid         <= 1'b0;

            m_bready         <= 1'b0;

            m_araddr         <= 32'd0;
            m_arlen          <= 8'd0;
            m_arsize         <= 3'd0;
            m_arburst        <= 2'd0;
            m_arvalid        <= 1'b0;
            m_rready         <= 1'b0;

            global_word_idx  <= 32'd0;
            load_count       <= 16'd0;
            send_count       <= 16'd0;
            burst_words_this <= 16'd0;

            for (k = 0; k < BURST_WORDS; k = k + 1)
                buffer[k] <= 32'd0;

        end else begin
            case (state)
                S_IDLE: begin
                    // default idle values
                    done      <= 1'b0;
                    bram_en   <= 1'b0;
                    m_awvalid <= 1'b0;
                    m_wvalid  <= 1'b0;
                    m_wlast   <= 1'b0;
                    m_bready  <= 1'b0;

                    load_count <= 16'd0;
                    send_count <= 16'd0;

                    if (global_word_idx >= WORDS_TO_COPY) begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        // decide how many words to send in this burst
                        if ((WORDS_TO_COPY - global_word_idx) >= BURST_WORDS)
                            burst_words_this <= BURST_WORDS[15:0];
                        else
                            burst_words_this <= (WORDS_TO_COPY - global_word_idx);

                        bram_addr <= global_word_idx[BRAM_ADDR_WIDTH-1:0];
                        bram_en   <= 1'b1;
                        state     <= S_BRAM_REQ;
                    end
                end

                // present BRAM address
                S_BRAM_REQ: begin
                    bram_en <= 1'b1;
                    state   <= S_BRAM_WAIT1;
                end

                // wait 1st BRAM latency cycle
                S_BRAM_WAIT1: begin
                    state <= S_BRAM_WAIT2;
                end

                // wait 2nd cycle and capture data
                S_BRAM_WAIT2: begin
                    buffer[load_count] <= bram_data;

                    if (load_count == burst_words_this - 1) begin
                        bram_en   <= 1'b0;

                        m_awaddr  <= DDR_BASE_ADDRESS + (global_word_idx << 2);
                        m_awlen   <= burst_words_this - 1;   // AXI = beats - 1
                        m_awsize  <= 3'b010;                 // 4 bytes per beat
                        m_awburst <= 2'b01;                  // INCR
                        m_awvalid <= 1'b1;

                        send_count <= 16'd0;
                        state      <= S_AW;
                    end else begin
                        load_count <= load_count + 1'b1;
                        bram_addr  <= global_word_idx + load_count + 1'b1;
                        state      <= S_BRAM_REQ;
                    end
                end

                S_AW: begin
                    if (m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;
                        m_wvalid  <= 1'b1;
                        m_wstrb   <= 4'b1111;
                        m_wlast   <= (burst_words_this == 1);
                        send_count <= 16'd0;
                        state     <= S_W;
                    end
                end

                S_W: begin
                    if (m_wvalid && m_wready) begin
                        if (send_count == burst_words_this - 1) begin
                            m_wvalid <= 1'b0;
                            m_wlast  <= 1'b0;
                            m_bready <= 1'b1;
                            state    <= S_B;
                        end else begin
                            send_count <= send_count + 1'b1;
                            m_wlast    <= (send_count == burst_words_this - 2);
                        end
                    end
                end

                S_B: begin
                    if (m_bvalid && m_bready) begin
                        m_bready        <= 1'b0;
                        global_word_idx <= global_word_idx + burst_words_this;

                        if (global_word_idx + burst_words_this >= WORDS_TO_COPY) begin
                            done  <= 1'b1;
                        end

                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule