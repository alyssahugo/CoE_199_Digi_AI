//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// alu.v -- ALU for the RV32IMC processor
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author: Microlab 198 Single-cycle RISC-V Group (2SAY1819)
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Module Name: alu.v
// Description:
//
// Revisions:
// Revision 0.01 - File Created
// Revision 1.00 - File modified by Pipelined RISC-V Group (2SAY1920)
// Additional Comments:
// 
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


`timescale 1ns / 1ps
`include "constants.vh"
`include "config.vh"

module alu(
	input CLK,
	input nrst,
	input load_hazard,

	input [`WORD_WIDTH-1:0] op_a,
	input [`WORD_WIDTH-1:0] op_b,
	input [3:0] ALU_op,

	output reg [`WORD_WIDTH-1:0] res,
	output mul_stall,
	output z,
	output less,
	output signed_less
);

	wire signed [`WORD_WIDTH-1:0] signed_a = op_a;
	wire signed [`WORD_WIDTH-1:0] signed_b = op_b;
	wire [2*`WORD_WIDTH-1:0]  ext_a = {{`WORD_WIDTH{((ALU_op == `ALU_MULH) || (ALU_op == `ALU_MULHSU)) && op_a[`WORD_WIDTH-1]}}, op_a};
	wire [2*`WORD_WIDTH-1:0]  ext_b = {{`WORD_WIDTH{(ALU_op == `ALU_MULH) && op_b[`WORD_WIDTH-1]}}, op_b};
        
    `ifdef FEATURE_MULT   
        wire [63:0] mul_res = ext_a * ext_b;
    `else 
        wire [63:0] mul_res = 0;
    `endif
         
	assign z	=	op_a == op_b;
	assign less =	op_a < op_b;
	assign signed_less	=	signed_a < signed_b;

	// This controls mul_stall which asserts for one cycle only whenever a multiplication
	// operation is present.
	// NOTE: if a load_hazard is present, we delay the update of mul_stall by 1 cycle.
    `ifdef FEATURE_MULT
        reg mul_stall_reg;
        reg [`WORD_WIDTH-1:0] mul_res_reg;
        // initial mul_stall_reg = 0;
        wire is_mul = (ALU_op > 4'd10) & (ALU_op != 4'd15);
        always@(posedge CLK) begin
            if(!nrst) begin 
                mul_stall_reg <= 0;
                mul_res_reg <= 32'd0;
            end
            else if (!load_hazard) begin
                mul_stall_reg <= is_mul & mul_stall;
                if (is_mul) begin
                    if (ALU_op == `ALU_MUL)
                        mul_res_reg <= mul_res[31:0];
                    else
                        mul_res_reg <= mul_res[63:32];
                end
				else
					mul_res_reg <= 32'd0;
            end
        end
        assign mul_stall = ~mul_stall_reg & is_mul;
    `else
        assign mul_stall = 0;
    `endif
    

	always@(*) begin
		case(ALU_op)
		    // base ISA
			`ALU_ADD: res = op_a + op_b;
			`ALU_SUB: res = op_a - op_b;
			`ALU_AND: res = op_a & op_b;
			`ALU_OR: res = op_a | op_b;
			`ALU_XOR: res = op_a ^ op_b;
			`ALU_SLT: res = signed_a < signed_b;
			`ALU_SLTU: res = op_a < op_b;
			`ALU_SLL: res = op_a << op_b[4:0];
			`ALU_SRL: res = op_a >> op_b[4:0];
			`ALU_SRA: res = signed_a >>> signed_b[4:0];
            // M extension
			`ALU_MUL: res = mul_res_reg;
			`ALU_MULHU: res = mul_res_reg;
			`ALU_MULH: res = mul_res_reg;
			`ALU_MULHSU: res = mul_res_reg;
            // division unimplemented
            
            //other ops 
			default: res = 32'h0;
		endcase
	end
endmodule
