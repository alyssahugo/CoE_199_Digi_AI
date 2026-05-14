`timescale 1ns / 1ps

`include "constants.vh"
`include "config.vh"

// #define SIM_BEHAV

module tb_core_extmem_benchmark();
	
	reg CLK;
	wire test_clk = CLK;
	reg nrst;

	reg [`INT_SIG_WIDTH-1:0] int_sig;

	reg [3:0] con_write;
	reg [`DATAMEM_BITS:0] con_addr;
	reg [`WORD_WIDTH-1:0] con_in;
	wire [`WORD_WIDTH-1:0] con_out;

	reg [`WORD_WIDTH-1:0] last_inst;
    
	localparam string out_data = "T:/Files/Projects/RV32IMC-Repo-GitlabF/pipelined-RV32IMC-1/out.mem";
    localparam string temp_inst = "T:/Files/Projects/RV32IMC-Repo-GitlabF/pipelined-RV32IMC-1/test_instmem.mem";
    localparam string temp_data = "T:/Files/Projects/RV32IMC-Repo-GitlabF/pipelined-RV32IMC-1/test_datamem.mem";
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
    wire core_data_grant = 1'b1;
    wire core_data_valid = 1'b1;
    
    wire [`EXT_PC_ADDR_BITS-1:0] core_inst_addr;
    wire [`WORD_WIDTH-1:0] core_inst_data;
	wire [`WORD_WIDTH-1:0] core_if_inst;
	wire [`WORD_WIDTH-1:0] core_id_inst;
    
    wire active_data_op = core_data_request;
    
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
    
    instmem INSTMEM (
        .clk(test_clk),
        .nrst(nrst),
        .sel_ISR(1'b0),

        .addr({1'b0, core_inst_addr}),
        .inst(core_inst_data)
    );
    
    core_extmem CORE(
        .clk(test_clk),
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

        `ifdef FEATURE_INST_TRACE_ENABLE
		.ext_if_inst(core_if_inst),
		.ext_id_inst(core_id_inst),
	    `endif
	    
	    .ext_inst_addr(core_inst_addr),
        .ext_inst_data(core_inst_data)
    );

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

	reg [`DATAMEM_BITS-1:0] last_buf_word;
	reg [1:0] last_buf_byte;
	wire [`BUS_BITS-1:0] last_buf_addr = {last_buf_word, last_buf_byte};
	
	wire [`DATAMEM_BITS-1:0] curr_buf_word = core_data_addr;
	reg [1:0] curr_buf_byte;
	wire [`BUS_BITS-1:0] curr_buf_addr = {curr_buf_word, curr_buf_byte};
	
	reg [7:0] next_char;
	reg [7:0] buff_char;

	always@(*) begin
		case(dmem_data_write)
			4'h8: begin
				curr_buf_byte = 2'd0;
				next_char = core_data_store[31:24];
			end
			4'h4: begin
				curr_buf_byte = 2'd1;
				next_char = core_data_store[23:16];
			end
			4'h2: begin
				curr_buf_byte = 2'd2;
				next_char = core_data_store[15:8];
			end
			4'h1: begin
				curr_buf_byte = 2'd3;
				next_char = core_data_store[7:0];
			end
			4'hC: begin
				curr_buf_byte = 2'd0;
				next_char = 0;
			end
			4'h3: begin
				curr_buf_byte = 2'd2;
				next_char = 0;
			end
			4'hF: begin
				curr_buf_byte = 2'd0;
				next_char = 0;
			end
			default: begin
				curr_buf_byte = 2'd0;
				next_char = 0;
			end
		endcase
	end

	always@(posedge CLK) begin
		last_buf_word <= curr_buf_word;
		last_buf_byte <= curr_buf_byte;
		if (active_data_op && curr_buf_addr > 15'h21FF && last_buf_addr != curr_buf_addr) begin
		      $write("%c", next_char);
		      buff_char <= next_char;
		end
	end

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
		
		$readmemh(temp_data, DATAMEM.COREMEM.ram_block);
        $readmemh(temp_inst, INSTMEM.instmem);

		#100 nrst = 1;
	end

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
		if(check == 50 || consecutive_nops == 8) done = 1;
	end

	// Tracking how many clock cycles it takes to execute the program
	always@(posedge CLK) begin
		if(!nrst) clock_counter <= 0;
		else if(!done) clock_counter <= clock_counter + 1;
	end

	// This controls max_data_addr
	always@(posedge CLK) begin
        if(!nrst)
            max_data_addr <= 0;
        else if(!done) 
            if(core_data_request) begin
                /*
                if (max_data_addr > 255) begin
                    max_data_addr = 256;
                end
                else begin
                */
                if (max_data_addr < core_data_addr[`DATAMEM_BITS-1:2])
                    max_data_addr <= core_data_addr[`DATAMEM_BITS-1:2];
                //end
            end
    end
	
	always@(posedge done) begin
		i = 0;
		j = 0;
		done = 0;
		$display("\n");
		if(check == 50) i = 50;
		else i = 10;
		$display("Finished test.");
		$writememh(out_data, DATAMEM.COREMEM.ram_block);
		$finish;
	end
	
endmodule