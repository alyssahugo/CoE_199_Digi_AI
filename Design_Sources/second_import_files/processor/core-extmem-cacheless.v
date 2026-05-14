`timescale 1ns / 1ps

`include "constants.vh"
`include "config.vh"

module core_extmem_cacheless (
    input clk,
    input nrst,

    // Interrupt signals
    `ifdef FEATURE_INTERRUPT_ENABLE
        input [`INT_SIG_WIDTH-1:0] int_sig,
    `endif

    // Data Memory I/O
    output [3:0] ext_noncache_data_write,
    output [31:0] ext_noncache_data_addr,
    output [`WORD_WIDTH-1:0] ext_noncache_data_store,
    input  [`WORD_WIDTH-1:0] ext_noncache_data_load,
    output ext_noncache_data_req,
    input  ext_noncache_data_gnt,
    input  ext_noncache_data_valid,
    input  ext_noncache_data_write_valid,
    output ext_noncache_done,
    output ext_noncache_wr,
    output ext_noncache_rd,

    // Debug / Trace Outputs
    `ifdef FEATURE_INST_TRACE_ENABLE
        output [`WORD_WIDTH-1:0] ext_if_inst,
        output [`WORD_WIDTH-1:0] ext_id_inst,
        output ext_trace_ready,
    `endif
    output [31:0] ext_probe_memALUout,
    output [31:0] ext_probe_datastore,

    // Existing probe ports
    output [16:0] ext_probe_if_pc,
    output [17-1:0] ext_probe_id_pc,
    output [17-1:0] ext_probe_if_pcnew,
    output [17-1:0] ext_probe_exe_pc,
    output                      ext_probe_if_ready,
    output                      ext_probe_if_stall,
    output                      ext_probe_id_stall,
    output                      ext_probe_if_flush,
    output                      ext_probe_id_flush,
    output                      ext_probe_jump,
    output                      ext_probe_enter_branch,
    output [1:0]                ext_probe_correction,

    // Added remaining probe ports
    output [`WORD_WIDTH-1:0]    ext_probe_id_branchtarget,
    output [`WORD_WIDTH-1:0]    ext_probe_exe_branchtarget,
    output [17-1:0] ext_probe_exe_PBT,
    output [17-1:0] ext_probe_exe_CNI,
    output [17-1:0]  ext_probe_save_PC,
    output                      ext_probe_id_sel_pc,
    output                      ext_probe_ret_ISR,
    output                      ext_probe_branch_flush,
    output                      ext_probe_jump_flush,

    // Instruction Memory I/O
    output [`EXT_PC_ADDR_BITS-1:0] ext_inst_addr,
    input [`WORD_WIDTH-1:0] ext_inst_data,
    
    
    output [31:0] ext_probe_id_rfoutA,        // Probe for register file output for `a5` (id_rfoutA)
    output [31:0] ext_probe_id_fwdopA,        // Probe for the forwarded value for `a5` (id_fwdopA)
    output ext_probe_id_sel_opA,              // Probe for id_sel_opA signal
    output [31:0] ext_probe_id_base_imm,      // Probe for id_base_imm signal (immediate for `jalr`)
    output ext_probe_id_sel_opBR,             // Probe for id_sel_opBR (for `jalr`)
    output ext_probe_id_is_jump,              // Probe for id_is_jump signal (should be 1 for `jalr`)
    output ext_probe_exe_is_jump,             // Probe for exe_is_jump signal (should be 1 for `jalr`)
    output [31:0] ext_probe_exe_target,       // Probe for the calculated final target in EXE stage
    output ext_probe_if_pcnew_1,               // Probe for the updated PC (`if_pcnew`)
//////////////////////////////////////////////////////////////////
    output [31:0] ext_probe_mem_loaddata,
    output [31:0] ext_probe_wb_loaddata,
    output [31:0] ext_probe_mem_datamemout,
    output [31:0] ext_probe_ext_noncache_data_load,
    output        ext_probe_ext_noncache_data_valid,
    output        ext_probe_ext_noncache_data_gnt,
    output [31:0] ext_probe_wb_wr_data,
    output [`REGFILE_BITS-1:0] ext_probe_wb_rd,
    output        ext_probe_wb_wr_en,
    output        ext_probe_load_hazard,
    output        ext_probe_exe_stall,
    output        ext_probe_mem_stall,
    output        ext_probe_exe_flush,
    output        ext_probe_mem_flush,
    output        ext_probe_wb_flush,
    output        ext_probe_fw_mem_to_id_A,
    output        ext_probe_fw_wb_to_id_A,
    output        ext_probe_fw_wb_to_exe_A,
    output        ext_probe_mem_is_ltype,
    output        ext_probe_mem_is_stype,
    output [2:0]  ext_probe_mem_dm_select,
    output [2:0]  ext_probe_mem_sel_data,
    output [31:0] ext_probe_atomic_temp_t,
    output [31:0] ext_probe_atomic_data_from_ocm,
    output        ext_probe_atomic_data_valid,
    output [3:0]  ext_probe_atomic_state,
    output [31:0] ext_probe_atomic_data_to_wb
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
        wire ext_trace_ready;
    `endif

    /******************************** DECLARING WIRES *******************************/

    // IF stage ======================================================================
    reg [17-1:0] if_pcnew;
    reg if_is_branch;
    wire [17-1:0] if_PC;
    wire [17-1:0] if_pc4;
    wire [`WORD_WIDTH-1:0] if_inst;
    wire if_ready;

    assign ext_if_inst         = if_inst;
    assign ext_probe_if_pc     = if_PC;
    assign ext_probe_if_pcnew  = if_pcnew;
    assign ext_probe_if_ready  = if_ready;

// ID Stage ======================================================================
    wire [17-1:0] id_pc4;
    wire [`WORD_WIDTH-1:0] id_inst;
    assign ext_id_inst = id_inst;
    wire [17:0] id_PC;
    assign ext_probe_id_pc = id_PC;





    wire [`WORD_WIDTH-1:0] id_brOP;

    wire [6:0] id_opcode;
    wire [2:0] id_funct3;
    wire [6:0] id_funct7;
    wire [`REGFILE_BITS-1:0] id_rsA;
    wire [`REGFILE_BITS-1:0] id_rsB;
    wire [`REGFILE_BITS-1:0] id_rd;
    assign id_funct3 = id_inst[14:12];
    assign id_funct7 = id_inst[31:25];

    wire [3:0] id_ALU_op;
    wire [3:0] id_atomic_op;
    wire id_div_valid;
    wire [1:0] id_div_op;
    wire id_sel_opA, id_sel_opB;
    wire id_is_stype;
    wire id_is_ltype;
    wire id_is_atomic;
    wire id_is_jump;
    wire id_is_btype;
    wire id_is_nop;
    wire id_wr_en;
    wire [2:0] id_dm_select;
    wire [2:0] id_imm_select;
    wire id_sel_pc;
    wire [2:0] id_sel_data;
    wire [1:0] id_store_select;
    wire id_sel_opBR;

    wire [`WORD_WIDTH-1:0] id_rfoutA, id_rfoutB;
    wire [`WORD_WIDTH-1:0] id_imm;
    wire [`WORD_WIDTH-1:0] id_branchtarget;
    wire [`WORD_WIDTH-1:0] id_fwdopA, id_fwdopB;
    wire [`WORD_WIDTH-1:0] id_fwdstore;



    assign ext_probe_id_rfoutA = id_rfoutA;


    assign ext_probe_id_fwdopA = id_fwdopA;


    assign ext_probe_id_sel_opA = id_sel_opA;


    assign ext_probe_id_base_imm = id_base_imm;


    assign ext_probe_id_sel_opBR = id_sel_opBR;


    assign ext_probe_id_is_jump = id_is_jump;


    assign ext_probe_id_branchtarget = id_branchtarget;
// EXE Stage =====================================================================
    wire [17-1:0] exe_pc4;
    wire [`WORD_WIDTH-1:0] exe_fwdopA;
    wire [`WORD_WIDTH-1:0] exe_fwdopB;
    wire [`WORD_WIDTH-1:0] exe_fwdstore;
    wire [`WORD_WIDTH-1:0] exe_imm;
    wire [`REGFILE_BITS-1:0] exe_rd;
    wire [17-1:0] exe_PC;
    assign ext_probe_exe_pc = exe_PC;
    wire [`WORD_WIDTH-1:0] exe_branchtarget;

    wire [`WORD_WIDTH-1:0] opA;
    wire [`WORD_WIDTH-1:0] opB;
    wire [`WORD_WIDTH-1:0] exe_rstore;
    wire exe_div_running;
    wire mul_stall;

    wire [`REGFILE_BITS-1:0] exe_rsA;
    wire [`REGFILE_BITS-1:0] exe_rsB;

    wire exe_z;
    wire exe_less;
    wire exe_signed_less;
    wire [2:0] exe_funct3;
    wire [6:0] exe_opcode;
    wire [5:0] exe_btype;
    assign exe_btype[5] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h0)? 1'b1 : 1'b0) : 1'b0;
    assign exe_btype[4] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h1)? 1'b1 : 1'b0) : 1'b0;
    assign exe_btype[3] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h4)? 1'b1 : 1'b0) : 1'b0;
    assign exe_btype[2] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h5)? 1'b1 : 1'b0) : 1'b0;
    assign exe_btype[1] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h6)? 1'b1 : 1'b0) : 1'b0;
    assign exe_btype[0] = (exe_opcode == `OPC_BTYPE)? ( (exe_funct3 == 3'h7)? 1'b1 : 1'b0) : 1'b0;

    wire [3:0] exe_ALU_op;
    wire [3:0] exe_atomic_op;
    wire exe_div_valid;
    wire [1:0] exe_div_op;
    wire exe_is_stype;
    wire exe_is_ltype;
    wire exe_is_atomic;
    `ifdef FEATURE_BIT_ENABLE
        wire [31:0] exe_dm_write;
    `else
        wire [3:0] exe_dm_write;
    `endif
    wire exe_wr_en;
    wire [2:0] exe_dm_select;
    wire [2:0] exe_sel_data;
    wire [1:0] exe_store_select;
    wire exe_sel_opBR;
    wire exe_to_OCM;

    wire [`WORD_WIDTH-1:0] exe_ALUout;
    wire [`WORD_WIDTH-1:0] exe_DIVout;
    wire [`WORD_WIDTH-1:0] exe_storedata;
    

    assign ext_probe_exe_branchtarget = exe_branchtarget;

    wire exe_is_jump; // Added probe for `exe_is_jump`
    assign ext_probe_exe_is_jump = exe_is_jump;

    wire [31:0] exe_target; // Added probe for calculated jump target
    assign ext_probe_exe_target = exe_target;

// MEM Stage =====================================================================
    wire [17-1:0] mem_pc4;
    wire [`WORD_WIDTH-1:0] mem_ALUout;
    wire [`WORD_WIDTH-1:0] mem_DIVout;
    wire [`WORD_WIDTH-1:0] mem_storedata;
    wire [`WORD_WIDTH-1:0] mem_imm;
    wire [`REGFILE_BITS-1:0]  mem_rd;
    wire [`WORD_WIDTH-1:0] mem_rstore;
    wire [1:0] mem_store_select;
    wire mem_active_op;
    wire mem_is_stype;
    wire mem_is_ltype;
    wire mem_is_atomic;
    wire [3:0] mem_atomic_op;
    wire [31:0] mem_opB;

    wire [3:0] mem_dm_write;
    wire mem_wr_en;
    wire [2:0] mem_dm_select;
    wire [2:0] mem_sel_data;

    wire[`WORD_WIDTH-1:0] mem_DATAMEMout;
    wire [`WORD_WIDTH-1:0] sb_rstore;
    wire [`WORD_WIDTH-1:0] mem_loaddata;

    wire mem_to_OCM;
    wire [`DATAMEM_BITS-1:0] mem_CACHE_addr;
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
    wire  mem_NONCACHE_wr;
    wire  [`WORD_WIDTH-1:0] mem_NONCACHE_in;
    wire [`WORD_WIDTH-1:0] mem_NONCACHEout;
    wire mem_NONCACHE_stall;
    wire mem_NONCACHE_ready;

// WB Stage ======================================================================
    wire [17-1:0] wb_pc4;
    wire [`WORD_WIDTH-1:0] wb_ALUout;
    wire [`WORD_WIDTH-1:0] wb_DIVout;
    wire [`WORD_WIDTH-1:0] wb_loaddata;
    wire [`WORD_WIDTH-1:0] wb_imm;
    wire [`REGFILE_BITS-1:0] wb_rd;

    wire wb_wr_en;
    wire [2:0] wb_sel_data;
    wire [`WORD_WIDTH-1:0] wb_wr_data;
    
        // Additional probe for updated PC new value (if_pcnew)
    assign ext_probe_if_pcnew_1 = if_pcnew;

// Signals for BHT ===============================================================
    wire [1:0] exe_correction;
    wire [17-1:0] exe_PBT;
    wire [17-1:0] exe_CNI;
    wire branch_flush;
    wire jump_flush;

    assign ext_probe_correction      = exe_correction;
    assign ext_probe_exe_PBT         = exe_PBT;
    assign ext_probe_exe_CNI         = exe_CNI;
    assign ext_probe_branch_flush    = branch_flush;
    assign ext_probe_jump_flush      = jump_flush;

// Data Forwarding ===============================================================
    wire fw_exe_to_id_A;
    wire fw_exe_to_id_B;
    wire fw_mem_to_id_A;
    wire fw_mem_to_id_B;
    wire fw_wb_to_id_A;
    wire fw_wb_to_id_B;
    wire fw_wb_to_exe_A;
    wire fw_wb_to_exe_B;
    wire fw_mem_to_exe_B;
    wire load_hazard;

// Clock Gating + SF_Controller ==================================================
    wire if_clk;
    wire id_clk;
    wire exe_clk;
    wire mem_clk;
    wire wb_clk;
    wire rf_clk;

    wire if_clk_en;
    wire id_clk_en;
    wire exe_clk_en;
    wire mem_clk_en;
    wire wb_clk_en;
    wire rf_clk_en;

    wire mem_dm_stall;
    wire mem_dm_ready;

    wire if_stall;
    wire id_stall;
    wire exe_stall;
    wire mem_stall;

    wire if_flush;
    wire id_flush;
    wire exe_flush;
    wire mem_flush;
    wire wb_flush;

    assign ext_probe_if_stall     = if_stall;
    assign ext_probe_id_stall     = id_stall;
    assign ext_probe_if_flush     = if_flush;
    assign ext_probe_id_flush     = id_flush;
    assign ext_probe_jump         = id_is_jump;
    assign ext_probe_enter_branch = if_is_branch;

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

// Compressed Instructions =======================================================
    wire if_not_comp = (if_inst[1:0] == 2'd3);
    wire id_is_comp;
    wire exe_is_comp;

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

    wire [`REGFILE_BITS-1:0] id_c_rsA;
    wire [`REGFILE_BITS-1:0] id_c_rsB;
    wire [`REGFILE_BITS-1:0] id_c_rd;
    wire [`WORD_WIDTH-1:0] id_c_imm;
    wire [`WORD_WIDTH-1:0] id_c_jt;

    wire exe_comp_use_A;
    wire exe_comp_use_B;
    wire [1:0] exe_c_btype;

//////////////////////////////////// ADDTNL WIRE PROBES
    assign ext_probe_mem_loaddata            = mem_loaddata;
    assign ext_probe_wb_loaddata             = wb_loaddata;
    assign ext_probe_mem_datamemout          = mem_DATAMEMout;
    assign ext_probe_ext_noncache_data_load  = ext_noncache_data_load;
    assign ext_probe_ext_noncache_data_valid = ext_noncache_data_valid;
    assign ext_probe_ext_noncache_data_gnt   = ext_noncache_data_gnt;
    assign ext_probe_wb_wr_data              = wb_wr_data;
    assign ext_probe_wb_rd                   = wb_rd;
    assign ext_probe_wb_wr_en                = wb_wr_en;
    assign ext_probe_load_hazard             = load_hazard;
    assign ext_probe_exe_stall               = exe_stall;
    assign ext_probe_mem_stall               = mem_stall;
    assign ext_probe_exe_flush               = exe_flush;
    assign ext_probe_mem_flush               = mem_flush;
    assign ext_probe_wb_flush                = wb_flush;
    assign ext_probe_fw_mem_to_id_A          = fw_mem_to_id_A;
    assign ext_probe_fw_wb_to_id_A           = fw_wb_to_id_A;
    assign ext_probe_fw_wb_to_exe_A          = fw_wb_to_exe_A;
    assign ext_probe_mem_is_ltype            = mem_is_ltype;
    assign ext_probe_mem_is_stype            = mem_is_stype;
    assign ext_probe_mem_dm_select           = mem_dm_select;
    assign ext_probe_mem_sel_data            = mem_sel_data;
    wire [31:0] atomic_probe_temp_t;
    wire [31:0] atomic_probe_data_from_OCM;
    wire        atomic_probe_data_valid;
    wire [3:0]  atomic_probe_state;
    wire [31:0] atomic_probe_data_to_WB;
    assign ext_probe_atomic_temp_t         = atomic_probe_temp_t;
    assign ext_probe_atomic_data_from_ocm  = atomic_probe_data_from_OCM;
    assign ext_probe_atomic_data_valid     = atomic_probe_data_valid;
    assign ext_probe_atomic_state          = atomic_probe_state;
    assign ext_probe_atomic_data_to_wb     = atomic_probe_data_to_WB;

// Interrupt Controller Signals===================================================
    wire ISR_PC_flush;
    wire ISR_pipe_flush;
    wire sel_ISR;
    wire ret_ISR;
    wire ISR_running;
    wire [17-1:0] save_PC;
    wire eret_call;

    assign ext_probe_save_PC   = save_PC;
    assign ext_probe_ret_ISR   = ret_ISR;

/*********************** DATAPATH (INSTANTIATING MODULES) ***********************/
    sf_controller SF_CONTROLLER(
        .clk(clk),
        .nrst(nrst),

        .if_pc(if_PC),
        .if_ready(if_ready),
        .if_pcnew(if_pcnew),

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

        .if_stall(if_stall),
        .id_stall(id_stall),
        .exe_stall(exe_stall),
        .mem_stall(mem_stall),

        .if_flush(if_flush),
        .id_flush(id_flush),
        .exe_flush(exe_flush),
        .mem_flush(mem_flush),
        .wb_flush(wb_flush),

        .if_clk_en(if_clk_en),
        .id_clk_en(id_clk_en),
        .exe_clk_en(exe_clk_en),
        .mem_clk_en(mem_clk_en),
        .wb_clk_en(wb_clk_en),
        .rf_clk_en(rf_clk_en),

        .id_rsA(id_rsA),
        .id_rsB(id_rsB),
        .exe_rsA(exe_rsA),
        .exe_rsB(exe_rsB),

        .exe_rd(exe_rd),
        .mem_rd(mem_rd),
        .wb_rd(wb_rd),

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

    `ifdef FEATURE_XILINX_BUFFER_IP
        BUFGCE #(.SIM_DEVICE("7SERIES")) en_iF (
            .I(clk),
            .CE(if_clk_en),
            .O(if_clk)
        );

        BUFGCE #(.SIM_DEVICE("7SERIES")) en_id (
            .I(clk),
            .CE(id_clk_en),
            .O(id_clk)
        );

        BUFGCE #(.SIM_DEVICE("7SERIES")) en_exe (
            .I(clk),
            .CE(exe_clk_en),
            .O(exe_clk)
        );

        BUFGCE #(.SIM_DEVICE("7SERIES")) en_mem (
            .I(clk),
            .CE(mem_clk_en),
            .O(mem_clk)
        );

        BUFGCE #(.SIM_DEVICE("7SERIES")) en_wb (
            .I(clk),
            .CE(wb_clk_en),
            .O(wb_clk)
        );

        BUFGCE #(.SIM_DEVICE("7SERIES")) en_rf (
            .I(clk),
            .CE(rf_clk_en),
            .O(rf_clk)
        );
    `else
        assign if_clk  = clk;
        assign id_clk  = clk;
        assign exe_clk = clk;
        assign mem_clk = clk;
        assign wb_clk  = clk;
        assign rf_clk  = clk;
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

        .exe_correction(exe_correction),
        .id_sel_pc(id_sel_pc),

        .ISR_PC_flush(ISR_PC_flush),
        .ISR_pipe_flush(ISR_pipe_flush),
        .sel_ISR(sel_ISR),
        .ret_ISR(ret_ISR),

        .ISR_running(ISR_running),
        .save_PC(save_PC),
        .eret_call(eret_call)
    );

    assign if_pc4 = if_PC + (if_not_comp ? 12'd4 : 12'd2);

    always @(*) begin
        if_is_branch = branch_flush;
    end

    always @(*) begin
        if (ret_ISR)
            if_pcnew = save_PC;
        else begin
            case (exe_correction)
                2'b10: if_pcnew = {exe_CNI, 1'h0};
                2'b11: if_pcnew = {exe_PBT, 1'h0};
                default: begin
                    case (id_sel_pc)
                        1'b1:    if_pcnew = id_branchtarget;
                        default: if_pcnew = if_pc4;
                    endcase
                end
            endcase
        end
    end

