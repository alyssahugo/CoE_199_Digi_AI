////-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//// instmem.v -- Instruction memory module
////-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//// Author: Microlab 198 Pipelined RISC-V Group (2SAY1920)
////-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
////
////-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//// Module Name: instmem.v
//// Description: This module implements the 8kB Instruction memory used by the RISC-V core.
////				4kB each are allocated for the main instmem & ISR ROMs. Both ROMs are
////				halfword addressable for compressed instructions support.
////
//// Revisions:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


//`timescale 1ns / 1ps

//`include "constants.vh"

//module instmem (
//    input clk,
//    input nrst,
//	input sel_ISR,

//	input [`EXT_PC_ADDR_BITS-1:0] addr,
//	output [`WORD_WIDTH-1:0] instruction,
	
//	// Instruction refill ports
//	input refill_valid,
//	input [`WORD_WIDTH-1:0] inst_refill
	
//);
	
//	wire [`WORD_WIDTH-1:0] prog;
//	// wire [`WORD_WIDTH-1:0] isr;
//	wire [`WORD_WIDTH-1:0] inst_t;
//	reg [`WORD_WIDTH-1:0] inst_reg;

//	reg [`WORD_WIDTH-1:0] instmem [0:`MEM_DEPTH-1];
	
//	reg [`EXT_PC_ADDR_BITS-1:0] refill_pointer;
	
//	assign prog = instmem[addr];

//    assign inst_t = prog;
//    assign instruction = inst_reg;
    
    
//    always@(posedge clk) begin
//        if (!nrst) begin
//            inst_reg <= 32'd0;
//            refill_pointer <= 0;
//        end else begin
//            inst_reg <= inst_t;
//            if (refill_valid) begin
//                refill_pointer <= refill_pointer + 1;
//                instmem[refill_pointer] <= inst_refill;
//            end
//        end
//    end
//endmodule


//`timescale 1ns / 1ps

//`include "constants.vh"

//module instmem (
//    input clk,
//    input nrst,
//    input sel_ISR,

//    input [`EXT_PC_ADDR_BITS-1:0] addr,
//    output reg [`WORD_WIDTH-1:0] instruction,

//    input refill_valid,
//    input [`WORD_WIDTH-1:0] inst_refill
//);

//    // 2 banks of 32768 words each
//    reg [`WORD_WIDTH-1:0] instmem_bank0 [0:32767];
//    reg [`WORD_WIDTH-1:0] instmem_bank1 [0:32767];

//    reg [`EXT_PC_ADDR_BITS-1:0] refill_pointer;

//    wire bank_sel_r;
//    wire [14:0] bank_addr_r;

//    wire bank_sel_w;
//    wire [14:0] bank_addr_w;

//    reg [`WORD_WIDTH-1:0] inst_word;

//    assign bank_sel_r  = addr[15];
//    assign bank_addr_r = addr[14:0];

//    assign bank_sel_w  = refill_pointer[15];
//    assign bank_addr_w = refill_pointer[14:0];

//    always @(*) begin
//        if (bank_sel_r)
//            inst_word = instmem_bank1[bank_addr_r];
//        else
//            inst_word = instmem_bank0[bank_addr_r];
//    end

//    always @(posedge clk) begin
//        if (!nrst) begin
//            instruction <= 32'd0;
//            refill_pointer <= {`EXT_PC_ADDR_BITS{1'b0}};
//        end else begin
//            instruction <= inst_word;

//            if (refill_valid) begin
//                if (bank_sel_w)
//                    instmem_bank1[bank_addr_w] <= inst_refill;
//                else
//                    instmem_bank0[bank_addr_w] <= inst_refill;

//                refill_pointer <= refill_pointer + 1'b1;
//            end
//        end
//    end

//endmodule


`timescale 1ns / 1ps

`include "constants.vh"

module instmem (
    input clk,
    input nrst,
    input sel_ISR,

    input [`EXT_PC_ADDR_BITS-1:0] addr,
    output reg [`WORD_WIDTH-1:0] instruction,

    input refill_valid,
    input [`WORD_WIDTH-1:0] inst_refill
);

    (* ram_style = "block" *) reg [`WORD_WIDTH-1:0] instmem_bank0 [0:32767];
    (* ram_style = "block" *) reg [`WORD_WIDTH-1:0] instmem_bank1 [0:32767];

    reg [`EXT_PC_ADDR_BITS-1:0] refill_pointer;

    wire bank_sel_r;
    wire [14:0] bank_addr_r;

    wire bank_sel_w;
    wire [14:0] bank_addr_w;

    reg [`WORD_WIDTH-1:0] inst_word;

    assign bank_sel_r  = addr[15];
    assign bank_addr_r = addr[14:0];

    assign bank_sel_w  = refill_pointer[15];
    assign bank_addr_w = refill_pointer[14:0];

    always @(*) begin
        if (bank_sel_r)
            inst_word = instmem_bank1[bank_addr_r];
        else
            inst_word = instmem_bank0[bank_addr_r];
    end

    always @(posedge clk) begin
        if (!nrst) begin
            instruction <= 32'd0;
            refill_pointer <= {`EXT_PC_ADDR_BITS{1'b0}};
        end else begin
            instruction <= inst_word;

            if (refill_valid) begin
                if (bank_sel_w)
                    instmem_bank1[bank_addr_w] <= inst_refill;
                else
                    instmem_bank0[bank_addr_w] <= inst_refill;

                refill_pointer <= refill_pointer + 1'b1;
            end
        end
    end

endmodule