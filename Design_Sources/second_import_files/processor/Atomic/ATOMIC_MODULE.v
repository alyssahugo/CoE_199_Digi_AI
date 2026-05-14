//`timescale 1ns / 1ps
//`include "constants.vh"
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 01/27/2025 09:50:40 AM
//// Design Name: 
//// Module Name: ATOMIC_MODULE
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: The atomic module to be placed in the MEM stage. Contains a small ALU for the binary operations (so we wouldnt need
////              to go back to EXE stage)
////              i_is_atomic - signal from ID stage if instruction is Atomic. Serves as enable signal
////              i_opA, i_opB - input operands. One from memory, one from register file
////              funct5 - 5 bits telling the binary op
////
////              Also functions as the interface to the On-Chip memory
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module ATOMIC_MODULE
//    #(
//    parameter ADDR_BITS = 12
//    )
//    (
//    input clk,
//    input nrst,
//    input i_wr,
//    input i_rd,
//    input i_is_atomic,
    
//    input [31:0] i_data_from_core,  // Data to be sent to OCM
//    input [31:0] i_data_from_OCM,
//    input [31:0] i_addr,
//    input [3:0] i_dm_write,
//    input [3:0] i_atomic_op,
//    input i_grant,
//    input i_data_valid,
//    input i_data_write_valid,
    
//    input [31:0] i_opB,                    // RS2 if Atomic
    
//    output o_wr,
//    output o_rd,
//    output [31:0] o_data_to_OCM,
//    output [31:0] o_addr, // AXI wants 32 bits 
//    output [3:0] o_dm_write,
//    output [31:0] o_data_to_WB,     // to Writeback stage
//    output o_request,
   
//    output reg o_done,          
//    output reg o_ready,
//    output  o_stall_atomic,
//    output [31:0] probe_res
//    );
    
//    //pass through
//    reg o_wr_t;
//    assign o_rd = i_rd || i_is_atomic;
//    assign o_wr = i_wr || o_wr_t;
    
    
    
//    wire initial_stall;
//    reg r_stall;
    
//    reg [31:0] res_t;
//    wire [31:0] res;
//    assign res = {res_t[7:0], res_t[15:8], res_t[23:16], res_t[31:24]}; // little endian
//    reg [31:0] temp_t;
//    wire [31:0] temp;
//    assign temp = {temp_t[7:0], temp_t[15:8], temp_t[23:16], temp_t[31:24]}; // little endian

                                
                                
//    // FSM of the module.
//    // If instruction is atomic, stall the IF, ID, and EXE stage till phases are done
//    // State:
//    // 4'd0 S_IDLE - wait for operations and wait for memory resources to be free
//    // 4'd1 S_GRANT - arbitrator gives grant to core; wait for valid signals
//    // 4'd2 S_ATOMIC_VALID_READ - valid data received at ports; wait for valid write after doing atomic operations on data
//    // 4'd3 S_ATOMIC_VALID_WRITE - confirmation that result is written in memory
//    // 4'd4 S_ATOMIC_DONE - atomic operation is done
//    //
//    // 4'd5 S_BASIC_LOAD - if load operation at non-cacheable region, wait for valid data
//    // 4'd6 S_BASIC_STORE - if write operation at non-cacheable region, wait for write confirmation
//    // 4'd7 S_BASIC_LOAD_RESP - basic load is done. valid data available for WB stage
//    // 4'd8 S_BASIC_WRITE_RESP - basic write is done. valid data is written at OCM
//    // 4'd9 S_DONE - load/store operation done. Cleanup. 
//    reg [3:0] state;
//    localparam S_IDLE = 4'd0;
//    localparam S_WAIT = 4'd1;
//    localparam S_GRANT = 4'd2;
//    localparam S_ATOMIC_VALID_READ = 4'd3;
//    localparam S_ATOMIC_VALID_WRITE = 4'd4;
//    localparam S_DONE = 4'd5;
    
//    localparam S_BASIC_LOAD = 4'd6;
//    localparam S_BASIC_STORE = 4'd7; 
//    localparam S_BASIC_LOAD_RESP = 4'd8; 
//    localparam S_BASIC_WRITE_RESP = 4'd9;

    
//    initial begin
//        state <= S_IDLE;
//        r_stall <= 0;
//    end
    
//    // I had to change this to negedge clk because I couldn't figure out for the life of me to make this work 
//    // in posedge clk.
        
//    always @ (negedge clk) begin
//        if (!nrst) begin
//            state <= S_IDLE;
//            r_stall <= 0;
//            temp_t <= 0;
//            //res <= 0;
//            o_wr_t <= 0;
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    if ( i_is_atomic || i_rd || i_wr) begin
//                        state <= S_WAIT;
//                        r_stall <= 1;
//                    end 
//                    else begin
//                        state <= S_IDLE;
//                        o_ready <= 0; 
//                    end
//                    o_done <= 0;
//                end
//                S_WAIT: begin
//                    if (!(i_wr || i_rd || i_is_atomic)) begin
//                        state <= S_IDLE; // go back to idle since we were wrong to enter here
//                        r_stall <= 0;
//                    end
//                    if (( i_is_atomic || i_rd || i_wr) && i_grant) state <= S_GRANT;
//                end
//                S_GRANT: begin
//                    // grant is given, wait for memory to complete the request
//                    if (i_data_valid && i_is_atomic) begin
//                        state <= S_ATOMIC_VALID_READ;
//                        o_wr_t <= 1;
//                        temp_t <= i_data_from_OCM;
//                    end
//                    else if (i_data_valid && i_rd) begin
//                        state <= S_BASIC_LOAD;
//                        temp_t <= i_data_from_OCM;
//                    end
                    
//                    else if (i_data_write_valid && i_wr) begin
//                        state <= S_BASIC_STORE;
                        
//                    end
//                    else state <= S_GRANT;
//                end
                
//                S_ATOMIC_VALID_READ: begin
//                    // do the work and operatin
//                    // wait for valid writes
//                    if (i_data_write_valid && i_is_atomic) begin
//                        state <= S_ATOMIC_VALID_WRITE;
                        
//                    end
//                end
                
//                S_ATOMIC_VALID_WRITE: begin
//                    state <= S_DONE;
//                    o_wr_t <= 0;
//                    o_done <= 1;
//                    o_ready <= 1;
//                    //r_stall <= 0;
//                end
                
//                S_DONE: begin
//                    //bypass the IDLE if consecutive requests?
//                    /*
//                    if (i_is_atomic || i_wr || i_rd) begin 
//                        state <= S_WAIT;
//                        r_stall <= 1;
//                    end
//                    */
//                    //else begin
//                        state <= S_IDLE;
//                        r_stall <= 0;
//                        o_ready <= 0;
//                    //end
//                end
                
//                S_BASIC_LOAD: begin
//                    //r_stall <= 0;
//                    state <= S_DONE;
//                    o_done <= 1;
//                    o_ready <= 1;
//                end
                
//                S_BASIC_STORE: begin
//                    //r_stall <= 0;
//                    state <= S_DONE;
//                    o_done <= 1;
                    
//                    o_ready <= 1;
//                end
//            endcase
            

//        end
        
//    end
    
//    // Small ALU module for binary operation
//    // 5 bits to tell the operation
//    // amoadd - 00000
//    // amoswap - 00001
//    // amoxor - 00100
//    // amoand - 01100
//    // etc
    
//    always @ (*) begin
//        res_t = 0;
//        case (i_atomic_op) 
//            4'd2: res_t = temp + i_opB;
//            4'd1: res_t = i_opB;
//            4'd3: res_t = temp ^ i_opB;
//            4'd4: res_t = temp & i_opB;
//            4'd5: res_t = temp | i_opB;
//            default: res_t = 0;
//            // to follow: minimum and maximums;
//        endcase
//    end
    
//    //assign initial_stall = (i_is_atomic || i_rd || i_wr) && !i_grant;
//    assign probe_res = res_t;
    
//    //assign o_done = (state == S_DONE) ? 1'b1 : 1'b0;
//    assign o_request = (i_is_atomic || i_wr || i_rd);
//    assign o_data_to_OCM = (i_is_atomic) ? res : i_data_from_core;
    
//    // Could be problematic
//    // we could not catch the dm_write correctly
//    assign o_dm_write = (i_is_atomic) ? 
//                            ( !(state == S_ATOMIC_VALID_READ) ) ? 4'b0000 : 4'b1111
//                         : (i_rd || i_wr) ? i_dm_write : 4'b0000  ;
    
    
    
//    assign o_data_to_WB = (i_is_atomic) ? 
//                            (i_atomic_op == 1) ? temp_t : res_t
//                            : temp_t;
    
//    assign o_addr = i_addr;
//    assign o_stall_atomic =  r_stall;
//endmodule

//`timescale 1ns / 1ps
//`include "constants.vh"

//module ATOMIC_MODULE
//    #(
//    parameter ADDR_BITS = 12
//    )
//    (
//    input clk,
//    input nrst,
//    input i_wr,
//    input i_rd,
//    input i_is_atomic,

//    input [31:0] i_data_from_core,
//    input [31:0] i_data_from_OCM,
//    input [31:0] i_addr,
//    input [3:0] i_dm_write,
//    input [3:0] i_atomic_op,
//    input i_grant,
//    input i_data_valid,
//    input i_data_write_valid,

//    input [31:0] i_opB,

//    output o_wr,
//    output o_rd,
//    output [31:0] o_data_to_OCM,
//    output [31:0] o_addr,
//    output [3:0] o_dm_write,
//    output [31:0] o_data_to_WB,
//    output o_request,

//    output reg o_done,
//    output reg o_ready,
//    output o_stall_atomic,
//    output [31:0] probe_res
//    );

//    reg o_wr_t;
//    assign o_rd = i_rd || i_is_atomic;
//    assign o_wr = i_wr || o_wr_t;

//    reg r_stall;

//    reg [31:0] res_t;
//    wire [31:0] res;
//    assign res = {res_t[7:0], res_t[15:8], res_t[23:16], res_t[31:24]};

//    reg [31:0] temp_t;
//    wire [31:0] temp;
//    assign temp = {temp_t[7:0], temp_t[15:8], temp_t[23:16], temp_t[31:24]};

//    reg [3:0] state;
//    localparam S_IDLE = 4'd0;
//    localparam S_WAIT = 4'd1;
//    localparam S_GRANT = 4'd2;
//    localparam S_ATOMIC_VALID_READ = 4'd3;
//    localparam S_ATOMIC_VALID_WRITE = 4'd4;
//    localparam S_DONE = 4'd5;
//    localparam S_BASIC_LOAD = 4'd6;
//    localparam S_BASIC_STORE = 4'd7;
//    localparam S_BASIC_LOAD_RESP = 4'd8;
//    localparam S_BASIC_WRITE_RESP = 4'd9;

//    initial begin
//        state <= S_IDLE;
//        r_stall <= 0;
//    end

//    always @ (negedge clk) begin
//        if (!nrst) begin
//            state   <= S_IDLE;
//            r_stall <= 0;
//            temp_t  <= 0;
//            o_wr_t  <= 0;
//            o_done  <= 0;
//            o_ready <= 0;
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    o_done  <= 0;
//                    o_ready <= 0;
//                    o_wr_t  <= 0;

//                    if (i_is_atomic || i_rd || i_wr) begin
//                        state   <= S_WAIT;
//                        r_stall <= 1;
//                    end else begin
//                        state   <= S_IDLE;
//                        r_stall <= 0;
//                    end
//                end

//                S_WAIT: begin
//                    if (!(i_wr || i_rd || i_is_atomic)) begin
//                        state <= S_IDLE;
//                        r_stall <= 0;
//                    end
//                    else if ((i_is_atomic || i_rd || i_wr) && i_grant) begin
//                        state <= S_GRANT;
//                    end
//                end

//                S_GRANT: begin
//                    if (i_data_valid && i_is_atomic) begin
//                        temp_t <= i_data_from_OCM;
//                        o_wr_t <= 1;
//                        state  <= S_ATOMIC_VALID_READ;
//                    end
//                    else if (i_data_valid && i_rd) begin
//                        temp_t <= i_data_from_OCM;
//                        state  <= S_BASIC_LOAD;
//                    end
//                    else if (i_data_write_valid && i_wr) begin
//                        state <= S_BASIC_STORE;
//                    end
//                    else begin
//                        state <= S_GRANT;
//                    end
//                end

//                S_ATOMIC_VALID_READ: begin
//                    if (i_data_write_valid && i_is_atomic) begin
//                        state <= S_ATOMIC_VALID_WRITE;
//                    end
//                end

//                S_ATOMIC_VALID_WRITE: begin
//                    state   <= S_DONE;
//                    o_wr_t  <= 0;
//                    o_done  <= 1;
//                    o_ready <= 1;
//                end

//                S_DONE: begin
//                    state   <= S_IDLE;
//                    r_stall <= 0;
//                    o_ready <= 0;
//                    o_wr_t  <= 0;
//                end

//                S_BASIC_LOAD: begin
//                    state   <= S_DONE;
//                    o_done  <= 1;
//                    o_ready <= 1;
//                end

//                S_BASIC_STORE: begin
//                    state   <= S_DONE;
//                    o_done  <= 1;
//                    o_ready <= 1;
//                end
//            endcase
//        end
//    end

//    always @ (*) begin
//        res_t = 0;
//        case (i_atomic_op)
//            4'd2: res_t = temp + i_opB;
//            4'd1: res_t = i_opB;
//            4'd3: res_t = temp ^ i_opB;
//            4'd4: res_t = temp & i_opB;
//            4'd5: res_t = temp | i_opB;
//            default: res_t = 0;
//        endcase
//    end

//    assign probe_res = res_t;

//    assign o_request = (i_is_atomic || i_wr || i_rd);
//    assign o_data_to_OCM = (i_is_atomic) ? res : i_data_from_core;

//    assign o_dm_write = (i_is_atomic) ?
//                            ((state == S_ATOMIC_VALID_READ) ? 4'b1111 : 4'b0000)
//                        : (i_rd || i_wr) ? i_dm_write : 4'b0000;

//    assign o_data_to_WB = (i_is_atomic) ?
//                            ((i_atomic_op == 1) ? temp_t : res_t)
//                        : temp_t;

//    assign o_addr = i_addr;
//    assign o_stall_atomic = r_stall;
//endmodule


`timescale 1ns / 1ps
`include "constants.vh"

module ATOMIC_MODULE
    #(
    parameter ADDR_BITS = 12
    )
    (
    input clk,
    input nrst,
    input i_wr,
    input i_rd,
    input i_is_atomic,

    input [31:0] i_data_from_core,
    input [31:0] i_data_from_OCM,
    input [31:0] i_addr,
    input [3:0] i_dm_write,
    input [3:0] i_atomic_op,
    input i_grant,
    input i_data_valid,
    input i_data_write_valid,

    input [31:0] i_opB,

    output o_wr,
    output o_rd,
    output [31:0] o_data_to_OCM,
    output [31:0] o_addr,
    output [3:0] o_dm_write,
    output [31:0] o_data_to_WB,
    output o_request,

    output reg o_done,
    output reg o_ready,
    output o_stall_atomic,
    output [31:0] probe_res,
    
    output [31:0] probe_temp_t,
    output [31:0] probe_data_from_OCM,
    output        probe_data_valid,
    output [3:0]  probe_state
    );

    reg o_wr_t;
    assign o_rd = i_rd || i_is_atomic;
    assign o_wr = i_wr || o_wr_t;

    reg r_stall;

    reg [31:0] res_t;
    wire [31:0] res;
    assign res = {res_t[7:0], res_t[15:8], res_t[23:16], res_t[31:24]};

    reg [31:0] temp_t;
    wire [31:0] temp;
    assign temp = {temp_t[7:0], temp_t[15:8], temp_t[23:16], temp_t[31:24]};

    reg [3:0] state;
    localparam S_IDLE               = 4'd0;
    localparam S_WAIT               = 4'd1;
    localparam S_GRANT              = 4'd2;
    localparam S_ATOMIC_VALID_READ  = 4'd3;
    localparam S_ATOMIC_VALID_WRITE = 4'd4;
    localparam S_DONE               = 4'd5;
    localparam S_BASIC_LOAD         = 4'd6;
    localparam S_BASIC_STORE        = 4'd7;
    localparam S_BASIC_LOAD_RESP    = 4'd8;
    localparam S_BASIC_WRITE_RESP   = 4'd9;

    initial begin
        state   <= S_IDLE;
        r_stall <= 0;
    end

    always @ (negedge clk) begin
        if (!nrst) begin
            state   <= S_IDLE;
            r_stall <= 0;
            temp_t  <= 32'h0000_0000;
            o_wr_t  <= 1'b0;
            o_done  <= 1'b0;
            o_ready <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    o_done  <= 1'b0;
                    o_ready <= 1'b0;
                    o_wr_t  <= 1'b0;

                    // Clear captured read data only when starting a NEW transaction.
                    if (i_is_atomic || i_rd || i_wr) begin
