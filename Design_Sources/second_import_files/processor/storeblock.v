//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// storeblock.v -- Store data module
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author: Microlab 198 Pipelined RISC-V Group (2SAY1920)
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Module Name: storeblock.v
// Description: Generates the data to be stored in the data memory
//				based on the store instruction used. The dm_write write enable
//				signal is also generated
//
// Revisions:
// Revision 0.01 - File Created
// Additional Comments:
// 
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

`timescale 1ns / 1ps
`include "config.vh"

module storeblock(
    input [31:0] opB,
    input [1:0] byte_offset,
    input [1:0] store_select,
    input is_stype,
    input load_in_mem,
    output [31:0] data,
    `ifdef FEATURE_BIT_ENABLE
        output [31:0] dm_write
    `else
        output [3:0] dm_write
    `endif
    );

    reg [3:0] dm_write_t;
    `ifdef FEATURE_BIT_ENABLE
        assign dm_write = {{8{dm_write_t[3]}}, {8{dm_write_t[2]}}, {8{dm_write_t[1]}}, {8{dm_write_t[0]}}};
    `else
        assign dm_write = dm_write_t;
    `endif
    
    parameter sw = 2'd2;
    parameter sh = 2'd1;
    parameter sb = 2'd0;
    
    wire [31:0] nboff_data;
    wire [31:0] nboff_data_shift;
    
    assign nboff_data = (store_select == sb) ? {24'd0 , opB[7:0]} : (store_select == sh) ? {16'd0, opB[15:0]} : opB ;
    assign nboff_data_shift = nboff_data << (8*byte_offset);
    assign data = {nboff_data_shift[7:0], nboff_data_shift[15:8], nboff_data_shift[23:16], nboff_data_shift[31:24]};
    
    // Original implementation was big-endian [b+3, b+2, b+1, b]
    // Changed to little-endian to accomodate RISC-V GNU Assembler Output [b, b+1, b+2, b+3]

	always@(*) begin
        if (~load_in_mem) begin
            case(store_select)
                sb:
                    case({is_stype, byte_offset})
                        3'b100: dm_write_t = 4'b1000;
                        3'b101: dm_write_t = 4'b0100;
                        3'b110: dm_write_t = 4'b0010;
                        3'b111: dm_write_t = 4'b0001;
                        default: dm_write_t = 4'b0000;
                    endcase
                sh:
                    case({is_stype, byte_offset})
                        3'b100: dm_write_t = 4'b1100;
                        3'b110: dm_write_t = 4'b0011;
                        default: dm_write_t = 4'b0000;
                    endcase
                sw:
                    case({is_stype, byte_offset})
                        3'b100: dm_write_t = 4'b1111;
                        default: dm_write_t = 4'b0000;
                    endcase

                default: dm_write_t = 4'b0000;
    		endcase
        end
        else begin
            // prioritize loads over stores
            dm_write_t = 4'b0000;
        end 
	end
endmodule
