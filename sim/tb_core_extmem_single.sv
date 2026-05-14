`timescale 1ns / 1ps

`include "constants.vh"
`include "config.vh"

// #define SIM_BEHAV

module tb_core_extmem_single();
	
	reg CLK;
	wire test_clk = CLK;
	reg nrst;

	reg [`INT_SIG_WIDTH-1:0] int_sig;

	reg [3:0] con_write;
	reg [`DATAMEM_BITS:0] con_addr;
	reg [`WORD_WIDTH-1:0] con_in;
	wire [`WORD_WIDTH-1:0] con_out;

	reg [`WORD_WIDTH-1:0] last_inst;
	
    // localparam string temp_inst = $sformatf("%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "instmem-dump/mem/program_inst.hex");
    localparam string temp_inst = $sformatf("%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "instmem-dump/mem/C-ADD.mem");
    // localparam string temp_data = $sformatf("%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "datamem-dump/mem/program_data.hex");
    localparam string temp_data = $sformatf("%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "datamem-dump/mem/C-ADD.mem");
    localparam string temp_refm = $sformatf("%s%s%s", `REPO_LOCATION, `TEST_LOCATION, "answer-keys/mem/C-ADD.mem");

	//wire [3:0] dmem_data_write;
	//`ifdef FEATURE_BIT_ENABLE
		//wire [`WORD_WIDTH-1:0] core_data_write;
		//assign dmem_data_write = {core_data_write[24], core_data_write[16], core_data_write[8], core_data_write[0]};
	//`else
    wire [3:0] core_data_write;
    wire [3:0] core_cache_data_write;
    wire core_cache_wr;
		//assign dmem_data_write = core_data_write;
	//`endif

    wire [`DATAMEM_BITS-1:0] core_data_addr;
    wire [`DATAMEM_BITS-1:0] core_cache_data_addr;	
    wire [`BUS_BITS-1:0] bus_data_addr = {core_data_addr, 2'b0};	
    wire [`WORD_WIDTH-1:0] core_data_store;	
    wire [`WORD_WIDTH-1:0] core_cache_data_store;
    
    wire [`WORD_WIDTH-1:0] core_data_load;
    //wire [127:0] core_cache_data_load;
    
    wire core_data_request;
    wire core_cache_data_request;
    
    //wire core_data_grant = 1'b1;
    //wire core_data_valid = 1'b1;
        
    wire core_data_grant;
    wire core_data_valid;
    wire core_done;
    wire core_cache_done;
    wire core_data_write_valid;
    
    wire [`EXT_PC_ADDR_BITS-1:0] core_inst_addr;
    wire [`WORD_WIDTH-1:0] core_inst_data;
	wire [`WORD_WIDTH-1:0] core_if_inst;
	wire [`WORD_WIDTH-1:0] core_id_inst;
    
    wire active_data_op = ext_cache_req || ext_noncache_req;
    
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
    wire [31:0] tb_data_cache;
    wire ext_cache_req;
    wire ext_noncache_req;
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
        .clk(test_clk),
        .nrst(nrst),
        .sel_ISR(1'b0),

        .addr({1'b0, core_inst_addr}),
        .instruction(core_inst_data)
    );
    /*
    core_extmem CORE(
        .clk(test_clk),
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
            .clk(test_clk), .nrst(nrst),
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
            .clk(CLK),                 .nrst(nrst),
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
    
    L2_cache_top # (.CACHE_WAY(2), .CACHE_SIZE(128), .ADDR_BITS(`DATAMEM_BITS))
        L2_cache (
            .clk(CLK),          .nrst(nrst),
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
//    bd_dual_testbench_wrapper rv32imc_core_dual (
//            .BRAM_PORTA_0_clk(bram_clk_a),
//            .BRAM_PORTA_0_din(bram_dinA),
//            .BRAM_PORTA_0_dout(bram_doutA),
//            .BRAM_PORTA_0_en(),
//            .BRAM_PORTA_0_rst(),
//            .BRAM_PORTA_0_we(bram_weA),
            
//            .BRAM_PORTB_0_clk(bram_clk_b),
//            .BRAM_PORTB_0_din(bram_dinB),
//            .BRAM_PORTB_0_dout(bram_doutB),
//            .BRAM_PORTB_0_en(),
//            .BRAM_PORTB_0_rst(),
//            .BRAM_PORTB_0_we(bram_weB),
            
            
//            .ext_inst_addr(core_inst_addr),
//            .bram_addr_a(addr_to_memA),
//            .bram_addr_b(addr_to_memB),
//            .clk(CLK),
//            .done_0(done),
//            .ext_id_inst_0(core_id_inst),
//            .ext_if_inst_0(core_if_inst),
//            .ext_inst_data(core_inst_data),
//            .ext_trace_ready_0(),
//            .interrupt_0(),
//            .nrst(nrst),
//            .o_stall_0(),
//            .probe_data_addr(),
//            .probe_datastore(),
//            .rs232_uart_rxd(1'b1),
//            .rs232_uart_txd(),
//            .tb_data_o_0(tb_data_cache),
//            .tb_hit_0(tb_hit),
//            .ext_cache_req(ext_cache_req),
//            .ext_noncache_req(ext_noncache_req)
//    );

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
    wire [31:0] box;
    answerkey_i AK();
    //assign box = {AK.memory[addr_tb][7:0], AK.memory[addr_tb][15:8], AK.memory[addr_tb][23:16], AK.memory[addr_tb][31:24]};
    assign box = AK.memory[addr_tb >> 2];
	always
		#10 CLK = ~CLK;		// 50MHz clock

	// Integers for checking results through the answer key
	integer i, j, check, done, pass, consecutive_nops;
	integer total_test_cases = 0;
	integer print_metrics = 0;

	// Various counters for checking performance of the core
	integer clock_counter, stall_counter, cumulative_stall_counter;
	integer cumulative_flush_counter;
	integer if_clk_counter, id_clk_counter, exe_clk_counter, mem_clk_counter, wb_clk_counter, rf_clk_counter;

	// Counters for checking BHT accuracy for each entry
	reg [31:0] bht_correct [0:`BHT_ENTRY-1];
	reg [31:0] bht_accesses [0:`BHT_ENTRY-1];
	reg [31:0] bht_overwrites [0:(`BHT_ENTRY/4)-1];
	integer total_bht_correct, total_bht_accesses, total_bht_overwrites;

	// Counter for NOPs (base & compressed versions)
	integer nop_counter;

	// Tracking "highest" data address written to for
	// displaying only what's needed in the answer key
	// (since there is no need to display the addresses
	// not written to)
	integer max_data_addr;

	// For checking instructions loaded
    wire [31:0] INST = core_if_inst;

	/********************************
	wire [9:0] data_addr;
	assign data_addr = CORE.mem_ALUout[11:2];
	/********************************/
	
    assign L2_addr = (done) ? addr_tb : L2_addr_t;
	initial begin
		CLK = 0;
		nrst = 0;

		int_sig = 0;
		// BTN = 0;
		// SW = 0;
		last_inst = 0;

		con_write = 0;
		con_addr = 10'h0;
		con_in = 0;

        addr_tb = 0;

		done = 0;
		check = 0;
		pass = 0;
		i = 0;
		j = 0;

		// Initializing counters
		clock_counter = 0;
		if_clk_counter = 0;
		id_clk_counter = 0;
		exe_clk_counter = 0;
		mem_clk_counter = 0;
		wb_clk_counter = 0;
		rf_clk_counter = 0;
		
		$readmemh(temp_data, memory.ram_block_1);
		$readmemh(temp_data, memory.ram_block_2);
        $readmemh(temp_inst, INSTMEM.instmem);
        $readmemh(temp_refm, AK.memory);
        max_data_addr = 256 << 2;
		#100 nrst = 1;
	end
	
	`ifdef SIM_BEHAV
	
	reg [`WORD_WIDTH-1:0] exe_inst, mem_inst, wb_inst;
	always@(posedge CLK) begin
		if(!nrst) begin
			exe_inst <= 0;
			mem_inst <= 0;
			wb_inst <= 0;
		end else begin
			exe_inst <= CORE.id_inst;
			mem_inst <= exe_inst;
			wb_inst <= mem_inst;
		end
	end

	reg [`PC_ADDR_BITS-1:0] mem_PC, wb_PC;
	always@(posedge CLK) begin
		if(!nrst) begin
			mem_PC <= 0;
			wb_PC <= 0;
		end else begin
			mem_PC <= CORE.exe_PC;
			wb_PC <= mem_PC;
		end
	end
	
	`endif

	// Checking for 10 NOPs/50 looping jumps in a row
	// NOTE: checking for last_inst should be done for at least 50 cycles
	// if there are DIV operations running in the processor.
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
	// This controlls the done flag
	always@(posedge CLK) begin
		if(check == 50 || consecutive_nops == 25) done = 1;
	end

	// Tracking how many clock cycles it takes to execute the program
	always@(posedge CLK) begin
		if(!nrst) clock_counter <= 0;
		else if(!done) clock_counter <= clock_counter + 1;
	end
	
	`ifdef SIM_BEHAV

	always@(posedge CORE.if_clk) begin
		if(!nrst) if_clk_counter <= 0;
		else if(!done) if_clk_counter <= if_clk_counter + 1;
	end

	always@(posedge CORE.id_clk) begin
		if(!nrst) id_clk_counter <= 0;
		else if(!done) id_clk_counter <= id_clk_counter + 1;
	end

	always@(posedge CORE.exe_clk) begin
		if(!nrst) exe_clk_counter <= 0;
		else if(!done) exe_clk_counter <= exe_clk_counter + 1;
	end

	always@(posedge CORE.mem_clk) begin
		if(!nrst) mem_clk_counter <= 0;
		else if(!done) mem_clk_counter <= mem_clk_counter + 1;
	end

	always@(posedge CORE.wb_clk) begin
		if(!nrst) wb_clk_counter <= 0;
		else if(!done) wb_clk_counter <= wb_clk_counter + 1;
	end

	always@(posedge CORE.rf_clk) begin
		if(!nrst) rf_clk_counter <= 0;
		else if(!done) rf_clk_counter <= rf_clk_counter + 1;
	end

	// Tracking how many cycles each stall takes
	always@(posedge CLK) begin
		if(!nrst)
			stall_counter <= 0;
		else if(!done)
			if(CORE.if_stall)
				stall_counter <= stall_counter + 1;
			else
				stall_counter <= 0;
	end

	// Tracking total clock cycles the pipeline was stalled
	always@(posedge CLK) begin
		if(!nrst)
			cumulative_stall_counter <= 0;
		else if(!done)
			if(CORE.if_stall)
				cumulative_stall_counter <= cumulative_stall_counter + 1;
	end

	// Tracking total clock cycles "wasted" due to flushing (not counting flushing due to stall conditions)
	always@(posedge CLK) begin
		if(!nrst)
			cumulative_flush_counter <= 0;
		else if(!done)
			if(CORE.ISR_PC_flush || CORE.ISR_pipe_flush || CORE.jump_flush)
				cumulative_flush_counter <= cumulative_flush_counter + 1;
			else if(CORE.branch_flush)
				cumulative_flush_counter <= cumulative_flush_counter + 2;
	end

	// Tracking BHT Accuracy
	// Accesses: id_is_jump = 1 or id_is_btype = 1
	// Correct access: CORE.BRANCHPREDICTOR.feedback = 1
	// Overwrites: if a fifo_counter value overflows
	wire [`BHT_SET_BITS-1:0] id_set = CORE.BRANCHPREDICTOR.id_set;
	wire [`BHT_SET_BITS-1:0] exe_set = CORE.BRANCHPREDICTOR.exe_set;
	wire [1:0] exe_setoffset = CORE.BRANCHPREDICTOR.exe_setoffset;

	always@(posedge CLK)
		if(!nrst) begin
			total_bht_overwrites <= 0;
			total_bht_accesses <= 0;
			total_bht_correct <= 0;
		end

	// This controls bht_accesses & bht_correct for branches & jumps.
	always@(posedge CLK) begin
		if(!nrst) begin
			for(i = 0; i < `BHT_ENTRY; i=i+1) begin
				bht_correct[i] <= 0;
				bht_accesses[i] <= 0;
			end
		end 
		else if(!done) begin
			if(CORE.id_is_btype) begin
				case(CORE.BRANCHPREDICTOR.id_iseqto)
					4'b1000: bht_accesses[{id_set, 2'b11}] <= bht_accesses[{id_set, 2'b11}] + 1;
					4'b0100: bht_accesses[{id_set, 2'b10}] <= bht_accesses[{id_set, 2'b10}] + 1;
					4'b0010: bht_accesses[{id_set, 2'b01}] <= bht_accesses[{id_set, 2'b01}] + 1;
					4'b0001: bht_accesses[{id_set, 2'b00}] <= bht_accesses[{id_set, 2'b00}] + 1;
					4'b0000: bht_accesses[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] <= bht_accesses[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] + 1;
				endcase
			end
			else if(CORE.id_is_jump) begin
				case(CORE.BRANCHPREDICTOR.id_iseqto)
					4'b1000: bht_accesses[{id_set, 2'b11}] <= bht_accesses[{id_set, 2'b11}] + 1;
					4'b0100: bht_accesses[{id_set, 2'b10}] <= bht_accesses[{id_set, 2'b10}] + 1;
					4'b0010: bht_accesses[{id_set, 2'b01}] <= bht_accesses[{id_set, 2'b01}] + 1;
					4'b0001: bht_accesses[{id_set, 2'b00}] <= bht_accesses[{id_set, 2'b00}] + 1;
					4'b0000: bht_accesses[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] <= bht_accesses[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] + 1;
				endcase
				if(CORE.id_jump_in_bht && !CORE.id_sel_opBR)
					case(CORE.BRANCHPREDICTOR.id_iseqto)
						4'b1000: bht_correct[{id_set, 2'b11}] <= bht_correct[{id_set, 2'b11}] + 1;
						4'b0100: bht_correct[{id_set, 2'b10}] <= bht_correct[{id_set, 2'b10}] + 1;
						4'b0010: bht_correct[{id_set, 2'b01}] <= bht_correct[{id_set, 2'b01}] + 1;
						4'b0001: bht_correct[{id_set, 2'b00}] <= bht_correct[{id_set, 2'b00}] + 1;
						4'b0000: bht_correct[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] <= bht_correct[{id_set, CORE.BRANCHPREDICTOR.fifo_counter[id_set]}] + 1;
					endcase
			end
		end
	end

	// This controls bht_correct for branch instructions
	always@(posedge CLK) begin
		if(!done)
			if((|CORE.exe_btype || |CORE.exe_c_btype) && CORE.BRANCHPREDICTOR.is_pred_correct)
				bht_correct[{exe_set, exe_setoffset}] <= bht_correct[{exe_set, exe_setoffset}] + 1;
			else if(CORE.exe_sel_opBR && (CORE.exe_branchtarget == CORE.BRANCHPREDICTOR.exe_loadentry[`BHT_PC_ADDR_BITS+1:2]))
				bht_correct[{exe_set, exe_setoffset}] <= bht_correct[{exe_set, exe_setoffset}] + 1;
	end

	// This controls bht_overwrites, which tracks if a fifo_counter overflows
	// Please check branchpredictor.v code to understand when a counter overflows
	always@(posedge CLK) begin
		if(!nrst)
			for(i=0; i<(`BHT_ENTRY/4); i=i+1)
				bht_overwrites[i] <= 0;
		else if(!done) begin
			if((CORE.id_is_btype || CORE.id_is_jump) && (CORE.BRANCHPREDICTOR.id_iseqto == 4'h0)) begin
				bht_overwrites[id_set] <= bht_overwrites[id_set] + 1;
			end
		end
	end
	
	`endif

	// This controls max_data_addr
	/*
	always@(posedge CLK) begin
        if(!nrst)
            max_data_addr <= 0;
        else if(!done) 
            if(CORE.mem_is_stype || CORE.mem_is_ltype) begin
                
                /*if (max_data_addr > 255) begin
                    max_data_addr = 256;
                end
                else begin
                
                if (max_data_addr < CORE.mem_ALUout[`DATAMEM_BITS-1:0])
                    max_data_addr <= CORE.mem_ALUout[`DATAMEM_BITS-1:0];
                //end
            end
    end
    */
    
	// For simulating int_sig
	// Test interrupts for the following conditions:
	//		+ during "normal operation" -> no stalls
	//		+ during stalls (division)
	//		+ a stall occurs before the ISR executes (load hazard, etc.)
	//		+ while a branch instruction is still in the pipeline before ISR executes
	always@(posedge CLK) begin
		// if(clock_counter == 20) int_sig[0] = 1;
		// if(clock_counter == 55) int_sig[1] = 1;
		// if(clock_counter == 100) int_sig[0] = 0;
		// if(clock_counter == 105) int_sig[1] = 0;

		// if(clock_counter == 213) int_sig[0] = 1;
		// // if(clock_counter == 250) int_sig[0] = 0;

		// if(clock_counter == 239) int_sig[1] = 1;
		// if(clock_counter == 241) int_sig[2] = 1;
		// if(clock_counter == 243) int_sig[2] = 0;

		// if(clock_counter == 460) int_sig[2] = 1;
		// if(clock_counter == 462) int_sig[0] = 0;
		// // if(clock_counter == 500) int_sig[0] = 0;

		// if(clock_counter == 7376) int_sig[3] = 1;
		// if(clock_counter == 7400) int_sig[3] = 0;

		// if(clock_counter == 8000) int_sig = 4'hF;
	end

	// The following code is for checking the contents
	// of BLOCKMEM
	always@(posedge done) begin
		$display("---------| SUMMARY |---------");
		$display("Address\t  Actual  \tExpected ");
		$display("=======\t==========\t==========");	
	end

	always@(negedge CLK) begin
		if(done) begin
		    // Check L2 Cache first
		    if (tb_hit) begin
		      if (tb_data_cache == box) begin
		          $display("0x%3X\t0x%X\t0x%X\tCache Hit", addr_tb, tb_data_cache, AK.memory[addr_tb >> 2]);
		          pass = pass + 1;
		      end
		      else begin
		          $display("0x%3D\t0x%X\t0x%X\tCache Fail--------------------", addr_tb, tb_data_cache, box);
		      end
		    end
			else begin 
			// check RAM
                if(out_tb == box) begin
                    $display("0x%3X\t0x%X\t0x%X\tRAM Pass", addr_tb, out_tb, AK.memory[addr_tb >> 2]);
                    pass = pass + 1;
                end else begin
                    $display("0x%3D\t0x%X\t0x%X\tRAM Fail--------------------", addr_tb, out_tb, box);
                end
            end

			total_test_cases = total_test_cases + 1;
			if(addr_tb == max_data_addr) print_metrics = 1;
			addr_tb = addr_tb + 4;
		end
	end
	
	`ifdef SIM_BEHAV

	// Since Vivado/Verilog can't handle nested FOR loops well, this part
	// was split off into its own task. Ideally, it would be within the for loop
	// below, but Vivado doesn't display each entry correctly.
	task bht_entry_display();
		begin
			$display("Entry %0d: %0d passed/%0d accesses\tAccuracy: %f%%.", 0, bht_correct[{i[3:0], 2'b00}], bht_accesses[{i[3:0], 2'b00}], 100*($itor(bht_correct[{i[3:0], 2'b00}])/$itor(bht_accesses[{i[3:0], 2'b00}])) );
			$display("Entry %0d: %0d passed/%0d accesses\tAccuracy: %f%%.", 1, bht_correct[{i[3:0], 2'b01}], bht_accesses[{i[3:0], 2'b01}], 100*($itor(bht_correct[{i[3:0], 2'b01}])/$itor(bht_accesses[{i[3:0], 2'b01}])) );
			$display("Entry %0d: %0d passed/%0d accesses\tAccuracy: %f%%.", 2, bht_correct[{i[3:0], 2'b10}], bht_accesses[{i[3:0], 2'b10}], 100*($itor(bht_correct[{i[3:0], 2'b10}])/$itor(bht_accesses[{i[3:0], 2'b10}])) );
			$display("Entry %0d: %0d passed/%0d accesses\tAccuracy: %f%%.", 3, bht_correct[{i[3:0], 2'b11}], bht_accesses[{i[3:0], 2'b11}], 100*($itor(bht_correct[{i[3:0], 2'b11}])/$itor(bht_accesses[{i[3:0], 2'b11}])) );
		end
	endtask
	
	`endif
	
	always@(posedge print_metrics) begin
		i = 0;
		j = 0;
		done = 0;
		$display("\n");
		if(check == 50) i = 50;
		else i = 10;
		$display("Passed %0d/%0d test cases.\nClock cycles: %0d", pass, total_test_cases, clock_counter-i);
		`ifdef SIM_BEHAV
		$display("Total cycles stalled: %0d", cumulative_stall_counter);
		$display("Total cycles flushed: %0d", cumulative_flush_counter);
		$display("Total NOPs: %0d", nop_counter);
		$display("=================\n");

		// Clock gating counters
		// Some counters subtracted by i to compensate for check & consecutive_nops
		$display("---| Clock Gating Metrics |---");
		$display("PC clock: %0d/%0d cycles", if_clk_counter-i, clock_counter-i);
		$display("IF/ID clock: %0d/%0d cycles", id_clk_counter-i, clock_counter-i);
		$display("ID/EXE clock: %0d/%0d cycles", exe_clk_counter, clock_counter-i);
		$display("EXE/MEM & DATAMEM clock: %0d/%0d cycles", mem_clk_counter, clock_counter-i);
		$display("MEM/WB clock: %0d/%0d cycles", wb_clk_counter, clock_counter-i);
		$display("Regfile clock: %0d/%0d cycles", rf_clk_counter, clock_counter-i);
		$display("Ungated clock: %0d/%0d cycles", clock_counter-i, clock_counter-i);
		$display("=================\n");
		
		// Computing BHT metrics
		// If check == 50, an infinite loop executed for 50 times.
		// So if the BHT accesses seems much higher than expected,
		// it's probably due to this.
		for(j = 0; j < `BHT_ENTRY; j = j + 1) begin
			total_bht_correct = total_bht_correct + bht_correct[j];
			total_bht_accesses = total_bht_accesses + bht_accesses[j];
		end

		for(j = 0; j < (`BHT_ENTRY/4); j = j+1) begin
			if(bht_overwrites[j] > 3) total_bht_overwrites = total_bht_overwrites + (bht_overwrites[j] - 3);
		end

		$display("---| BHT Performance Metrics |---");
		$display("BHT Entries: %0d.", `BHT_ENTRY);
		$display("Precision: %0d passed/%0d accesses.", total_bht_correct, total_bht_accesses);
		$display("Accuracy: %f%%.", 100*($itor(total_bht_correct)/$itor(total_bht_accesses)));
		$display("Overwrites done: %0d.", total_bht_overwrites);
		/* $display("---| Per-set Metrics |---");
		for(i = 0; i < (`BHT_ENTRY/4); i = i + 1) begin
			if(bht_overwrites[i] > 3) $display("Set: %0d\tOverwrites: %0d", i, bht_overwrites[i] - 3);
			else $display("Set: %0d\tOverwrites: 0", i);
			bht_entry_display();
			$display("------");
		end */	
		`endif
		$finish;
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