//                        temp_t  <= 32'h0000_0000;
                        state   <= S_WAIT;
                        r_stall <= 1'b1;
                    end else begin
                        state   <= S_IDLE;
                        r_stall <= 1'b0;
                    end
                end

                S_WAIT: begin
                    if (!(i_wr || i_rd || i_is_atomic)) begin
                        state   <= S_IDLE;
                        r_stall <= 1'b0;
                    end
                    else if ((i_is_atomic || i_rd || i_wr) && i_grant) begin
                        state <= S_GRANT;
                    end
                end

                S_GRANT: begin
                    // Keep latching read data whenever valid is present.
                    // This makes the response sticky instead of depending on a
                    // fragile single-cycle coincidence.
                    if (i_data_valid) begin
                        temp_t <= i_data_from_OCM;
                    end

                    if (i_data_valid && i_is_atomic) begin
                        o_wr_t <= 1'b1;
                        state  <= S_ATOMIC_VALID_READ;
                    end
                    else if (i_data_valid && i_rd) begin
                        state  <= S_BASIC_LOAD;
                    end
                    else if (i_data_write_valid && i_wr) begin
                        state  <= S_BASIC_STORE;
                    end
                    else begin
                        state  <= S_GRANT;
                    end
                end

                S_ATOMIC_VALID_READ: begin
                    // Hold temp_t; do not clear it here.
                    if (i_data_write_valid && i_is_atomic) begin
                        state <= S_ATOMIC_VALID_WRITE;
                    end
                end

                S_ATOMIC_VALID_WRITE: begin
                    state   <= S_DONE;
                    o_wr_t  <= 1'b0;
                    o_done  <= 1'b1;
                    o_ready <= 1'b1;
                end

                S_DONE: begin
                    state   <= S_IDLE;
                    r_stall <= 1'b0;
                    o_ready <= 1'b0;
                    o_wr_t  <= 1'b0;
                    // Do NOT clear temp_t here. Let it remain stable until
                    // the next transaction starts in S_IDLE.
                end

                S_BASIC_LOAD: begin
                    state   <= S_DONE;
                    o_done  <= 1'b1;
                    o_ready <= 1'b1;
                    // Do NOT clear temp_t here.
                end

                S_BASIC_STORE: begin
                    state   <= S_DONE;
                    o_done  <= 1'b1;
                    o_ready <= 1'b1;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    always @ (*) begin
        res_t = 32'h0000_0000;
        case (i_atomic_op)
            4'd2: res_t = temp + i_opB;
            4'd1: res_t = i_opB;
            4'd3: res_t = temp ^ i_opB;
            4'd4: res_t = temp & i_opB;
            4'd5: res_t = temp | i_opB;
            default: res_t = 32'h0000_0000;
        endcase
    end

    assign probe_res = res_t;

    assign o_request     = (i_is_atomic || i_wr || i_rd);
    assign o_data_to_OCM = (i_is_atomic) ? res : i_data_from_core;

    assign o_dm_write = (i_is_atomic) ?
                            ((state == S_ATOMIC_VALID_READ) ? 4'b1111 : 4'b0000)
                        : (i_rd || i_wr) ? i_dm_write : 4'b0000;

    assign o_data_to_WB = (i_is_atomic) ?
                            ((i_atomic_op == 1) ? temp_t : res_t)
                        : temp_t;

    assign o_addr         = i_addr;
    assign o_stall_atomic = r_stall;
    
    assign probe_temp_t        = temp_t;
    assign probe_data_from_OCM = i_data_from_OCM;
    assign probe_data_valid    = i_data_valid;
    assign probe_state         = state;

endmodule

