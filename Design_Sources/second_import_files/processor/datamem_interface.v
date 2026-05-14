`timescale 1ns / 1ps
`include "constants.vh"
`include "config.vh"

module datamem_interface(
        input clk,
        input nrst,
        input [2:0] sel_data,           // Writeback data type -- check in lieu of explicit load signal
        input mem_flush,
        // Pass-through to Datamem
        input [`DATAMEM_BITS-1:0] exe_addr_in,
        input [`DATAMEM_BITS-1:0] mem_addr_in,
        `ifdef FEATURE_DMEM_BYTE_ADDRESS
            output [`BUS_BITS-1:0] addr_out,
        `else
            output [`DATAMEM_BITS-1:0] addr_out,
        `endif 
                
        // Store Block I/O
        input [31:0] sb_opB,
        input [1:0] sb_byte_offset,
        input [1:0] sb_store_select,
        input sb_is_stype,
        output [31:0] sb_data,
        `ifdef FEATURE_BIT_ENABLE
            output [31:0] sb_dm_write,
        `else
            output [3:0] sb_dm_write,
        `endif
        // Load Block I/O
        input [31:0] lb_data,    
        input [1:0] lb_byte_offset,    
        input [2:0] lb_dm_select,    
        output [31:0] lb_loaddata,
        
        // Control Outputs
        output dm_stall,
        output dm_req,
        input dm_gnt,
        input dm_valid,
        
        // Core Control I/O
        input [`REGFILE_BITS-1:0] mem_rd,
        output store_sel,
        output read_ready
    ); 
    
    wire [31:0] lb_data_t;
    wire [31:0] sb_data_t;
    wire [`DATAMEM_BITS-1:0] addr_out_t;
    `ifdef FEATURE_DMEM_BYTE_ADDRESS
        assign addr_out = {addr_out_t, 2'b0};
    `else
        assign addr_out = addr_out_t;
    `endif 
    `ifdef FEATURE_BIT_ENABLE
        wire [31:0] sb_dm_write_t;
    `else
        wire [31:0] sb_dm_write_t;
    `endif
    
    wire is_load = (sel_data == 3'd3) && (mem_rd != 0);
    wire is_mem_op = (sb_is_stype || is_load) && ~mem_flush;
    wire [`DATAMEM_BITS-1:0] addr_in = (is_load || store_sel) ? mem_addr_in : exe_addr_in;
    reg [`WORD_WIDTH-1:0] num_cycles;
    wire [`WORD_WIDTH-1:0] num_cycles_little_e = {num_cycles[7:0], num_cycles[15:8], num_cycles[23:16], num_cycles[31:24]};
    reg [`DATAMEM_BITS-1:0] last_addr_out;
    wire [`WORD_WIDTH-1:0] local_in = (last_addr_out == 'h7FC) ? num_cycles_little_e : lb_data_t;

    always@(posedge clk) begin
        if (!nrst) begin
            num_cycles <= `WORD_WIDTH'd0;
            last_addr_out <= 'd0;
        end
        else begin
            num_cycles <= num_cycles + `WORD_WIDTH'd1;
            if (dm_req)
                last_addr_out <= addr_out_t;
            else
                last_addr_out <= last_addr_out;
        end
    end
        
    storeblock STOREBLOCK(
		.opB(sb_opB),
		.byte_offset(sb_byte_offset),
		.store_select(sb_store_select),
		.is_stype(sb_is_stype),
		.load_in_mem(is_load),
		.data(sb_data_t),
		.dm_write(sb_dm_write_t)
	);
	
	loadblock LOADBLOCK(
		.data(local_in),
		.byte_offset(lb_byte_offset),
		.dm_select(lb_dm_select),
		.loaddata(lb_loaddata)
	);

    mem_protocol_driver MPH(
        .clk(clk),
        .nrst(nrst),
        
        .issue_op(is_mem_op), // && ~hold),
        .busy(dm_stall),
        .delay_store(store_sel),
        .ready(read_ready),
        .is_load(is_load),
        
        .issue_addr(addr_in),
        .addr_out(addr_out_t),
        
        .read_in(lb_data),
        .load_out(lb_data_t),
        
        .store_in(sb_data_t),
        .write_out(sb_data),

        .wren(sb_dm_write_t),
        .wren_out(sb_dm_write),

        .req(dm_req),
        .gnt(dm_gnt),
        .valid(dm_valid)
    );
endmodule