//    always @(*) begin
//        if (ret_ISR)
//            if_pcnew = save_PC;
//        else begin
//            case (exe_correction)
//                2'b10: if_pcnew = exe_branchtarget;   // temporary debug change
//                2'b11: if_pcnew = exe_branchtarget;   // temporary debug change
//                default: begin
//                    case (id_sel_pc)
//                        1'b1:    if_pcnew = id_branchtarget;
//                        default: if_pcnew = if_pc4;
//                    endcase
//                end
//            endcase
//        end
//    end

// ID Stage ======================================================================
    assign id_fwdopA = fw_exe_to_id_A ?
                            ((exe_sel_data == 3'd4) ? exe_DIVout :
                             (exe_sel_data == 3'd2) ? exe_imm :
                             (exe_sel_data == 3'd1) ? exe_ALUout :
                                                      exe_pc4) :
                       fw_mem_to_id_A ?
                            ((mem_sel_data == 3'd4) ? mem_DIVout :
                             (mem_sel_data == 3'd3) ? mem_loaddata :
                             (mem_sel_data == 3'd2) ? mem_imm :
                             (mem_sel_data == 3'd1) ? mem_ALUout :
                                                      mem_pc4) :
                       fw_wb_to_id_A ? wb_wr_data :
                       id_sel_opA ? id_rfoutA : id_PC;

    assign id_fwdopB = (fw_exe_to_id_B && !id_is_stype) ?
                            ((exe_sel_data == 3'd4) ? exe_DIVout :
                             (exe_sel_data == 3'd2) ? exe_imm :
                             (exe_sel_data == 3'd1) ? exe_ALUout :
                                                      exe_pc4) :
                       (fw_mem_to_id_B && !id_is_stype) ?
                            ((mem_sel_data == 3'd4) ? mem_DIVout :
                             (mem_sel_data == 3'd3) ? mem_loaddata :
                             (mem_sel_data == 3'd2) ? mem_imm :
                             (mem_sel_data == 3'd1) ? mem_ALUout :
                                                      mem_pc4) :
                       (fw_wb_to_id_B && !id_is_stype) ?
                            wb_wr_data :
                       id_sel_opB ? id_imm : id_rfoutB;

    assign id_fwdstore = (fw_exe_to_id_B && id_is_stype) ?
                            ((exe_sel_data == 3'd4) ? exe_DIVout :
                             (exe_sel_data == 3'd2) ? exe_imm :
                             (exe_sel_data == 3'd1) ? exe_ALUout :
                                                      exe_pc4) :
                         (fw_mem_to_id_B && id_is_stype) ?
                            ((mem_sel_data == 3'd4) ? mem_DIVout :
                             (mem_sel_data == 3'd3) ? mem_loaddata :
                             (mem_sel_data == 3'd2) ? mem_imm :
                             (mem_sel_data == 3'd1) ? mem_ALUout :
                                                      mem_pc4) :
                         (fw_wb_to_id_B && id_is_stype) ?
                            wb_wr_data : id_rfoutB;

    controller1 CONTROL(
        .opcode(id_opcode),
        .funct3(id_funct3),
        .funct7(id_funct7),

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

        .src1_addr(id_rsA),
        .src2_addr(id_rsB),
        .src1_out(id_rfoutA),
        .src2_out(id_rfoutB)
    );

    shiftsignshuff SHIFTSIGNSHUFF(
        .imm_select(id_base_imm_select),
        .inst(id_inst[31:7]),
        .imm(id_base_imm)
    );

    assign id_brOP = (id_sel_opBR) ? id_fwdopA : id_PC;
    assign id_branchtarget = id_brOP + (id_is_comp ? (id_sel_opBR ? 32'd0 : id_c_jt) : id_base_imm);

    assign ext_probe_id_branchtarget = id_branchtarget;
    assign ext_probe_id_sel_pc       = id_sel_pc;

    compressed_decoder C_DECODER(
        .inst(id_inst[15:0]),
        .is_compressed(id_is_comp),

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

        .rs1(id_c_rsA),
        .rs2(id_c_rsB),
        .rd(id_c_rd),
        .imm(id_c_imm),
        .jt(id_c_jt)
    );

    assign id_dm_select    = id_is_comp ? id_c_dm_select      : id_base_dm_select;
    assign id_sel_data     = id_is_comp ? id_c_sel_data       : id_base_sel_data;
    assign id_store_select = id_is_comp ? id_c_store_select   : id_base_store_select;
    assign id_ALU_op       = id_is_comp ? id_c_alu_op         : id_base_ALU_op;
    assign id_is_stype     = id_is_comp ? id_c_is_stype       : id_base_is_stype;
    assign id_is_ltype     = id_is_comp ? id_c_is_ltype       : id_base_is_ltype;
    assign id_is_atomic    = id_is_comp ? 0                   : id_base_is_atomic;
    assign id_wr_en        = id_is_comp ? id_c_wr_en          : id_base_wr_en;
    assign id_imm          = id_is_comp ? id_c_imm            : id_base_imm;
    assign id_rd           = id_is_comp ? id_c_rd             : id_base_rd;
    assign id_rsA          = id_is_comp ? id_c_rsA            : id_base_rsA;
    assign id_rsB          = id_is_comp ? id_c_rsB            : id_base_rsB;
    assign id_sel_opA      = id_is_comp ? id_c_sel_opA        : id_base_sel_opA;
    assign id_sel_opB      = id_is_comp ? id_c_sel_opB        : id_base_sel_opB;
    assign id_sel_opBR     = id_is_comp ? id_c_sel_opBR       : id_base_sel_opBR;
    assign id_sel_pc       = id_is_comp ? id_c_sel_pc         : id_base_sel_pc;
    assign id_is_jump      = id_is_comp ? id_c_is_jump        : id_base_is_jump;
    assign id_is_btype     = id_is_comp ? id_c_is_btype       : id_base_is_btype;
    assign id_imm_select   = id_is_comp ? id_c_imm_select     : id_base_imm_select;
    assign id_is_nop       = id_is_comp ? id_c_is_nop         : (id_inst == 32'h13);
    assign id_opcode       = id_is_comp ? id_c_opcode         : id_inst[6:0];

    pipereg_id_exe ID_EXE(
        .clk(exe_clk),
        .nrst(nrst),

        .stall(id_stall),
        .flush(exe_flush),

        .id_pc4(id_pc4),                    .exe_pc4(exe_pc4),
        .id_fwdopA(id_fwdopA),              .exe_fwdopA(exe_fwdopA),
        .id_fwdopB(id_fwdopB),              .exe_fwdopB(exe_fwdopB),

        .id_opcode(id_opcode),              .exe_opcode(exe_opcode),
        .id_funct3(id_funct3),              .exe_funct3(exe_funct3),
        .id_branchtarget(id_branchtarget),  .exe_branchtarget(exe_branchtarget),

        .id_fwdstore(id_fwdstore),          .exe_fwdstore(exe_fwdstore),

        .id_imm(id_imm),                    .exe_imm(exe_imm),
        .id_rd(id_rd),                      .exe_rd(exe_rd),
        .id_PC(id_PC),                      .exe_PC(exe_PC),

        .id_ALU_op(id_ALU_op),              .exe_ALU_op(exe_ALU_op),
        .id_atomic_op(id_atomic_op),        .exe_atomic_op(exe_atomic_op),
        .id_c_btype(id_c_btype),            .exe_c_btype(exe_c_btype),
        .id_sel_opBR(id_sel_opBR),          .exe_sel_opBR(exe_sel_opBR),
        .id_div_valid(id_div_valid),        .exe_div_valid(exe_div_valid),
        .id_div_op(id_div_op),              .exe_div_op(exe_div_op),
        .id_is_stype(id_is_stype),          .exe_is_stype(exe_is_stype),
        .id_is_ltype(id_is_ltype),          .exe_is_ltype(exe_is_ltype),
        .id_is_atomic(id_is_atomic),        .exe_is_atomic(exe_is_atomic),
        .id_wr_en(id_wr_en),                .exe_wr_en(exe_wr_en),
        .id_dm_select(id_dm_select),        .exe_dm_select(exe_dm_select),
        .id_sel_data(id_sel_data),          .exe_sel_data(exe_sel_data),
        .id_store_select(id_store_select),  .exe_store_select(exe_store_select),
        .id_comp_use_A(id_c_use_A),         .exe_comp_use_A(exe_comp_use_A),
        .id_comp_use_B(id_c_use_B),         .exe_comp_use_B(exe_comp_use_B),
        .id_is_comp(id_is_comp),            .exe_is_comp(exe_is_comp),
        .id_rs1(id_rsA),                    .exe_rs1(exe_rsA),
        .id_rs2(id_rsB),                    .exe_rs2(exe_rsB)
    );

    assign ext_probe_exe_branchtarget = exe_branchtarget;

// EXE Stage =====================================================================
    assign opA = fw_wb_to_exe_A ? wb_loaddata : exe_fwdopA;
    assign opB = (fw_wb_to_exe_B && !exe_is_stype) ? wb_loaddata : exe_fwdopB;
    assign exe_rstore = fw_mem_to_exe_B ? mem_loaddata : (fw_wb_to_exe_B ? wb_loaddata : exe_fwdstore);

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

        .if_PC(if_PC[17-1:1]),

        .id_PC(id_PC[17-1:1]),
        .id_branchtarget(id_branchtarget[17-1:1]),
        .id_is_jump(id_is_jump),
        .id_is_btype(id_is_btype),

        .exe_PC(exe_PC[17-1:1]),
        .exe_branchtarget(exe_branchtarget[17-1:1]),
        .exe_sel_opBR(exe_sel_opBR),
        .exe_z(exe_z),
        .exe_less(exe_less),
        .exe_signed_less(exe_signed_less),
        .exe_btype(exe_btype),
        .exe_c_btype(exe_c_btype),

        .exe_correction(exe_correction),
        .branch_flush(branch_flush),
        .jump_flush(jump_flush),
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

        .exe_pc4(exe_pc4),                  .mem_pc4(mem_pc4),
        .exe_ALUout(exe_ALUout),            .mem_ALUout(mem_ALUout),
        .exe_DIVout(exe_DIVout),            .mem_DIVout(mem_DIVout),
        .exe_storedata(exe_storedata),      .mem_storedata(mem_storedata),
        .exe_imm(exe_imm),                  .mem_imm(mem_imm),
        .exe_rd(exe_rd),                    .mem_rd(mem_rd),
        .exe_rstore(exe_rstore),            .mem_rstore(mem_rstore),
        .exe_is_stype(exe_is_stype),        .mem_is_stype(mem_is_stype),
        .exe_is_ltype(exe_is_ltype),        .mem_is_ltype(mem_is_ltype),
        .exe_store_select(exe_store_select),.mem_store_select(mem_store_select),

        .exe_dm_write(exe_dm_write),        .mem_dm_write(mem_dm_write),
        .exe_wr_en(exe_wr_en),              .mem_wr_en(mem_wr_en),
        .exe_dm_select(exe_dm_select),      .mem_dm_select(mem_dm_select),
        .exe_sel_data(exe_sel_data),        .mem_sel_data(mem_sel_data),
        .exe_is_atomic(exe_is_atomic),      .mem_is_atomic(mem_is_atomic),
        .exe_atomic_op(exe_atomic_op),      .mem_atomic_op(mem_atomic_op),
        .exe_opB(opB),                      .mem_opB(mem_opB)
    );

// MEM Stage =====================================================================
    assign ext_probe_memALUout = mem_ALUout;
    assign ext_probe_datastore = ext_noncache_data_store;

    assign mem_active_op = mem_is_atomic || mem_is_stype || mem_is_ltype;

    ATOMIC_MODULE #(.ADDR_BITS(`DATAMEM_BITS)) ATOMIC_ALU(
        .clk(mem_clk),
        .nrst(nrst),
        .i_wr(mem_is_stype),
        .i_rd(mem_is_ltype),
        .i_is_atomic(mem_is_atomic),
        .i_data_from_core(mem_storedata),
        .i_data_from_OCM(ext_noncache_data_load),
        .i_addr(mem_ALUout),
        .i_dm_write(mem_dm_write),
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
        .o_rd(ext_noncache_rd),
        .probe_temp_t(atomic_probe_temp_t),
        .probe_data_from_OCM(atomic_probe_data_from_OCM),
        .probe_data_valid(atomic_probe_data_valid),
        .probe_state(atomic_probe_state)
//        .o_data_to_WB(atomic_probe_data_to_WB)
    );

    assign mem_DATAMEMout = mem_NONCACHEout;
    assign mem_dm_ready = mem_NONCACHE_ready;
    assign mem_dm_stall = mem_NONCACHE_stall;

    loadblock LOADBLOCK(
        .data(mem_DATAMEMout),
        .byte_offset(mem_ALUout[1:0]),
        .dm_select(mem_dm_select),
        .loaddata(mem_loaddata)
    );

    pipereg_mem_wb MEM_WB(
        .clk(wb_clk),
        .nrst(nrst),

        .stall(mem_stall),
        .flush(wb_flush),

        .mem_pc4(mem_pc4),                  .wb_pc4(wb_pc4),
        .mem_ALUout(mem_ALUout),            .wb_ALUout(wb_ALUout),
        .mem_DIVout(mem_DIVout),            .wb_DIVout(wb_DIVout),
        .mem_loaddata(mem_loaddata),        .wb_loaddata(wb_loaddata),
        .mem_imm(mem_imm),                  .wb_imm(wb_imm),
        .mem_rd(mem_rd),                    .wb_rd(wb_rd),

        .mem_wr_en(mem_wr_en),              .wb_wr_en(wb_wr_en),
        .mem_sel_data(mem_sel_data),        .wb_sel_data(wb_sel_data)
    );

// WB Stage ======================================================================
    assign wb_wr_data = (wb_sel_data == 3'd0) ? wb_pc4 :
                        (wb_sel_data == 3'd1) ? wb_ALUout :
                        (wb_sel_data == 3'd2) ? wb_imm :
                        (wb_sel_data == 3'd4) ? wb_DIVout :
                                                wb_loaddata;

endmodule