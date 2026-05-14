`timescale 1ns / 1ps

`include "constants.vh"

module instmem_interface (
    input clk,
    input nrst,

    input if_stall,
    input if_flush,
    input id_stall,
    input id_flush,
    
    input [`PC_ADDR_BITS-1:0] if_pc4,
    input [`PC_ADDR_BITS-1:0] if_pcnew,
    input branch,
    
    output reg [`PC_ADDR_BITS-1:0] if_pc_out,
    output [`PC_ADDR_BITS-1:0] id_pc_out,
    output [`PC_ADDR_BITS-1:0] id_pc4,
    output ready,
    output [`WORD_WIDTH-1:0] if_inst,
    output [`WORD_WIDTH-1:0] id_inst,
    
    input [`WORD_WIDTH-1:0] inst_data,
	output [`PC_ADDR_BITS-1:0] inst_addr
    );

    pipereg_if_id IF_ID(
		.clk(clk),
		.nrst(nrst),

		.flush(id_flush),
		.stall(if_stall),

		.if_pc4(if_pc4), 	.id_pc4(id_pc4),
		.if_inst(if_inst), 	.id_inst(id_inst),
		.if_PC(if_pc_out), 		.id_PC(id_pc_out)
	);
    
    reg [2:0] state;
    reg filled;
    
    reg [`WORD_WIDTH/2-1:0] comp_buffer;
    reg [`WORD_WIDTH/2-1:0] jump_buffer;
    wire align_branch = if_pcnew[1];
    wire align = if_pc_out[1];
    reg align_reg;
    
    reg [`PC_ADDR_BITS-1:0] addr_next;
    assign inst_addr = {2'b0, addr_next[`PC_ADDR_BITS-1:2]};
    
    reg in_branch;
    
    reg ready_reg;
    assign ready = ready_reg;
    reg [`WORD_WIDTH-1:0] if_inst_reg;
    assign if_inst = if_inst_reg;
    wire [15:0] inst_lo16 = align ? comp_buffer : inst_data[15:0];
    wire [15:0] inst_hi16 = align ? inst_data[15:0] : inst_data[31:16]; 
    wire inst_compressed = inst_lo16[1:0] != 2'd3;
    wire misalign_in_compressed = inst_data[17:16] != 2'd3;
	
	always@(posedge clk) begin
	   if (!nrst) begin
	       comp_buffer <= 16'd0;
	       jump_buffer <= 16'd0;
           if_pc_out <= 32'd0;
           state <= 3'd0;
           filled <= 1'b0;
           in_branch <= 0;
	   end
	   else begin
            if (id_stall) begin
                comp_buffer <= comp_buffer;
                jump_buffer <= jump_buffer;
                if_pc_out <= if_pc_out;
                filled <= filled;   
                in_branch <= in_branch;
            end
            else begin
                case(state)
                    // Default state
                    3'd0: begin
                        case ({branch, in_branch})
                            // regular instruction
                            2'b00: begin
                                in_branch <= 0;
                                comp_buffer <= inst_data[31:16];
                                jump_buffer <= 16'd0;
                                if_pc_out <= if_pcnew;
                                state <= 3'd0;
                                filled <= (align ^ inst_compressed);
                            end
                            // regular instruction after branch
                            2'b01: begin
                                in_branch <= 0;
                                comp_buffer <= inst_data[31:16];
                                jump_buffer <= 16'd0;
                                if_pc_out <= if_pcnew;
                                state <= 3'd0;
                                filled <= (align ^ inst_compressed);
                            end
                            // start control flow instruction
                            2'b10: begin
                                state <= 3'd0;
                                if (align_branch) begin
                                    // Branch into misaligned instruction!
                                    // check lowest two bits of first halfword
                                    if (misalign_in_compressed) begin
                                        // 16-bit instruction
                                        // affected by jump_flush --> resolve on next cycle
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b1; 
                                    end
                                    else begin
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 1;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= inst_data[15:0];  
                                        filled <= 1'b1; 
                                    end
                                end
                                else begin
                                    // check lowest two bits instead
                                    if (inst_data[1:0] == 2'd3) begin
                                        // word-aligned 32-bit instruction
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= 16'd0;
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b0;
                                    end
                                    else begin
                                        // word-aligned 16-bit instruction 
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b1; 
                                    end
                                end
                            end
                            // control flow instruction into another control flow instruction
                            2'b11: begin
                                state <= 3'd0;
                                if (align_branch) begin
                                    // Branch into misaligned instruction!
                                    // check lowest two bits of first halfword
                                    if (misalign_in_compressed) begin
                                        // 16-bit instruction
                                        // affected by jump_flush --> resolve on next cycle
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b1; 
                                    end
                                    else begin
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 1;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= inst_data[15:0];  
                                        filled <= 1'b1; 
                                    end
                                end
                                else begin
                                    // check lowest two bits instead
                                    if (inst_data[1:0] == 2'd3) begin
                                        // word-aligned 32-bit instruction
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= 16'd0;
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b0;
                                    end
                                    else begin
                                        // word-aligned 16-bit instruction 
                                        if_pc_out <= if_pcnew;
                                        in_branch <= 0;
                                        comp_buffer <= inst_data[31:16];
                                        jump_buffer <= 16'd0;
                                        filled <= 1'b1; 
                                    end
                                end
                            end
                        endcase
                    end
                    // Reset
                    default: begin
                        comp_buffer <= 16'd0;
                        jump_buffer <= 16'd0;
                        if_pc_out <= 32'd0;
                        state <= 3'd0;
                        filled <= 1'b0;
                        in_branch <= 0;
                    end
                endcase
            end
        end
	end
	
	// data outputs
    always@(*) begin
        if (branch) begin
            addr_next = if_pcnew;
            if_inst_reg = inst_data;
            // entering control flow instruction
            if (align_branch && !misalign_in_compressed) begin
                // misaligned word fetch needed
                ready_reg = 0;
            end
            else begin
                // no misaligned word fetch
                ready_reg = 1;
            end      
        end
        else if (in_branch) begin
            addr_next = if_pc_out + 32'd4;
            ready_reg = 1;
            if_inst_reg = {inst_hi16, inst_lo16};
        end
        
        else begin
            // regular instruction
            if (!align || inst_compressed) begin
                // word-aligned instruction
                addr_next = if_pc_out;
                ready_reg = 1;
            end
            else begin
                // non-word-aligned instruction
                if (filled) begin
                    addr_next = if_pc_out + 32'd4;
                    ready_reg = 1;
                end
                else begin
                    addr_next = if_pc_out;
                    ready_reg = 0;
                end 
            end
            if_inst_reg = {inst_hi16, inst_lo16};
         end
     end
endmodule