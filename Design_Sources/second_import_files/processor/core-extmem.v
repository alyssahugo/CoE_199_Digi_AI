//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// core.v -- Pipelined RISCV Core
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author: Microlab 198 Pipelined RISC-V Group (2SAY1920)
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Module Name: core.v
// Description: This module contains the submodules needed to implement a
//				five-stage RISC-V processor.
//				Signal names:
//					+ if_XXXXX : IF stage, id_XXXXX : ID stage, etc.
//
// Revisions:
// Revision 0.01 - File Created
// Additional Comments:
// 
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

`timescale 1ns / 1ps

`include "constants.vh"
`include "config.vh"

module core_extmem (
	input clk,			// Input clock
	input nrst,

	// Interrupt signals
	`ifdef FEATURE_INTERRUPT_ENABLE
		input [`INT_SIG_WIDTH-1:0] int_sig,
	`endif 
	
	// Data Memory I/O
	//`ifdef FEATURE_BIT_ENABLE
		//output [31:0] ext_noncache_data_write,
	//`else
    output [3:0] ext_noncache_data_write,
    output [3:0] ext_cache_data_write,
	//`endif
	//`ifdef FEATURE_DMEM_BYTE_ADDRESS
        //output [`BUS_BITS-1:0] ext_noncache_data_addr,	
    //`else
    output [31:0] ext_noncache_data_addr,	
    output [`ADDR_BITS-1:0] ext_cache_data_addr,
    //`endif 
	
	//output ext_data_wr_en,
	output [`WORD_WIDTH-1:0] ext_noncache_data_store,	
	input [`WORD_WIDTH-1:0] ext_noncache_data_load,
	output ext_noncache_data_req,
	input ext_noncache_data_gnt,
	input ext_noncache_data_valid,
	input ext_noncache_data_write_valid,
	output ext_noncache_done,
	output ext_noncache_wr,
	output ext_noncache_rd,
	
    output [`WORD_WIDTH-1:0] ext_cache_data_store,	
	input [127:0] ext_cache_data_load, // NOT PARAMETRIZED
	output ext_cache_data_req,
	input ext_cache_data_gnt,
	output ext_cache_wr,
	output ext_cache_rd,
	input ext_cache_data_valid,
	input ext_cache_data_write_valid,
	output ext_cache_done,
	input [`TAG_BITS-1:0] ext_scu_tags,
	input [`INDEX_BITS-1:0] ext_scu_index,
	input ext_scu_invalidate,
	input ext_scu_reserve_exclusive,
	input ext_scu_to_shared,
	output [`ADDR_BITS-1:0] ext_scu_addr,
	output ext_scu_req,
	output ext_scu_wr,
	output ext_scu_hit,
	
	output [31:0] ext_probe_memALUout,
    output [31:0] ext_probe_datastore,
	
	// Debug Outputs
	`ifdef FEATURE_INST_TRACE_ENABLE
		output [`WORD_WIDTH-1:0] ext_if_inst,
		output [`WORD_WIDTH-1:0] ext_id_inst,
		output ext_trace_ready,
	`endif
	
	// Instruction Memory I/O
	output [`EXT_PC_ADDR_BITS-1:0] ext_inst_addr,
	input [`WORD_WIDTH-1:0] ext_inst_data
);

	`ifdef FEATURE_INTERRUPT_ENABLE
		// do nothing
	`else
		wire [`INT_SIG_WIDTH-1:0] int_sig = `INT_SIG_WIDTH'd0;
	`endif 

	`ifdef FEATURE_INST_TRACE_ENABLE
		// do nothing
	`else
		wire [`WORD_WIDTH-1:0] ext_if_inst;
		wire [`WORD_WIDTH-1:0] ext_id_inst;
	`endif

	assign ext_data_wr_en = |ext_noncache_data_write;

/******************************** DECLARING WIRES *******************************/

// IF stage ======================================================================
	reg [`PC_ADDR_BITS-1:0] if_pcnew;		// Input to PC; new PC address
	reg if_is_branch;                       // Determines if branch, used for instmem interface
	wire [`PC_ADDR_BITS-1:0] if_PC;			// Output of PC, input to INSTMEM
	wire [`PC_ADDR_BITS-1:0] if_pc4;		// PC + 4
	wire [`WORD_WIDTH-1:0] if_inst;			// INSTMEM Output
	assign ext_if_inst = if_inst;
	
	wire if_ready;                          // INSTMEM Output Ready
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// ID Stage ======================================================================
	// Outputs of IF/ID Pipeline Register
	wire [`PC_ADDR_BITS-1:0] id_pc4;		// PC + 4
	wire [`WORD_WIDTH-1:0] id_inst;			// 32bit Instruction
	assign ext_id_inst = id_inst;
	wire [`PC_ADDR_BITS-1:0] id_PC;			// PC

	// Other Datapath signals
	wire [`WORD_WIDTH-1:0] id_brOP;			// For computing branch target address
	//wire id_jump_in_bht;					// For jumps already in BHT
	
	// 32-bit instruction parts
	wire [6:0] id_opcode;					// opcode
	wire [2:0] id_funct3;					// funct3
	wire [6:0] id_funct7;					// funct7
	wire [`REGFILE_BITS-1:0] id_rsA; 		// source register B
	wire [`REGFILE_BITS-1:0] id_rsB;		// source register A
	wire [`REGFILE_BITS-1:0] id_rd;			// destination register
	assign id_funct3 = id_inst[14:12];
	assign id_funct7 = id_inst[31:25];

	// Control signals ///////////////////////////////////////////////////////////
	wire [3:0] id_ALU_op;								// For EXE stage 		//
	wire [3:0] id_atomic_op;
	wire id_div_valid;									// For EXE stage 		//
	wire [1:0] id_div_op;								// For EXE stage 		//
	wire id_sel_opA, id_sel_opB;						// For EXE stage 		//
	wire id_is_stype;									// For EXE stage 		//
	wire id_is_ltype;
	wire id_is_atomic;
	wire id_is_jump;									// For ID stage 		//
	wire id_is_btype;									// For ID Stage 		//
	wire id_is_nop; 									// For ID stage 		//
	wire id_wr_en;										// For WB stage 		//
	wire [2:0] id_dm_select;							// For MEM stage 		//
	wire [2:0] id_imm_select;							// For ID stage 		//
	wire id_sel_pc;										// For EXE stage 		//
	wire [2:0] id_sel_data;								// For WB stage 		//
	wire [1:0] id_store_select;							// For EXE stage 		//
	wire id_sel_opBR;									// For ID stage 		//
	//////////////////////////////////////////////////////////////////////////////

	// Inputs to ID/EXE Pipereg 														
	wire [`WORD_WIDTH-1:0] id_rfoutA, id_rfoutB;	// Regfile outputs 								
	wire [`WORD_WIDTH-1:0] id_imm;					// Output of SHIFT, SIGN EXT, AND SHUFFLE block

	wire [`WORD_WIDTH-1:0] id_branchtarget;			// Computed branch target

	wire [`WORD_WIDTH-1:0] id_fwdopA, id_fwdopB;	// Selected operands based on forwarded data
	wire [`WORD_WIDTH-1:0] id_fwdstore;				// Selected input to STOREBLOCK based on forwarded data
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// EXE Stage =====================================================================
	// Outputs of ID/EXE Pipeline Register
	wire [`PC_ADDR_BITS-1:0] exe_pc4;		// PC + 4
	wire [`WORD_WIDTH-1:0] exe_fwdopA;		// Selected opA in ID stage based on forwarded data
	wire [`WORD_WIDTH-1:0] exe_fwdopB;		// Selected opB in ID stage based on forwarded data
	wire [`WORD_WIDTH-1:0] exe_fwdstore;	// Selected input to STOREBLOCK based on forwarded data
	wire [`WORD_WIDTH-1:0] exe_imm;			// Immediate
	wire [`REGFILE_BITS-1:0] exe_rd;		// Destination register
	wire [`PC_ADDR_BITS-1:0] exe_PC;		// PC
	wire [`WORD_WIDTH-1:0] exe_branchtarget;// Computed branch target

	// Other wires used inside EXE stage
	wire [`WORD_WIDTH-1:0] opA;				// Input opA to ALU & Divider
	wire [`WORD_WIDTH-1:0] opB;				// Input opB to ALU & Divider
	wire [`WORD_WIDTH-1:0] exe_rstore;		// Input data to STOREBLOCK
	wire exe_div_running;					// (From Divider) Input to SF controller
	wire mul_stall;							// (From ALU) Input to SF controller

	wire [`REGFILE_BITS-1:0] exe_rsA;		// Source register A
	wire [`REGFILE_BITS-1:0] exe_rsB;		// Source register B

	wire exe_z;								// Output of ALU; used for evaluating Branches
	wire exe_less;							// Output of ALU; used for evaluating Branches
	wire exe_signed_less;					// Output of ALU; used for evaluating Branches
	wire [2:0] exe_funct3;					// Used for generating exe_btype
	wire [6:0] exe_opcode;					// Used for generating exe_btype
	wire [5:0] exe_btype;					// Determines what branch instruction is in EXE stage
	assign exe_btype[5] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h0)? 1'b1 : 1'b0) : 1'b0;	// BEQ
	assign exe_btype[4] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h1)? 1'b1 : 1'b0) : 1'b0;	// BNE
	assign exe_btype[3] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h4)? 1'b1 : 1'b0) : 1'b0;	// BLT
	assign exe_btype[2] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h5)? 1'b1 : 1'b0) : 1'b0;	// BGE
	assign exe_btype[1] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h6)? 1'b1 : 1'b0) : 1'b0;	// BLTU
	assign exe_btype[0] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h7)? 1'b1 : 1'b0) : 1'b0;	// BGEU

	// Control signals
	wire [3:0] exe_ALU_op;					// For EXE stage
	wire [3:0] exe_atomic_op;
	wire exe_div_valid;						// For EXE stage
	wire [1:0] exe_div_op;					// For EXE stage
	wire exe_is_stype;						// For EXE stage
	wire exe_is_ltype;
	wire exe_is_atomic;
	`ifdef FEATURE_BIT_ENABLE
        wire [31:0] exe_dm_write;				// For MEM stage
    `else
		wire [3:0] exe_dm_write;				// For MEM stage
    `endif
	wire exe_wr_en;							// For WB stage
	wire [2:0] exe_dm_select;				// For MEM stage
	wire [2:0] exe_sel_data;				// For WB stage
	wire [1:0] exe_store_select;			// For EXE stage
	wire exe_sel_opBR;						// For EXE stage
	wire exe_to_OCM;

	// Inputs to EXE/MEM Pipereg
	wire [`WORD_WIDTH-1:0] exe_ALUout;		// ALU output
	wire [`WORD_WIDTH-1:0] exe_DIVout;		// Divider output
	wire [`WORD_WIDTH-1:0] exe_storedata;	// Output of STORE BLOCK
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// MEM Stage =====================================================================
	// Outputs of EXE/MEM Pipeline Register
	wire [`PC_ADDR_BITS-1:0] mem_pc4;		// PC + 4
	wire [`WORD_WIDTH-1:0] mem_ALUout;		// ALU output
	wire [`WORD_WIDTH-1:0] mem_DIVout;		// Divider output
	wire [`WORD_WIDTH-1:0] mem_storedata;	// Input data to DATAMEM
	wire [`WORD_WIDTH-1:0] mem_imm;			// 32bit Immediate
	wire [`REGFILE_BITS-1:0]  mem_rd;		// Destination register
	wire [`WORD_WIDTH-1:0] mem_rstore;		// Input data to STOREBLOCK
	wire [1:0] mem_store_select;
	wire mem_active_op;
	wire mem_is_stype;
	wire mem_is_ltype;
	wire mem_is_atomic;
	wire [3:0] mem_atomic_op;
	//wire [`WORD_WIDTH-1:0] mem_OCMout;
	wire [31:0] mem_opB;

	// Control signals
	wire [3:0] mem_dm_write;				// For MEM stage
	wire mem_wr_en;							// For WB stage
	wire [2:0] mem_dm_select;				// For MEM stage
	wire [2:0] mem_sel_data;				// For WB stage

	// MEM Stage Datapath Signals
	wire[`WORD_WIDTH-1:0] mem_DATAMEMout;	// Output of DATAMEM
	wire [`WORD_WIDTH-1:0] sb_rstore;		// Input data to STOREBLOCK
	

	// Inputs to MEM/WB Pipereg
	wire [`WORD_WIDTH-1:0] mem_loaddata;	// Output of LOAD BLOCK
	
	wire mem_to_OCM;
	wire [`ADDR_BITS-1:0] mem_CACHE_addr;
	wire [3:0] mem_CACHE_dm_write;
	wire  mem_CACHE_rd;
	wire  mem_CACHE_wr;
	wire  [`WORD_WIDTH-1:0] mem_CACHE_in;
	wire [`WORD_WIDTH-1:0] mem_CACHEout;
	wire mem_CACHE_stall;
	wire mem_CACHE_ready;
	
	wire [31:0] mem_NONCACHE_addr;
	wire [3:0] mem_NONCACHE_dm_write;
	wire  mem_NONCACHE_rd;
	//wire  mem_NONCACHE_is_atomic;
	wire  mem_NONCACHE_wr;
	wire  [`WORD_WIDTH-1:0] mem_NONCACHE_in;
	wire [`WORD_WIDTH-1:0] mem_NONCACHEout;
	wire mem_NONCACHE_stall;
	wire mem_NONCACHE_ready;
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// WB Stage ======================================================================
	// Outputs of MEM/WB Pipeline Register
	wire [`PC_ADDR_BITS-1:0] wb_pc4;		// PC + 4
	wire [`WORD_WIDTH-1:0] wb_ALUout;		// ALU output
	wire [`WORD_WIDTH-1:0] wb_DIVout;		// Divider output
	wire [`WORD_WIDTH-1:0] wb_loaddata;		// Output of LOAD BLOCK
	wire [`WORD_WIDTH-1:0] wb_imm;			// 32bit Immediate
	wire [`REGFILE_BITS-1:0] wb_rd;			// Destination register

	// Control signals
	wire wb_wr_en;							// For WB stage
	wire [2:0] wb_sel_data;					// For WB stage

	// Datapath signals
	wire [`WORD_WIDTH-1:0] wb_wr_data;
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// Signals for BHT ===============================================================
	//wire if_prediction;						// Input to sel_PC mux
	wire [1:0] exe_correction;				// input to sel_PC mux
	//wire [`BHT_PC_ADDR_BITS-1:0] if_PBT;	// Predicted branch target
	wire [`BHT_PC_ADDR_BITS-1:0] exe_PBT;	// Predicted branch target
	wire [`BHT_PC_ADDR_BITS-1:0] exe_CNI;	// Correct Next Instruction
	wire branch_flush;						// Flushes IF/ID & ID/EXE
	wire jump_flush;						// Flushes IF/ID only
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// Data Forwarding Control Signals ===============================================
	wire fw_exe_to_id_A;
    wire fw_exe_to_id_B;
    wire fw_mem_to_id_A;
    wire fw_mem_to_id_B;
	wire fw_wb_to_id_A;
    wire fw_wb_to_id_B;
    wire fw_wb_to_exe_A;
    wire fw_wb_to_exe_B;
	wire fw_mem_to_exe_B;
	wire load_hazard;						// Asserts if a load hazard is detected
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// Clock Gating + SF_Controller ==================================================
	wire if_clk;			// CLK input to PC
	wire id_clk;			// CLK input to IF/ID pipereg
	wire exe_clk;			// CLK input to ID/EXE pipereg
	wire mem_clk;			// CLK input to EXE/MEM pipereg & DATAMEM
	wire wb_clk;			// CLK input to MEM/WB pipereg
	wire rf_clk;			// CLK input to Register file
	
	wire if_clk_en;
	wire id_clk_en;
	wire exe_clk_en;
	wire mem_clk_en;
	wire wb_clk_en;
	wire rf_clk_en;
	
	wire mem_dm_stall;          // Stall from load/store operation
	wire mem_dm_ready;			// Load state ready
	
	wire if_stall;			// Controls Interrupt Controller stall
	wire id_stall;			// Controls BHT stall & flush logic
	wire exe_stall;
	wire mem_stall;

	wire if_flush;			// Controls PC flush
	wire id_flush;			// Controls IF/ID flush
	wire exe_flush; 		// Controls ID/EXE flush
	wire mem_flush; 		// Controls EXE/MEM flush
	wire wb_flush; 			// Controls MEM/WB flush
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// ID 32-bit Instruction Signals =================================================
    wire [2:0] id_base_dm_select;
    wire [2:0] id_base_imm_select;
    wire [2:0] id_base_sel_data;
    wire [1:0] id_base_store_select;
    wire [3:0] id_base_ALU_op;
    wire id_base_sel_opA;
    wire id_base_sel_opB;
    wire id_base_is_stype;
    wire id_base_is_ltype;
    wire id_base_is_atomic;
    wire id_base_wr_en;
    wire [`REGFILE_BITS-1:0] id_base_rsA = id_inst[19:15];
    wire [`REGFILE_BITS-1:0] id_base_rsB = id_inst[24:20];
    wire [`REGFILE_BITS-1:0] id_base_rd = id_inst[11:7];
    wire [`WORD_WIDTH-1:0] id_base_imm;
	wire id_base_is_jump;
	wire id_base_is_btype;
	wire id_base_sel_pc;
	wire id_base_sel_opBR;
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





// Compressed Instructions =======================================================
    wire if_not_comp = (if_inst[1:0] == 2'd3);           // Compressed or not
    wire id_is_comp;
	wire exe_is_comp;
	
	// compressed control signals
    wire [2:0] id_c_dm_select;
    wire [2:0] id_c_imm_select;
    wire [2:0] id_c_sel_data;
    wire [1:0] id_c_store_select;
    wire [3:0] id_c_alu_op;
    wire id_c_sel_opA;
    wire id_c_sel_opB;
	wire id_c_sel_pc;
	wire id_c_sel_opBR;
    wire id_c_is_stype;
    wire id_c_is_ltype;
    wire id_c_wr_en;
	wire [1:0] id_c_btype;
	wire id_c_use_A;
	wire id_c_use_B;
	wire id_c_is_jump;
	wire id_c_is_btype;
	wire id_c_is_nop;
	wire [5:0] id_c_opcode;

	// registers and immediates
    wire [`REGFILE_BITS-1:0] id_c_rsA;
    wire [`REGFILE_BITS-1:0] id_c_rsB;
    wire [`REGFILE_BITS-1:0] id_c_rd;
    wire [`WORD_WIDTH-1:0] id_c_imm;
    wire [`WORD_WIDTH-1:0] id_c_jt;
    
	// signals for later stages
	wire exe_comp_use_A;
	wire exe_comp_use_B;
	wire [1:0] exe_c_btype;
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    




// Interrupt Controller Signals===================================================
	wire ISR_PC_flush;						// Flushes PC at ISR start sequence
	wire ISR_pipe_flush;					// Flushes IF/ID at ISR start/end sequence
	wire sel_ISR;							// selects ISRMEM
	wire ret_ISR;							// selects save_PC as input to PC
	wire ISR_running;						// asserted if the ISR is running
	wire [`PC_ADDR_BITS-1:0] save_PC;		// saves PC address of interrupted instruction
	
	wire eret_call;
// &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&



/*********************** DATAPATH (INSTANTIATING MODULES) ***********************/
// STALL, FLUSH, and FORWARDING Controller =======================================
	sf_controller SF_CONTROLLER(
		.clk(clk),
		.nrst(nrst),

		// Inputs from IF stage
		.if_pc(if_PC),
		.if_ready(if_ready),
		.if_pcnew(if_pcnew),

		// Inputs from ID stage
		.id_pc(id_PC),
		.is_jump(id_is_jump),
		.is_nop(id_is_nop),

		.ISR_PC_flush(ISR_PC_flush),
		.ISR_pipe_flush(ISR_pipe_flush),
		.branch_flush(branch_flush),
		.jump_flush(jump_flush),
		.mem_active_op(mem_active_op),
		.mul_stall(mul_stall),
		.div_running(exe_div_running),
		.dmem_stall(mem_dm_stall),
		.dmem_ready(mem_dm_ready),

		// Stall signals
		.if_stall(if_stall),
		.id_stall(id_stall),
		.exe_stall(exe_stall),
		.mem_stall(mem_stall),

		// Flushes/resets
		.if_flush(if_flush),
		.id_flush(id_flush),
		.exe_flush(exe_flush),
		.mem_flush(mem_flush),
		.wb_flush(wb_flush),

		// Clock enables
		.if_clk_en(if_clk_en),
		.id_clk_en(id_clk_en),
		.exe_clk_en(exe_clk_en),
		.mem_clk_en(mem_clk_en),
		.wb_clk_en(wb_clk_en),
		.rf_clk_en(rf_clk_en),

		// Forwarding Unit inputs and outputs
		// Source registers
		.id_rsA(id_rsA),
		.id_rsB(id_rsB),
		.exe_rsA(exe_rsA),
		.exe_rsB(exe_rsB),

		// Destination registers
		.exe_rd(exe_rd),
		.mem_rd(mem_rd),
		.wb_rd(wb_rd),

		// Control signals
		.exe_wr_en(exe_wr_en),
		.mem_wr_en(mem_wr_en),
		.wb_wr_en(wb_wr_en),

		.id_sel_opA(id_sel_opA),
		.id_sel_opB(id_sel_opB),

		.id_sel_data(id_sel_data),
		.exe_sel_data(exe_sel_data),
		.mem_sel_data(mem_sel_data),
		.wb_sel_data(wb_sel_data),

		.id_is_stype(id_is_stype),
		.id_is_btype(id_is_btype),

		.id_imm_select(id_imm_select),

		.exe_opcode(exe_opcode),
		.exe_comp_use_A(exe_comp_use_A),
		.exe_comp_use_B(exe_comp_use_B),
		.exe_is_comp(exe_is_comp),
		.id_sel_opBR(id_sel_opBR),
		.exe_sel_opBR(exe_sel_opBR),

		// Outputs
		.fw_exe_to_id_A(fw_exe_to_id_A),
		.fw_exe_to_id_B(fw_exe_to_id_B),
		.fw_mem_to_id_A(fw_mem_to_id_A),
		.fw_mem_to_id_B(fw_mem_to_id_B),
		.fw_wb_to_id_A(fw_wb_to_id_A),
		.fw_wb_to_id_B(fw_wb_to_id_B),

		.fw_wb_to_exe_A(fw_wb_to_exe_A),
		.fw_wb_to_exe_B(fw_wb_to_exe_B),
		.fw_mem_to_exe_B(fw_mem_to_exe_B),
		.load_hazard(load_hazard)
	);

// CLOCKS ========================================================
    
    `ifdef FEATURE_XILINX_BUFFER_IP
        BUFGCE 
        #(
           .SIM_DEVICE("7SERIES")
        )
        en_iF 
        (
            .I(clk),
            .CE(if_clk_en),
            .O(if_clk)
        );
    
        BUFGCE #(
           .SIM_DEVICE("7SERIES")
        ) en_id (
            .I(clk),
            .CE(id_clk_en),
            .O(id_clk)
        );
    
        BUFGCE #(
           .SIM_DEVICE("7SERIES")
        ) en_exe (
            .I(clk),
            .CE(exe_clk_en),
            .O(exe_clk)
        );
    
        BUFGCE #(
           .SIM_DEVICE("7SERIES")
        ) en_mem (
            .I(clk),
            .CE(mem_clk_en),
            .O(mem_clk)
        );
    
        BUFGCE #(
           .SIM_DEVICE("7SERIES")
        ) en_wb (
            .I(clk),
            .CE(wb_clk_en),
            .O(wb_clk)
        );
    
        BUFGCE #(
           .SIM_DEVICE("7SERIES")
        ) en_rf(
            .I(clk),
            .CE(rf_clk_en),
            .O(rf_clk)
        );
	`else
        assign if_clk = clk;
        assign id_clk = clk;
        assign exe_clk = clk;
        assign mem_clk = clk;
        assign wb_clk = clk;
        assign rf_clk = clk;
    `endif


// IF Stage ======================================================================
    
	instmem_interface_slow IM_I (
        .clk(clk),
        .nrst(nrst),

		.if_stall(if_stall),
        .if_flush(if_flush),
		.id_stall(id_stall && ~id_flush),
		.id_flush(id_flush),
    
        .if_pc_out(if_PC),
    	.id_pc_out(id_PC),
		.if_pc4(if_pc4),
		.id_pc4(id_pc4),
        .if_pcnew(if_pcnew),

        .enter_branch(if_is_branch),
		.correction(exe_correction[1]),
		.jump(id_is_jump),
		//.jump_in_bht(id_jump_in_bht),
        .enter_interrupt(1'b0),		
    	
    	.if_inst(if_inst),
		.id_inst(id_inst),

        .ready(if_ready),
		.trace_ready(ext_trace_ready),
        
        .inst_data(ext_inst_data),
        .inst_addr(ext_inst_addr)
    );

	interrupt_controller INT_CON(
		.clk(clk),
		.nrst(nrst),
		.stall(if_stall),

		.if_pcnew(if_pcnew),
		.if_PC(if_PC),
		.exe_opcode(exe_opcode),
		.int_sig(int_sig),

		//.if_prediction(if_prediction),
		.exe_correction(exe_correction),
		//.id_jump_in_bht(id_jump_in_bht),
		.id_sel_pc(id_sel_pc),

		.ISR_PC_flush(ISR_PC_flush),
		.ISR_pipe_flush(ISR_pipe_flush),
		.sel_ISR(sel_ISR),
		.ret_ISR(ret_ISR),

		.ISR_running(ISR_running),
		.save_PC(save_PC),
		.eret_call(eret_call)
	);

	// PC + 4
	assign if_pc4 = if_PC + (if_not_comp ? 12'd4 : 12'd2); // buff_stall ? if_PC : if_PC + 12'd4;

	// PC Selection
	// Check for exe_correction, then jumps in ID stage, then check if_prediction last
	// This is so when a branch/jump in the EXE or ID stage has to flush earlier stages,
	// branches/jumps in the IF stage that are predicted to take the branch target won't get
	// executed since they're supposed to be flushed anyway.
	always@(*) begin
		if(ret_ISR)
			if_pcnew = save_PC;
		else begin
			case(exe_correction)
				2'b10: if_pcnew = {exe_CNI, 1'h0};
				2'b11: if_pcnew = {exe_PBT, 1'h0};
				default: begin
					case(id_sel_pc)
						1'b1: if_pcnew = id_branchtarget;
						default: if_pcnew = if_pc4;
					endcase
				end
			endcase
		end
	end

	/*
	pipereg_if_id IF_ID(
		.clk(id_clk),
		.nrst(nrst),

		.flush(id_flush),
		.stall(if_stall),

		.if_pc4(if_pc4), 	.id_pc4(id_pc4),
		.if_inst(if_inst), 	.id_inst(id_inst),
		.if_PC(if_PC), 		.id_PC(id_PC)
	);
	*/


// ID Stage ======================================================================
	// Selecting operands
	// id_fwdopA is passed through ID/EXE pipeline register to the ALU
	assign id_fwdopA = fw_exe_to_id_A?
							(exe_sel_data == 3'd4)? exe_DIVout		:
							(exe_sel_data == 3'd2)? exe_imm			: 
							(exe_sel_data == 3'd1)? exe_ALUout		:
													exe_pc4			:												 
					   fw_mem_to_id_A?
					   		(mem_sel_data == 3'd4)? mem_DIVout		:
					   		(mem_sel_data == 3'd3)? mem_loaddata	:
					   		(mem_sel_data == 3'd2)? mem_imm			:
					   		(mem_sel_data == 3'd1)? mem_ALUout		:
					   								mem_pc4			:
					   fw_wb_to_id_A?
					   		wb_wr_data								:
					   id_sel_opA?
					   		id_rfoutA : id_PC;
							   
	// id_fwdopB is passed through ID/EXE pipeline register to the ALU
	assign id_fwdopB = (fw_exe_to_id_B && !id_is_stype)?
							(exe_sel_data == 3'd4)? exe_DIVout		:             
							(exe_sel_data == 3'd2)? exe_imm			: 
							(exe_sel_data == 3'd1)? exe_ALUout 		:
													exe_pc4			:
					   (fw_mem_to_id_B && !id_is_stype)?
					   		(mem_sel_data == 3'd4)? mem_DIVout		:
					   		(mem_sel_data == 3'd3)? mem_loaddata	:
					   		(mem_sel_data == 3'd2)? mem_imm			:
					   		(mem_sel_data == 3'd1)? mem_ALUout		:
					   								mem_pc4			:
					   (fw_wb_to_id_B && !id_is_stype)?
					   		wb_wr_data								:                 
                    	id_sel_opB?
	                    	id_imm : id_rfoutB;
	
	// id_fwdstore is passed through ID/EXE pipeline register & is sent to STOREBLOCK
	assign id_fwdstore = (fw_exe_to_id_B && id_is_stype)?
							(exe_sel_data == 3'd4)? exe_DIVout		:
							(exe_sel_data == 3'd2)? exe_imm			: 
							(exe_sel_data == 3'd1)? exe_ALUout 		:
													exe_pc4			:
						 (fw_mem_to_id_B && id_is_stype)?
						 	(mem_sel_data == 3'd4)? mem_DIVout 		:
						 	(mem_sel_data == 3'd3)? mem_loaddata	:
						 	(mem_sel_data == 3'd2)? mem_imm			:
						 	(mem_sel_data == 3'd1)? mem_ALUout		:
						 							mem_pc4			:
						 (fw_wb_to_id_B && id_is_stype)?
						 	wb_wr_data : id_rfoutB;
	
	// Control Unit
	controller1 CONTROL(
		// Inputs
		.opcode(id_opcode),
		.funct3(id_funct3),
		.funct7(id_funct7),

		// Outputs
		.ALU_op(id_base_ALU_op),
		.atomic_op(id_atomic_op),
		.div_valid(id_div_valid),
		.div_op(id_div_op),
		.sel_opA(id_base_sel_opA),
		.sel_opB(id_base_sel_opB),
		.is_stype(id_base_is_stype),
        .is_ltype(id_base_is_ltype),
        .is_atomic(id_base_is_atomic),

		.is_jump(id_base_is_jump),
		
		.is_btype(id_base_is_btype),

		.wr_en(id_base_wr_en),
		.dm_select(id_base_dm_select),
		.imm_select(id_base_imm_select),
		.sel_pc(id_base_sel_pc),
		.sel_data(id_base_sel_data),
		.store_select(id_base_store_select),
		.sel_opBR(id_base_sel_opBR)
	);

	regfile RF(
		.clk(rf_clk),
		.nrst(nrst),

		.wr_en(wb_wr_en),
		.wr_data(wb_wr_data),
		.dest_addr(wb_rd),

		.src1_addr(id_rsA),		.src2_addr(id_rsB),
		.src1_out(id_rfoutA),	.src2_out(id_rfoutB)
	);

	shiftsignshuff SHIFTSIGNSHUFF(
		.imm_select(id_base_imm_select),
		.inst(id_inst[31:7]),
		.imm(id_base_imm)
	);

	// Branch target address computation
	// id_brOP = rfoutA for JALR only
	assign id_brOP = (id_sel_opBR) ? id_fwdopA : id_PC;
	assign id_branchtarget = id_brOP + (id_is_comp ? (id_sel_opBR ? 32'd0: id_c_jt) : id_base_imm);

    compressed_decoder C_DECODER (
        // Input
        .inst(id_inst[15:0]),
        
        // Type indicator (output)
        .is_compressed(id_is_comp),
        
        // Control signals (output)
        .dm_select(id_c_dm_select),
        .imm_select(id_c_imm_select),
        .sel_data(id_c_sel_data),
        .store_select(id_c_store_select),
        .alu_op(id_c_alu_op),
        .sel_opA(id_c_sel_opA),
        .sel_opB(id_c_sel_opB),
		.sel_opBR(id_c_sel_opBR),
		.sel_pc(id_c_sel_pc),
        .is_stype(id_c_is_stype),
        .is_ltype(id_c_is_ltype),
        .wr_en(id_c_wr_en),
		.btype(id_c_btype),
		.use_A(id_c_use_A),
		.use_B(id_c_use_B),
		.is_jump(id_c_is_jump),
		.is_btype(id_c_is_btype),
		.is_nop(id_c_is_nop),
		.base_opcode(id_c_opcode),
        
        // Results (output)
        .rs1(id_c_rsA),
        .rs2(id_c_rsB),
        .rd(id_c_rd),
        .imm(id_c_imm),
        .jt(id_c_jt)
    );
    
	// Assigning control signals based on whether the decoded instruction is compressed
    assign id_dm_select = id_is_comp ? id_c_dm_select : id_base_dm_select; 
    assign id_sel_data = id_is_comp ? id_c_sel_data : id_base_sel_data;
    assign id_store_select = id_is_comp ? id_c_store_select : id_base_store_select;
    assign id_ALU_op = id_is_comp ? id_c_alu_op : id_base_ALU_op;
    assign id_is_stype = id_is_comp ? id_c_is_stype : id_base_is_stype;
    assign id_is_ltype = id_is_comp ? id_c_is_ltype : id_base_is_ltype;
    assign id_is_atomic = id_is_comp ? 0 : id_base_is_atomic;
    assign id_wr_en = id_is_comp ? id_c_wr_en : id_base_wr_en;
    assign id_imm = id_is_comp ? id_c_imm : id_base_imm;
    assign id_rd = id_is_comp ? id_c_rd : id_base_rd;
    assign id_rsA = id_is_comp ? id_c_rsA: id_base_rsA;
    assign id_rsB = id_is_comp ? id_c_rsB : id_base_rsB;
    assign id_sel_opA = id_is_comp ? id_c_sel_opA : id_base_sel_opA;
    assign id_sel_opB = id_is_comp ? id_c_sel_opB : id_base_sel_opB;
	assign id_sel_opBR = id_is_comp ? id_c_sel_opBR : id_base_sel_opBR;
	assign id_sel_pc = id_is_comp ? id_c_sel_pc : id_base_sel_pc;
	assign id_is_jump = id_is_comp ? id_c_is_jump : id_base_is_jump;
	assign id_is_btype = id_is_comp ? id_c_is_btype : id_base_is_btype;
	assign id_imm_select = id_is_comp ? id_c_imm_select : id_base_imm_select;
	assign id_is_nop = id_is_comp ? id_c_is_nop : (id_inst == 32'h13);
	assign id_opcode = id_is_comp ? id_c_opcode : id_inst[6:0];
	// ================================================================================
    
	pipereg_id_exe ID_EXE(
		.clk(exe_clk),
		.nrst(nrst),

        .stall(id_stall),
		.flush(exe_flush),

		.id_pc4(id_pc4),					.exe_pc4(exe_pc4),
		.id_fwdopA(id_fwdopA),				.exe_fwdopA(exe_fwdopA),
		.id_fwdopB(id_fwdopB),				.exe_fwdopB(exe_fwdopB),

		.id_opcode(id_opcode),				.exe_opcode(exe_opcode),
		.id_funct3(id_funct3),				.exe_funct3(exe_funct3),
		.id_branchtarget(id_branchtarget),	.exe_branchtarget(exe_branchtarget),

		.id_fwdstore(id_fwdstore),			.exe_fwdstore(exe_fwdstore),
		
		.id_imm(id_imm),					.exe_imm(exe_imm),
		.id_rd(id_rd),						.exe_rd(exe_rd),
		.id_PC(id_PC),						.exe_PC(exe_PC),

		// Control signals go here
		.id_ALU_op(id_ALU_op),				.exe_ALU_op(exe_ALU_op),
		.id_atomic_op(id_atomic_op),        .exe_atomic_op(exe_atomic_op),
		.id_c_btype(id_c_btype),			.exe_c_btype(exe_c_btype),
		.id_sel_opBR(id_sel_opBR),			.exe_sel_opBR(exe_sel_opBR),
		.id_div_valid(id_div_valid),		.exe_div_valid(exe_div_valid),
		.id_div_op(id_div_op),				.exe_div_op(exe_div_op),
		.id_is_stype(id_is_stype),			.exe_is_stype(exe_is_stype),
		.id_is_ltype(id_is_ltype),          .exe_is_ltype(exe_is_ltype),
		.id_is_atomic(id_is_atomic),        .exe_is_atomic(exe_is_atomic),
		.id_wr_en(id_wr_en),				.exe_wr_en(exe_wr_en),
		.id_dm_select(id_dm_select),		.exe_dm_select(exe_dm_select),
		.id_sel_data(id_sel_data),			.exe_sel_data(exe_sel_data),
		.id_store_select(id_store_select), 	.exe_store_select(exe_store_select),
		.id_comp_use_A(id_c_use_A),			.exe_comp_use_A(exe_comp_use_A),
		.id_comp_use_B(id_c_use_B),			.exe_comp_use_B(exe_comp_use_B),
		.id_is_comp(id_is_comp),			.exe_is_comp(exe_is_comp),
		.id_rs1(id_rsA),					.exe_rs1(exe_rsA),
		.id_rs2(id_rsB),					.exe_rs2(exe_rsB)
	);



// EXE Stage =====================================================================
	// Selecting operands
	assign opA = fw_wb_to_exe_A? wb_loaddata : exe_fwdopA;
	assign opB = (fw_wb_to_exe_B && !exe_is_stype) ? wb_loaddata : exe_fwdopB;

	assign exe_rstore = fw_mem_to_exe_B ? mem_loaddata : fw_wb_to_exe_B ? wb_loaddata : exe_fwdstore;

	alu ALU(
		.CLK(clk),
		.nrst(nrst),
		.load_hazard(load_hazard),

		.op_a(opA),
		.op_b(opB),
		.ALU_op(exe_ALU_op),

		.res(exe_ALUout),
		.mul_stall(mul_stall),
		.z(exe_z),
		.less(exe_less),
		.signed_less(exe_signed_less)
	);
    
    `ifdef FEATURE_DIV
	divider_unit DIVIDER(
		.CLK(clk),
		.nrst(nrst),
		.load_hazard(load_hazard),

		.opA(opA),
		.opB(opB),

		.id_div_valid(id_div_valid),
		.id_div_op_0(id_div_op[0]),
		.exe_div_valid(exe_div_valid),
		.exe_div_op(exe_div_op),

		.div_running(exe_div_running),
		.DIVout(exe_DIVout)
	);
	`else
	assign exe_DIVout = 0;
	assign exe_div_running = 0;
	`endif
	

	branchpredictor BRANCHPREDICTOR(
		.CLK(clk),
		.nrst(nrst),

		.ISR_running(ISR_running),

		.stall(id_stall),
		.hold(if_stall),

		.if_PC(if_PC[`PC_ADDR_BITS-1:1]),

		.id_PC(id_PC[`PC_ADDR_BITS-1:1]),
		.id_branchtarget(id_branchtarget[`PC_ADDR_BITS-1:1]),
		.id_is_jump(id_is_jump),
		.id_is_btype(id_is_btype),

		.exe_PC(exe_PC[`PC_ADDR_BITS-1:1]),
		.exe_branchtarget(exe_branchtarget[`PC_ADDR_BITS-1:1]),
		.exe_sel_opBR(exe_sel_opBR),
		.exe_z(exe_z),
		.exe_less(exe_less),
		.exe_signed_less(exe_signed_less),
		.exe_btype(exe_btype),
		.exe_c_btype(exe_c_btype),
		
		// Outputs
		//.if_prediction(if_prediction),
		.exe_correction(exe_correction),
		
		.branch_flush(branch_flush),
		.jump_flush(jump_flush),
		//.id_jump_in_bht(id_jump_in_bht),

		//.if_PBT(if_PBT),
		.exe_PBT(exe_PBT),
		.exe_CNI(exe_CNI)
	);
	
    storeblock STOREBLOCK(
		.opB(exe_rstore),
		.byte_offset(exe_ALUout[1:0]),
		.store_select(exe_store_select),
		.is_stype(exe_is_stype),
		.load_in_mem(exe_is_ltype),
		.data(exe_storedata),
		.dm_write(exe_dm_write)
	);
	
	
	pipereg_exe_mem EXE_MEM(
		.clk(mem_clk),
		.nrst(nrst),

        .stall(exe_stall),
		.flush(mem_flush),

		.exe_pc4(exe_pc4),					.mem_pc4(mem_pc4),
		.exe_ALUout(exe_ALUout),			.mem_ALUout(mem_ALUout),
		.exe_DIVout(exe_DIVout),			.mem_DIVout(mem_DIVout),
		.exe_storedata(exe_storedata),		.mem_storedata(mem_storedata), // huh
		.exe_imm(exe_imm),					.mem_imm(mem_imm),
		.exe_rd(exe_rd),					.mem_rd(mem_rd),
		.exe_rstore(exe_rstore),			.mem_rstore(mem_rstore),
		.exe_is_stype(exe_is_stype),		.mem_is_stype(mem_is_stype),
		.exe_is_ltype(exe_is_ltype),        .mem_is_ltype(mem_is_ltype),
		.exe_store_select(exe_store_select),	.mem_store_select(mem_store_select),

		// Control signals
		.exe_dm_write(exe_dm_write),		.mem_dm_write(mem_dm_write),
		.exe_wr_en(exe_wr_en),				.mem_wr_en(mem_wr_en),
		.exe_dm_select(exe_dm_select),		.mem_dm_select(mem_dm_select),
		.exe_sel_data(exe_sel_data),		.mem_sel_data(mem_sel_data),
		.exe_is_atomic(exe_is_atomic),      .mem_is_atomic(mem_is_atomic),
		.exe_atomic_op(exe_atomic_op),      .mem_atomic_op(mem_atomic_op),
		.exe_opB(opB),                      .mem_opB(mem_opB)
		//.exe_to_OCM(exe_to_OCM),            //.mem_to_OCM(mem_to_OCM)
	);



// MEM Stage =====================================================================
	// probes 
	assign ext_probe_memALUout = mem_ALUout;
	assign ext_probe_datastore = ext_noncache_data_store;
	
	assign mem_active_op = mem_is_atomic || mem_is_stype || mem_is_ltype;
    // Reroute if direct to RAM or to CACHE
    MEM_ADDR_ROUTE 
        MEM_ADDR_ROUTE (
            .i_addr(mem_ALUout),
            .i_data(mem_storedata),
            .i_is_atomic(mem_is_atomic),
            .i_dm_write(mem_dm_write),
            .i_wr(mem_is_stype),
            .i_rd(mem_is_ltype),
            
            .o_addr_to_cache(mem_CACHE_addr),
            .o_dm_write_to_cache(mem_CACHE_dm_write),
            .o_wr_to_cache(mem_CACHE_wr),
            .o_rd_to_cache(mem_CACHE_rd),
            .o_data_to_cache(mem_CACHE_in),
            
            .o_addr_to_OCM(mem_NONCACHE_addr),
            .o_dm_write_to_OCM(mem_NONCACHE_dm_write),
            .o_wr_to_OCM(mem_NONCACHE_wr),
            .o_rd_to_OCM(mem_NONCACHE_rd),
            .o_data_to_OCM(mem_NONCACHE_in),
            
            .o_to_OCM(mem_to_OCM)
        );
    
    // Put the STOREBLOCK and LOADBLOCK outside the Datamem interface
    
    // The atomic module also serves as the OCM interface
    
    ATOMIC_MODULE#(.ADDR_BITS(`DATAMEM_BITS))
        ATOMIC_ALU(
            .clk(mem_clk), .nrst(nrst), // oh n
            .i_wr(mem_NONCACHE_wr), 
            .i_rd(mem_NONCACHE_rd),
            .i_is_atomic(mem_is_atomic), // force no atomics muna
            .i_data_from_core(mem_NONCACHE_in),
            .i_data_from_OCM(ext_noncache_data_load),
            .i_addr(mem_NONCACHE_addr),
            .i_dm_write(mem_NONCACHE_dm_write),
            .i_atomic_op(mem_atomic_op),
            .i_opB(mem_opB),
            .i_grant(ext_noncache_data_gnt),
            .i_data_valid(ext_noncache_data_valid),
            .i_data_write_valid(ext_noncache_data_write_valid),
            
            .o_data_to_OCM(ext_noncache_data_store),
            .o_addr(ext_noncache_data_addr),
            .o_dm_write(ext_noncache_data_write),
            .o_data_to_WB(mem_NONCACHEout),
            .o_request(ext_noncache_data_req),
            .o_done(ext_noncache_done),
            .o_stall_atomic(mem_NONCACHE_stall),
            .o_ready(mem_NONCACHE_ready),
            .o_wr(ext_noncache_wr),
            .o_rd(ext_noncache_rd)
            
        );
	
	///////////////////// L1 cache
	L1_cache_top // small cache to check refills and eviction
	   L1_CACHE (
	       .clk(~mem_clk),  .nrst(nrst),
	       .i_dm_write(mem_CACHE_dm_write),
	       .i_rd(mem_CACHE_rd),
	       .i_wr(mem_CACHE_wr),
	       .i_data_addr(mem_CACHE_addr),
	       .i_data(mem_CACHE_in),
	       
	       .i_data_block_from_L2(ext_cache_data_load),
	       .i_grant(ext_cache_data_gnt),
	       .i_data_valid(ext_cache_data_valid),
	       .i_data_wvalid(ext_cache_data_write_valid),
	       
	       .o_data(mem_CACHEout),
	       .o_all_done(mem_CACHE_ready),
	       
	       // to L2
	       .o_dm_write(ext_cache_data_write),
	       //.o_wr(ext_cache_wr),
	       //.o_rd(ext_cache_rd),
	       .o_req_block(ext_cache_data_req), // read
	       .o_req_wr(ext_cache_wr),
	       .o_wrdata_to_L2(ext_cache_data_store),
	       .o_addr(ext_cache_data_addr),
	       
	       // Snooping
	       .i_ext_tags(ext_scu_tags),
           .i_ext_index(ext_scu_index),
           .i_ext_invalidate(ext_scu_invalidate),
           .i_ext_reserve_exclusive(ext_scu_reserve_exclusive),
           .i_ext_to_shared(ext_scu_to_shared),
	       .o_ext_addr(ext_scu_addr),
           .o_scu_req(ext_scu_req),
           .o_scu_wr(ext_scu_wr),
           .o_scu_hit(ext_scu_hit),
	       .o_stall(mem_CACHE_stall)
	       
	       
	   );
	
    assign mem_DATAMEMout = (mem_to_OCM) ?   mem_NONCACHEout : mem_CACHEout;
    assign mem_dm_ready = (mem_CACHE_ready || mem_NONCACHE_ready);
    assign mem_dm_stall = (mem_CACHE_stall || mem_NONCACHE_stall);
    assign ext_cache_done = mem_CACHE_ready;
	loadblock LOADBLOCK(
		.data(mem_DATAMEMout),
		.byte_offset(mem_ALUout[1:0]),
		.dm_select(mem_dm_select),
		.loaddata(mem_loaddata)
	);
	
    /*
    wire mem_dm_en;
    `ifdef FEATURE_DMEM_BYTE_ADDRESS
        wire [`BUS_BITS-1:0] mem_dm_addr;
    `else
        wire [`DATAMEM_BITS-1:0] mem_dm_addr;
	`endif
	wire mem_sel_store;
	wire sb_is_stype;
    
	assign ext_noncache_data_write = exe_dm_write;
	assign ext_noncache_data_addr = mem_dm_addr;	
	assign ext_noncache_data_store = exe_storedata;	
	assign mem_DATAMEMout = ext_noncache_data_load;
	assign ext_noncache_data_req = mem_dm_en;

	assign sb_rstore = mem_sel_store ? mem_rstore : exe_rstore;
	wire [1:0] sb_store_select = mem_sel_store ? mem_store_select : exe_store_select;
	wire [1:0] sb_byte_offset = mem_sel_store ? mem_ALUout[1:0] : exe_ALUout[1:0];
	assign sb_is_stype = mem_sel_store ? mem_is_stype : exe_is_stype;
	
	datamem_interface DM_I(
	     .clk(clk),
	     .nrst(nrst),
	     .sel_data(mem_sel_data),
	     .mem_flush(mem_flush),
	     
	     .exe_addr_in(exe_ALUout[`DATAMEM_BITS+1:2]),
	     .mem_addr_in(mem_ALUout[`DATAMEM_BITS+1:2]),
	     .addr_out(mem_dm_addr),
	     
	     .sb_opB(sb_rstore),
         .sb_byte_offset(sb_byte_offset),
         .sb_store_select(sb_store_select),
         .sb_is_stype(sb_is_stype),
         .sb_data(exe_storedata),
         .sb_dm_write(exe_dm_write),
         
         .lb_data(mem_DATAMEMout),    
         .lb_byte_offset(mem_ALUout[1:0]),    
         .lb_dm_select(mem_dm_select),    
         .lb_loaddata(mem_loaddata),
         
         .dm_req(mem_dm_en),
         .dm_gnt(ext_noncache_data_gnt),
         .dm_valid(ext_noncache_data_valid),
         
         .dm_stall(mem_dm_stall),
		 .store_sel(mem_sel_store),
         .mem_rd(mem_rd),
         .read_ready(mem_dm_ready)
	);
    */
	pipereg_mem_wb MEM_WB(
		.clk(wb_clk),
		.nrst(nrst),

        .stall(mem_stall),
		.flush(wb_flush),

		.mem_pc4(mem_pc4),					.wb_pc4(wb_pc4),
		.mem_ALUout(mem_ALUout),			.wb_ALUout(wb_ALUout),
		.mem_DIVout(mem_DIVout),			.wb_DIVout(wb_DIVout),
		.mem_loaddata(mem_loaddata),		.wb_loaddata(wb_loaddata),
		.mem_imm(mem_imm),					.wb_imm(wb_imm),
		.mem_rd(mem_rd),					.wb_rd(wb_rd),

		// Control signals
		.mem_wr_en(mem_wr_en),				.wb_wr_en(wb_wr_en),
		.mem_sel_data(mem_sel_data),		.wb_sel_data(wb_sel_data)
	);



// WB Stage ======================================================================
	// Selector MUX
	assign wb_wr_data = (wb_sel_data == 3'd0) ? wb_pc4 : 
						(wb_sel_data == 3'd1) ? wb_ALUout : 
						(wb_sel_data == 3'd2) ? wb_imm :
						(wb_sel_data == 3'd4) ? wb_DIVout :
						wb_loaddata;
endmodule
