`timescale 1ns / 1ps
`include "constants.vh"
`include "config.vh"

module mem_protocol_driver (
    input clk,
    input nrst,

    // Interface Control Signals
    input issue_op,
    output busy,
    output reg ready,                   // ready to read from load output
    output reg delay_store,
    input is_load,

    // Memory I/O
    input [`DATAMEM_BITS-1:0] issue_addr,
    output reg [`DATAMEM_BITS-1:0] addr_out,
    
    input [`WORD_WIDTH-1:0] read_in,
    output reg [`WORD_WIDTH-1:0] load_out,

    input [`WORD_WIDTH-1:0] store_in,
    output reg [`WORD_WIDTH-1:0] write_out,
    
    `ifdef FEATURE_BIT_ENABLE
        input [31:0] wren, 
        output reg [31:0] wren_out,
    `else
        input [3:0] wren, 
        output reg [3:0] wren_out,
    `endif
        
    // Memory Control Signals
    output reg req,
    input gnt,
    input valid
    );

    reg [`DATAMEM_BITS-1:0] addr_buffer;
    reg [`WORD_WIDTH-1:0] load_buffer;
    reg [`WORD_WIDTH-1:0] write_buffer;
    `ifdef FEATURE_BIT_ENABLE
        reg [31:0] wren_buffer;
    `else
        reg [3:0] wren_buffer;
    `endif

    reg [2:0] mem_state;
    reg hold_state;

    localparam MEM_START = 3'h0;
    localparam MEM_WAIT_LOAD = 3'h1;
    localparam MEM_GRANT_LOAD = 3'h2;
    localparam MEM_VALID_LOAD = 3'h3;
    localparam MEM_WAIT_STORE = 3'h4;
    localparam MEM_GRANT_STORE = 3'h5;
    // localparam MEM_CLEANUP = 3'h7;

    wire op_type = is_load;
    
    localparam OP_LOAD = 1'b1;
    localparam OP_STORE = 1'b0;

    assign busy = (mem_state != MEM_START) || (issue_op && !hold_state);
    
    assign addr_out = addr_buffer;
    assign load_out = load_buffer;
    assign write_out = write_buffer;
    assign wren_out = wren_buffer;

    
    
    always@(posedge clk) begin
        if(!nrst) begin
            delay_store <= 0;
            hold_state <= 0;
        end
        else begin
            delay_store <= ((mem_state == MEM_START) || op_type == OP_STORE) ? 0 : hold_state;
            hold_state <= (mem_state == MEM_START) ? issue_op : hold_state;
        end
    end

    always@(posedge clk) begin
        if(!nrst) begin
            addr_buffer <= 0;
            load_buffer <= 0;
            write_buffer <= 0;
            wren_buffer <= 0;
            req <= 0;

            mem_state <= MEM_START;
        end
        else begin
            case(mem_state)
                MEM_START: begin
                    if (issue_op) begin
                        addr_buffer <= issue_addr;
                        load_buffer <= 0;
                        req <= 1;

                        if (op_type == OP_LOAD) begin
                            write_buffer <= 0;
                            wren_buffer <= 4'd0;
                            mem_state <= MEM_WAIT_LOAD;
                        end
                        else begin
                            write_buffer <= store_in;
                            wren_buffer <= wren;
                            mem_state <= MEM_WAIT_STORE;
                        end
                    end
                    else begin
                        addr_buffer <= 0;
                        load_buffer <= 0;
                        write_buffer <= 0;
                        wren_buffer <= 4'd0;
                        req <= 0;

                        mem_state <= MEM_START;
                    end
                end
                MEM_WAIT_LOAD: begin
                    write_buffer <= 0;
                    wren_buffer <= 4'd0;
                    if (gnt) begin
                        req <= 0;
                        addr_buffer <= 0;
                        `ifdef FEATURE_NEGEDGE_ENABLE
                        // 1+ cycle delay
                        if (valid) begin
                            load_buffer <= read_in;
                            mem_state <= MEM_VALID_LOAD;
                        end
                        else begin
                            load_buffer <= 0;
                            mem_state <= MEM_GRANT_LOAD;
                        end
                        `else
                        load_buffer <= 0;
                        mem_state <= MEM_GRANT_LOAD;
                        `endif
                    end
                    else begin
                        addr_buffer <= addr_buffer;
                        load_buffer <= 0;
                        req <= 1;
                        mem_state <= MEM_WAIT_LOAD;
                    end
                end
                MEM_GRANT_LOAD: begin
                    write_buffer <= 0;
                    wren_buffer <= 4'd0;
                    req <= 0;
                    addr_buffer <= 0;
                    
                    if (valid) begin
                        load_buffer <= read_in;
                        mem_state <= MEM_VALID_LOAD;
                    end
                    else begin
                        load_buffer <= 0;
                        mem_state <= MEM_GRANT_LOAD;
                    end
                end
                MEM_VALID_LOAD: begin
                    addr_buffer <= 0;
                    load_buffer <= 0;
                    write_buffer <= 0;
                    wren_buffer <= 4'd0;
                    req <= 0;

                    mem_state <= MEM_START;
                end
                MEM_WAIT_STORE: begin
                    if (gnt) begin
                        write_buffer <= 0;
                        wren_buffer <= 0;
                        addr_buffer <= 0;
                        req <= 0;
                        load_buffer <= 0;
                        mem_state <= MEM_START;
                    end
                    else begin
                        write_buffer <= write_buffer;
                        wren_buffer <= wren_buffer;
                        addr_buffer <= addr_buffer;
                        req <= 1;
                        load_buffer <= 0;
                        mem_state <= MEM_WAIT_STORE;
                    end
                end
                default: begin
                    addr_buffer <= 0;
                    load_buffer <= 0;
                    write_buffer <= 0;
                    wren_buffer <= 4'd0;
                    req <= 0;

                    mem_state <= MEM_START;
                end
            endcase
        end
    end
    
    always@(posedge clk) begin
        if (!nrst) begin
            ready <= 0;
        end
        else begin
            case(mem_state)
                MEM_WAIT_LOAD: begin
                    `ifdef FEATURE_NEGEDGE_ENABLE
                    if (valid) begin
                        ready <= 1;
                    end
                    else begin
                        ready <= 0;
                    end
                    `else
                    ready <= 0;
                    `endif
                end
                MEM_GRANT_LOAD: begin
                    if (valid) begin
                        ready <= 1;
                    end
                    else begin
                        ready <= 0;
                    end
                end
                MEM_WAIT_STORE: begin
                    if (gnt) begin
                        ready <= 1;
                    end
                    else begin
                        ready <= 0;
                    end
                end
                default:
                    ready <= 0;
            endcase
        end
    end
endmodule
