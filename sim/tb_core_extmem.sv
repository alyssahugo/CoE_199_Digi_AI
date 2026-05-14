`timescale 1ns / 1ps

`include "constants.vh"
`include "config.vh"

module tb_core_extmem();

    parameter NUM_TESTS = 70;
    string test_pile[NUM_TESTS] = '{
        "C-ADD",
        "C-ADDI",
        "C-ADDI16SP",
        "C-ADDI4SPN",
        "C-AND",
        "C-ANDI",
        "C-BEQZ",
        "C-BNEZ",
        "C-J",
        "C-JAL",
        "C-JALR",
        "C-JR",
        "C-LI",
        "C-LUI",
        "C-LW",
        "C-LWSP",
        "C-MV",
        "C-OR",
        "C-SLLI",
        "C-SRAI",
        "C-SRLI",
        "C-SUB",
        "C-SW",
        "C-SWSP",
        "C-XOR",
        "I-ADD-01",
        "I-ADDI-01",
        "I-AND-01",
        "I-ANDI-01",
        "I-AUIPC-01",
        "I-BEQ-01",
        "I-BGE-01",
        "I-BGEU-01",
        "I-BLT-01",
        "I-BLTU-01",
        "I-BNE-01",
        "I-DELAY_SLOTS-01",
        "I-JAL-01",
        "I-JALR-01",
        "I-LB-01",
        "I-LBU-01",
        "I-LH-01",
        "I-LHU-01",
        "I-LUI-01",
        "I-LW-01",
        "I-NOP-01",
        "I-OR-01",
        "I-ORI-01",
        "I-RF_size-01",
        "I-RF_width-01",
        "I-SB-01",
        "I-SH-01",
        "I-SLL-01",
        "I-SLLI-01",
        "I-SLT-01",
        "I-SLTI-01",
        "I-SLTIU-01",
        "I-SLTU-01",
        "I-SRA-01",
        "I-SRAI-01",
        "I-SRL-01",
        "I-SRLI-01",
        "I-SUB-01",
        "I-SW-01",
        "I-XOR-01",
        "I-XORI-01",
        "MUL",
        "MULH",
        "MULHSU",
        "MULHU"
    };
    string current_test = "";
    parameter string file_pile[NUM_TESTS] = {
        "C-ADD.mem",
        "C-ADDI.mem",
        "C-ADDI16SP.mem",
        "C-ADDI4SPN.mem",
        "C-AND.mem",
        "C-ANDI.mem",
        "C-BEQZ.mem",
        "C-BNEZ.mem",
        "C-J.mem",
        "C-JAL.mem",
        "C-JALR.mem",
        "C-JR.mem",
        "C-LI.mem",
        "C-LUI.mem",
        "C-LW.mem",
        "C-LWSP.mem",
        "C-MV.mem",
        "C-OR.mem",
        "C-SLLI.mem",
        "C-SRAI.mem",
        "C-SRLI.mem",
        "C-SUB.mem",
        "C-SW.mem",
        "C-SWSP.mem",
        "C-XOR.mem",
        "I-ADD-01.mem",
        "I-ADDI-01.mem",
        "I-AND-01.mem",
        "I-ANDI-01.mem",
        "I-AUIPC-01.mem",
        "I-BEQ-01.mem",
        "I-BGE-01.mem",
        "I-BGEU-01.mem",
        "I-BLT-01.mem",
        "I-BLTU-01.mem",
        "I-BNE-01.mem",
        "I-DELAY_SLOTS-01.mem",
        "I-JAL-01.mem",
        "I-JALR-01.mem",
        "I-LB-01.mem",
        "I-LBU-01.mem",
        "I-LH-01.mem",
        "I-LHU-01.mem",
        "I-LUI-01.mem",
        "I-LW-01.mem",
        "I-NOP-01.mem",
        "I-OR-01.mem",
        "I-ORI-01.mem",
        "I-RF_size-01.mem",
        "I-RF_width-01.mem",
        "I-SB-01.mem",
        "I-SH-01.mem",
        "I-SLL-01.mem",
        "I-SLLI-01.mem",
        "I-SLT-01.mem",
        "I-SLTI-01.mem",
        "I-SLTIU-01.mem",
        "I-SLTU-01.mem",
        "I-SRA-01.mem",
        "I-SRAI-01.mem",
        "I-SRL-01.mem",
        "I-SRLI-01.mem",
        "I-SUB-01.mem",
        "I-SW-01.mem",
        "I-XOR-01.mem",
        "I-XORI-01.mem",
        "MUL.mem",
        "MULH.mem",
        "MULHSU.mem",
        "MULHU.mem"
    };
	
	reg CLK;
	wire testclk = CLK;
	reg nrst;
	wire [`INT_SIG_WIDTH-1:0] int_sig = 0;;

	reg [3:0] con_write;
	reg [`DATAMEM_BITS-1:0] con_addr;
	reg [`WORD_WIDTH-1:0] con_in;
	wire [`WORD_WIDTH-1:0] con_out;

	wire [`WORD_WIDTH:0] INST;
	reg [`WORD_WIDTH:0] last_inst;
	
	always
	   #20 CLK = ~CLK;		// 25MHz clock
    
		
	

	
	
	
	reg [31:0] nop_counter;
	// Checking for 10 NOPs/50 looping jumps in a row
    // NOTE: checking for last_inst should be done for at least 50 cycles
    // if there are DIV operations running in the processor.
    wire [31:0] box;
    
    // Integers for checking results through the answer key
    integer i, j, check, done, pass, consecutive_nops;
    integer total_test_cases = 0;
    integer print_metrics;
    integer total_error_count = 0;
    
    // Tracking "highest" data address written to for
    // displaying only what's needed in the answer key
    // (since there is no need to display the addresses
    // not written to)
    integer max_data_addr;
    
    reg suite_done [NUM_TESTS];
    reg test_suites_done;
    /*
    wire [3:0] dmem_data_write;
	`ifdef FEATURE_BIT_ENABLE
		wire [`WORD_WIDTH-1:0] core_data_write;
		assign dmem_data_write = {core_data_write[24], core_data_write[16], core_data_write[8], core_data_write[0]};
	`else
		wire [3:0] core_data_write;
		assign dmem_data_write = core_data_write;
	`endif
    
    wire [`DATAMEM_BITS-1:0] core_data_addr;	
    wire [`BUS_BITS-1:0] bus_data_addr = {core_data_addr, 2'b0};	
    wire [`DATAMEM_WIDTH-1:0] core_data_store;	
    wire [`DATAMEM_WIDTH-1:0] core_data_load;
    wire core_data_request;

    

    
    */
    reg [31:0] clock_counter;
    wire [`EXT_PC_ADDR_BITS-1:0] core_inst_addr;
    wire [`WORD_WIDTH-1:0] core_inst_data;
	wire [`WORD_WIDTH-1:0] core_if_inst;
	wire [`WORD_WIDTH-1:0] core_id_inst;
    
    wire core_data_request;
//    wire core_cache_data_request;
//    wire active_data_op = ext_cache_req || ext_noncache_req;
    wire [3:0] core_data_write;
//    wire [3:0] core_cache_data_write;
//    wire core_cache_wr;
		//assign dmem_data_write = core_data_write;
	//`endif

    wire [`DATAMEM_BITS-1:0] core_data_addr;
//    wire [`DATAMEM_BITS-1:0] core_cache_data_addr;	
    wire [`BUS_BITS-1:0] bus_data_addr = {core_data_addr, 2'b0};	
//    wire [`WORD_WIDTH-1:0] core_data_store;	
//    wire [`WORD_WIDTH-1:0] core_cache_data_store;
    
    wire [`WORD_WIDTH-1:0] core_data_load;
    //wire [127:0] core_cache_data_load;
    

    
    //wire core_data_grant = 1'b1;
    //wire core_data_valid = 1'b1;
        
    wire core_data_grant;
    wire core_data_valid;
    wire core_done;
//    wire core_cache_done;
    wire core_data_write_valid;
    wire [3:0] L2_dm_write;
    wire [`DATAMEM_BITS-1:0] L2_addr_t;
    wire [`DATAMEM_BITS-1:0] L2_addr;
    wire [31:0] L2_data;
    wire L2_wr;
    wire L2_rd;
    wire L2_done;
    
    wire [3:0] weB;
    wire [31:0] data_to_memB;
    wire [31:0] data_from_memA;
    wire [`DATAMEM_BITS-3:0] addr_to_memA;
    wire [`DATAMEM_BITS-1:0] addr_to_memB;

    wire [127:0] data_block_from_L2;
    
    wire [`WORD_WIDTH-1:0] ram_data;
    wire [`WORD_WIDTH-1:0] ram_data_in;
    
    wire [`DATAMEM_BITS-1:0] ram_addr;
    wire [3:0] ram_dm_wire;
    
    reg [`DATAMEM_BITS:0] addr_tb;    
    wire [31:0] out_tb;
    wire tb_hit;
//    wire [31:0] tb_data_cache;
    
    /*
    datamem DATAMEM (
        .clk(CLK),
        .nrst(nrst),

        .dm_write(dmem_data_write),
        `ifdef FEATURE_DMEM_BYTE_ADDRESS
		      .data_addr(core_data_addr),
		`else 
		      .data_addr(bus_data_addr),      
	    `endif
          
        .data_in(core_data_store),
        .data_req(core_data_request),
        .data_gnt(),
        .data_valid(),

        .con_write(con_write),
        .con_addr(con_addr),
        .con_in(con_in),
        .con_en(1'b1),

        .data_out(core_data_load),
        .con_out(con_out)
    );
    */
    instmem INSTMEM (
        .clk(testclk),
        .nrst(nrst),
        .sel_ISR(1'b0),

        .addr({1'b0, core_inst_addr}),
        .instruction(core_inst_data)
    );
    /*    
    core_extmem CORE(
        .clk(testclk),
        .nrst(nrst),
        `ifdef FEATURE_INTERRUPT_ENABLE
		    .int_sig(int_sig),
	    `endif 
        

         .ext_data_wr_en(),
         .ext_noncache_data_addr(core_data_addr),
         .ext_noncache_data_store(core_data_store),	
         .ext_noncache_data_load(core_data_load),
         .ext_noncache_data_req(core_data_request),
         .ext_noncache_data_gnt(core_data_grant),
         .ext_noncache_data_valid(core_data_valid),
         .ext_noncache_data_write_valid(core_data_write_valid),
         .ext_noncache_done(core_done),
         .ext_noncache_data_write(core_data_write),
        
         .ext_cache_data_addr(core_cache_data_addr),
         .ext_cache_data_store(core_cache_data_store),	
         .ext_cache_data_load(data_block_from_L2), // NOT PARAMETRIZED
         .ext_cache_data_req(core_cache_data_request),
         .ext_cache_data_gnt(core_cache_grant),
         .ext_cache_wr(core_cache_wr),
         .ext_cache_data_valid(L2_done),
         .ext_cache_data_write_valid(),
         .ext_cache_done(core_cache_done),
         .ext_cache_data_write(core_cache_data_write),
        
        `ifdef FEATURE_INST_TRACE_ENABLE
		.ext_if_inst(core_if_inst),
		.ext_id_inst(core_id_inst),
	    `endif
	    
	    .ext_inst_addr(core_inst_addr),
        .ext_inst_data(core_inst_data)
        //.ext_OCM_done(core_done)
    );
     
     // On chip memory external to the core
    OCM #(.ADDR_BITS(`DATAMEM_BITS))
        ON_CHIP_MEMORY(
            .clk(testclk), .nrst(nrst),
            .i_req_core_1(core_data_request),
            .i_done_core_1(core_done),
            .o_grant_core_1(core_data_grant),
            .i_data_core_1(core_data_store),
            .i_dm_write_core_1(core_data_write),
            //.o_data_core_1(core_1_data_from_OCM),
            .i_addr_1(core_data_addr),
            .o_data(core_data_load),
            .valid_data(core_data_valid),
            .valid_write_data(core_data_write_valid),
            
            //outputs to RAM
            .ram_data(ram_data),
            .in_addr_bus(ram_addr),
            .in_data_bus(ram_data_in),
            .dm_wire(ram_dm_wire)
            
            
            .addr_tb(addr_tb),
            .out_tb(out_tb),
            
           
            
        );
  
  
   // L2 //////////////////////////////////////////////

    arbitration_unit #(.ADDR_BITS(`DATAMEM_BITS))
        arbitration_unit (
            .clk(testclk),                 .nrst(nrst),
            // core 1
            .i_req_core_1(core_cache_data_request || core_cache_wr),
            .i_wr_core_1(core_cache_wr),
            .i_rd_core_1(core_cache_data_request),
            .i_done_core_1(core_cache_done),
            .i_data_core_1(core_cache_data_store),
            .i_dm_write_core_1(core_cache_data_write),
            .i_addr_1(core_cache_data_addr),
            .o_grant_core_1(core_cache_grant),
            
            
            //core 2
            .i_req_core_2(1'b0), // disable core 2 
            
            
            .o_addr(L2_addr_t),
            .o_wr(L2_wr),
            .o_rd(L2_rd),
            .o_dm_write(L2_dm_write),
            .o_data(L2_data)
            
            
        
        );
    
    L2_cache_top # (.CACHE_WAY(4), .CACHE_SIZE(1024), .ADDR_BITS(`DATAMEM_BITS))
        L2_cache (
            .clk(testclk),          .nrst(nrst),
            .i_dm_write(L2_dm_write),      .i_rd(L2_rd),
            .i_wr(L2_wr),            .i_data_addr(L2_addr),
            .i_data(L2_data),          .i_ready_mm(1'b1),
            .i_L1_done(core_cache_done),
            .o_data(data_block_from_L2),          .o_all_done(L2_done),
            
            // To RAM
            .i_data_from_memA(data_from_memA),
            .o_addr_to_memA(addr_to_memA),
            .o_write_signal_ram(weB),
            .o_data_to_memB(data_to_memB),
            .o_addr_to_memB(addr_to_memB),
            
            .tb_hit(tb_hit),
            .tb_data_o(tb_data_cache)
            
        );
    
    */
    wire bram_clk_a;
    wire bram_clk_b;
    wire [3:0] bram_weA;
    wire [3:0] bram_weB;
    wire [31:0] bram_doutA;
    wire [31:0] bram_doutB;
    wire [31:0] bram_dinA;
    wire [31:0] bram_dinB;
    core_extmem_cacheless DUT (
        .clk(CLK),
        .nrst(nrst),

//        .int_sig(int_sig),

        .ext_noncache_data_write(ext_noncache_data_write),
        .ext_noncache_data_addr(ext_noncache_data_addr),
        .ext_noncache_data_store(ext_noncache_data_store),
        .ext_noncache_data_load(ext_noncache_data_load),
        .ext_noncache_data_req(ext_noncache_data_req),
        .ext_noncache_data_gnt(ext_noncache_data_gnt),
        .ext_noncache_data_valid(ext_noncache_data_valid),
        .ext_noncache_data_write_valid(ext_noncache_data_write_valid),
        .ext_noncache_done(ext_noncache_done),
        .ext_noncache_wr(ext_noncache_wr),
        .ext_noncache_rd(ext_noncache_rd),

        .ext_if_inst(ext_if_inst),
        .ext_id_inst(ext_id_inst),
        .ext_trace_ready(ext_trace_ready),

        .ext_probe_memALUout(ext_probe_memALUout),
        .ext_probe_datastore(ext_probe_datastore),

        .ext_probe_if_pc(ext_probe_if_pc),
        .ext_probe_id_pc(ext_probe_id_pc),
        .ext_probe_if_pcnew(ext_probe_if_pcnew),
        .ext_probe_exe_pc(ext_probe_exe_pc),
        .ext_probe_if_ready(ext_probe_if_ready),
        .ext_probe_if_stall(ext_probe_if_stall),
        .ext_probe_id_stall(ext_probe_id_stall),
        .ext_probe_if_flush(ext_probe_if_flush),
        .ext_probe_id_flush(ext_probe_id_flush),
        .ext_probe_jump(ext_probe_jump),
        .ext_probe_enter_branch(ext_probe_enter_branch),
        .ext_probe_correction(ext_probe_correction),

        .ext_probe_id_branchtarget(ext_probe_id_branchtarget),
        .ext_probe_exe_branchtarget(ext_probe_exe_branchtarget),
        .ext_probe_exe_PBT(ext_probe_exe_PBT),
        .ext_probe_exe_CNI(ext_probe_exe_CNI),
        .ext_probe_save_PC(ext_probe_save_PC),
        .ext_probe_id_sel_pc(ext_probe_id_sel_pc),
        .ext_probe_ret_ISR(ext_probe_ret_ISR),
        .ext_probe_branch_flush(ext_probe_branch_flush),
        .ext_probe_jump_flush(ext_probe_jump_flush),

        .ext_inst_addr(core_inst_addr),
        .ext_inst_data(core_inst_data),

        .ext_probe_id_rfoutA(ext_probe_id_rfoutA),
        .ext_probe_id_fwdopA(ext_probe_id_fwdopA),
        .ext_probe_id_sel_opA(ext_probe_id_sel_opA),
        .ext_probe_id_base_imm(ext_probe_id_base_imm),
        .ext_probe_id_sel_opBR(ext_probe_id_sel_opBR),
        .ext_probe_id_is_jump(ext_probe_id_is_jump),
        .ext_probe_exe_is_jump(ext_probe_exe_is_jump),
        .ext_probe_exe_target(ext_probe_exe_target),
        .ext_probe_if_pcnew_1(ext_probe_if_pcnew_1),

        .ext_probe_mem_loaddata(ext_probe_mem_loaddata),
        .ext_probe_wb_loaddata(ext_probe_wb_loaddata),
        .ext_probe_mem_datamemout(ext_probe_mem_datamemout),
        .ext_probe_ext_noncache_data_load(ext_probe_ext_noncache_data_load),
        .ext_probe_ext_noncache_data_valid(ext_probe_ext_noncache_data_valid),
        .ext_probe_ext_noncache_data_gnt(ext_probe_ext_noncache_data_gnt),
        .ext_probe_wb_wr_data(ext_probe_wb_wr_data),
        .ext_probe_wb_rd(ext_probe_wb_rd),
        .ext_probe_wb_wr_en(ext_probe_wb_wr_en),
        .ext_probe_load_hazard(ext_probe_load_hazard),
        .ext_probe_exe_stall(ext_probe_exe_stall),
        .ext_probe_mem_stall(ext_probe_mem_stall),
        .ext_probe_exe_flush(ext_probe_exe_flush),
        .ext_probe_mem_flush(ext_probe_mem_flush),
        .ext_probe_wb_flush(ext_probe_wb_flush),
        .ext_probe_fw_mem_to_id_A(ext_probe_fw_mem_to_id_A),
        .ext_probe_fw_wb_to_id_A(ext_probe_fw_wb_to_id_A),
        .ext_probe_fw_wb_to_exe_A(ext_probe_fw_wb_to_exe_A),
        .ext_probe_mem_is_ltype(ext_probe_mem_is_ltype),
        .ext_probe_mem_is_stype(ext_probe_mem_is_stype),
        .ext_probe_mem_dm_select(ext_probe_mem_dm_select),
        .ext_probe_mem_sel_data(ext_probe_mem_sel_data),
        .ext_probe_atomic_temp_t(ext_probe_atomic_temp_t),
        .ext_probe_atomic_data_from_ocm(ext_probe_atomic_data_from_ocm),
        .ext_probe_atomic_data_valid(ext_probe_atomic_data_valid),
        .ext_probe_atomic_state(ext_probe_atomic_state),
        .ext_probe_atomic_data_to_wb(ext_probe_atomic_data_to_wb)
    );
     four_port_memory_construct # (.ADDR_WIDTH(`DATAMEM_BITS-2))
        memory (
            // PORT A - refills
            .clkA(bram_clk_a),
            .enaA(1'b1),
            .weA(bram_weA),
            .addrA(addr_to_memA),
            .doutA(bram_doutA),
            .dinA(bram_dinA),
            
            // PORT B - Eviction
            .clkB(bram_clk_b),
            .enaB(1'b1),
            .weB(bram_weB),
            .addrB(addr_to_memB),
            .dinB(bram_dinB),
            .doutB(bram_doutB),
            
            // PORT D - OCM
            .clkC(CLK),
            .enaC(1'b1),
            .weC(ram_dm_wire),
            .addrC(ram_addr),
            .dinC(ram_data_in),
            .doutC(ram_data),
            
            // PORT D - Testbench
            .clkD(CLK),
            .enaD(1'b1),
            .weD(4'b0),
            .addrD(addr_tb >> 2),
            .doutD(out_tb)
            
        );
    /*
    wire core_data_grant;
    wire core_data_valid;
    wire core_done;
    wire core_data_write_valid;
    core_extmem CORE(
        .clk(testclk),
        .nrst(nrst),
        `ifdef FEATURE_INTERRUPT_ENABLE
		    .int_sig(int_sig),
	    `endif 
        
        .ext_data_write(core_data_write),
        
        .ext_data_addr(core_data_addr),        
        .ext_data_store(core_data_store),
        .ext_data_load(core_data_load),
        .ext_data_req(core_data_request),
        .ext_data_gnt(core_data_grant),
        .ext_data_valid(core_data_valid),
        .ext_data_write_valid(core_data_write_valid),

        `ifdef FEATURE_INST_TRACE_ENABLE
		.ext_if_inst(core_if_inst),
		.ext_id_inst(core_id_inst),
	    `endif
	    
	    .ext_inst_addr(core_inst_addr),
        .ext_inst_data(core_inst_data),
        .ext_OCM_done(core_done)
    );
    wire [31:0] out_tb; 
    reg [`DATAMEM_BITS:0] addr_tb;   
    */

    answerkey_i #() AK();
    
    assign INST = core_if_inst;
        
    //assign box = {AK.memory[con_addr][7:0], AK.memory[con_addr][15:8], AK.memory[con_addr][23:16], AK.memory[con_addr][31:24]};
    assign box = AK.memory[addr_tb >> 2];
    initial begin
        CLK = 0;
    end
    assign L2_addr = (done) ? addr_tb : L2_addr_t;
    genvar i_f;
    integer i_k;

	for (i_f = 0; i_f < NUM_TESTS; i_f++) begin


        localparam string temp_data = $sformatf("%s%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "datamem-dump/mem/", file_pile[i_f]);
        localparam string temp_inst = $sformatf("%s%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "instmem-dump/mem/", file_pile[i_f]);
        localparam string temp_refm = $sformatf("%s%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "answer-keys/mem/", file_pile[i_f]);
        
        initial begin
            suite_done[i_f] = 0;
            
            if (i_f != 0) begin
                while(suite_done[i_f-1] == 0) begin
                    #1000;
                end
            end
            
            current_test = test_pile[i_f];
            i_k = i_f;
            nrst = 0;
            CLK = 0;
            last_inst = 0;
            con_write = 0;
            con_addr = 10'h0;
            addr_tb = 10'h0;
            max_data_addr = 248 * 4;
            con_in = 0;
            done = 0;
            check = 0;
            pass = 0;
            print_metrics = 0;
            i = 0;
            j = 0;
            total_test_cases = 0;
            test_suites_done = 0;
            
            $readmemh(temp_data, memory.ram_block_1);
            $readmemh(temp_data, memory.ram_block_2);
            $readmemh(temp_inst, INSTMEM.instmem);
            $readmemh(temp_refm, AK.memory);
            
            #250;
            nrst = 1;
        end
    end 
   
    // Tracking how many clock cycles it takes to execute the program
	always@(posedge CLK) begin
		if(!nrst) clock_counter <= 0;
		else  if (!test_suites_done) clock_counter <= clock_counter + 1;
	end
    // The following code is for checking the contents
    // of BLOCKMEM
    
    /*
    always@(posedge CLK) begin
         if(!nrst)
            max_data_addr <= 0;
        else if(!done) 
            if(CORE.mem_is_stype || CORE.mem_is_ltype) begin
                
                if (max_data_addr > 255) begin
                    max_data_addr = 256;
                end
                else begin
                
                if (max_data_addr < CORE.mem_ALUout[`DATAMEM_BITS-1:0])
                    max_data_addr <= CORE.mem_ALUout[`DATAMEM_BITS-1:0];
                //end
            end
    end
    */
    
    
    always@(posedge done) begin
        
        $display("%s", test_pile[i_k]);
        $display("---------| SUMMARY |---------");
        $display("Address\t  Actual  \tExpected ");
        $display("=======\t==========\t==========");	
    end
    
    always@(negedge testclk) begin
        if(done) begin	
            /*
            if(out_tb == box) begin
                //$display("0x%3X\t0x%X\t0x%X\tPass", con_addr, con_out, AK.memory[con_addr]);
                pass = pass + 1;
            end else begin
                if (!print_metrics) begin
                    $display("0x%3X\t0x%X\t0x%X\tFail--------------------", addr_tb, out_tb, box);
                    total_error_count = total_error_count + 1;
                end
            end
            */
            // Check L2 Cache first
		    if (tb_hit) begin
		      if (tb_data_cache == box) begin
		          //$display("0x%3X\t0x%X\t0x%X\tCache Hit", addr_tb, tb_data_cache, AK.memory[addr_tb >> 2]);
		          pass = pass + 1;
		      end
		      else begin
		          $display("0x%3X\t0x%X\t0x%X\tCache Fail--------------------", addr_tb, tb_data_cache, box);
		          total_error_count = total_error_count + 1;
		      end
		    end
			else begin 
			// check RAM
                if(out_tb == box) begin
                    //$display("0x%3X\t0x%X\t0x%X\tRAM Pass", addr_tb, out_tb, AK.memory[addr_tb >> 2]);
                    pass = pass + 1;
                end else begin
                    $display("0x%3D\t0x%X\t0x%X\tRAM Fail--------------------", addr_tb, out_tb, box);
                    total_error_count = total_error_count + 1;
                end
            end
            total_test_cases = total_test_cases + 1;
            addr_tb = addr_tb + 4;
            if(addr_tb == max_data_addr) print_metrics = 1;
        end
    end
        
    always@(posedge print_metrics) begin
        $display("Passed %0d/%0d test cases.\n\n", pass, total_test_cases);
        suite_done[i_k] = 1;
        nrst = 0;
        if (i_k == NUM_TESTS - 1) begin
            test_suites_done = 1;
            $display("Error count across %0d tests: %0d. \n\n", NUM_TESTS, total_error_count);
            $display("Total clock cycles across test suite: %0d", clock_counter);
            $finish;
        end
    end 
    
    always@(posedge CLK) begin
	    if (!nrst) begin
	        check = 0;
	        consecutive_nops = 0;
	        last_inst <= 0;
	    end
	    else begin
	       if (active_data_op) begin
                last_inst <= INST;
                consecutive_nops = 0;
                check = 0;
            end
            else if (!done) begin
                if ((last_inst[15:0] == 16'h0001 || last_inst == 32'h13) && (INST[15:0] == 16'h0001 || INST == 32'h13)) begin
                    consecutive_nops = consecutive_nops + 1;
                    check = check + 1;
                end
                else if (INST == last_inst) begin
                    check = check + 1;
                end
                else if (INST == 32'h0) begin
                    check = check;
                end
                else begin
                    last_inst <= INST;
                    consecutive_nops = 0;
                    check = 0;
                end
             end
         end
    end
    // This controls the NOP counter
	always@(posedge CLK) begin
	   if (!done)
            if(!nrst)
                nop_counter <= 0;
            else if(!done)
                if(INST[15:0] == 16'h0001 || INST == 32'h00000013)
                    nop_counter <= nop_counter + 1;
	end
	// This controls the done flag
	always@(posedge CLK) begin
		if(check == 100 || consecutive_nops == 25) done = 1;
	end
	
	 
        
endmodule

// ANSWER KEY
module answerkey_i #(parameter REF_OUT = "answerkey.mem")();
	reg [31:0] memory [0:`DATAMEM_DEPTH-1];
	initial begin
	    for (int i = 0; i < `DATAMEM_DEPTH-1; i++) begin
	       memory[i] = 32'd0;
	    end
		$readmemh(REF_OUT, memory);
	end
endmodule