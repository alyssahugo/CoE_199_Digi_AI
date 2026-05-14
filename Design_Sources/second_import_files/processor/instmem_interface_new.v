`timescale 1ns / 1ps

`include "constants.vh"

module instmem_interface_new (
    input clk,
    input nrst,

    input if_stall,
    input if_flush,
    input id_stall,
    input id_flush,
    
    input [`PC_ADDR_BITS-1:0] if_pc4,
    input [`PC_ADDR_BITS-1:0] if_pcnew,
    input branch,
    
    output [`PC_ADDR_BITS-1:0] if_pc_out,
    output [`PC_ADDR_BITS-1:0] id_pc_out,
    output [`PC_ADDR_BITS-1:0] id_pc4,
    output ready,
    output [`WORD_WIDTH-1:0] if_inst,
    output [`WORD_WIDTH-1:0] id_inst,
    
    input [`WORD_WIDTH-1:0] inst_data,
	output [`PC_ADDR_BITS-1:0] inst_addr
    );

    wire [`PC_ADDR_BITS-1:0] inst_addr_t;
    assign inst_addr = {2'b0, inst_addr_t[`PC_ADDR_BITS-1:2]};

    pipereg_if_id IF_ID(
		.clk(clk),
		.nrst(nrst),

		.flush(id_flush),
		.stall(if_stall),

		.if_pc4(if_pc4), 	.id_pc4(id_pc4),
		.if_inst(if_inst), 	.id_inst(id_inst),
		.if_PC(if_pc_out), 		.id_PC(id_pc_out)
	);

    wire t_hold;
    wire t_comp;
    wire t_reissue;
    wire t_issue;
    wire t_align;

    im_issue if_i(
        .clk(clk),
        .nrst(nrst),

        .dispatch_hold(t_hold),
        .dispatch_comp(t_comp),
        .dispatch_reissue(t_reissue),
        .dispatch_issue(t_issue),

        .addr_in(if_pcnew),
        .addr_out(inst_addr_t),
        .dispatch_addr(if_pc_out),
        .align(t_align)
    );

    im_dispatch if_d(
        .clk(clk),
        .nrst(nrst),
        .stall(id_stall),
        .align(t_align),
        
        .hold(t_hold),
        .comp(t_comp),
        .reissue(t_reissue),
        .issue(t_issue),
        .ready(ready),

        .inst_in(inst_data),
        .inst_out(if_inst)
    );
    
endmodule

module im_issue(
    input clk,
    input nrst,

    input dispatch_hold,
    input dispatch_comp,
    input dispatch_reissue,
    output reg dispatch_issue,

    input [`PC_ADDR_BITS-1:0] addr_in,
    output reg [`PC_ADDR_BITS-1:0] addr_out,
    output reg [`PC_ADDR_BITS-1:0] dispatch_addr,
    output align
);

    assign align = addr_out[1];

    reg last_comp;
    reg push_comp;

    always@(posedge clk) begin
        if (!nrst) begin
            dispatch_addr <= 0;
            addr_out <= 0;
            dispatch_issue <= 0;
            last_comp <= 0;
            push_comp <= 0;
        end

        else begin
            if (dispatch_hold) begin
                dispatch_addr <= dispatch_addr;
                addr_out <= addr_out;
                dispatch_issue <= 1;
                last_comp <= 0;
                push_comp <= push_comp;
            end
            else begin
                dispatch_issue <= 1;
                last_comp <= dispatch_comp;
                
                if (dispatch_comp) begin
                    push_comp <= ~push_comp;
                    if (push_comp)
                        addr_out <= addr_out;
                    else
                        addr_out <= addr_out + `PC_ADDR_BITS'd4;
                end
                else begin
                    push_comp <= push_comp;
                    addr_out <= addr_out + `PC_ADDR_BITS'd4;
                end
                // determine true address for instruction
                if (last_comp == dispatch_comp)
                    dispatch_addr <= addr_out;
                else if (last_comp)
                    dispatch_addr <= addr_out + `PC_ADDR_BITS'd2;
                else
                    dispatch_addr <= addr_out - `PC_ADDR_BITS'd2;
            end
        end
    end

endmodule

module im_dispatch(
    input clk,
    input nrst,
    input stall,
    input align,
    
    output hold,
    output comp,
    output reissue,
    input issue,
    output ready,

    input [`WORD_WIDTH-1:0] inst_in,
    output [`WORD_WIDTH-1:0] inst_out
);

    reg [`WORD_WIDTH/2-1:0] inst_1;
    reg [`WORD_WIDTH/2-1:0] inst_0;

    reg [`WORD_WIDTH-1:0] last_inst;
    reg [`WORD_WIDTH-1:0] inst_buffer;
    reg fill;
    reg hold_reg;
    reg stall_hold;

    assign comp = (inst_0[1:0] != 2'h3) && issue;
    assign reissue = align && ~comp && ~fill && issue;
    assign ready = issue && ~reissue;
    assign hold = (comp && fill) || stall;

    always@(*) begin
        if (stall_hold) begin
            inst_1 = last_inst[31:16];
            inst_0 = last_inst[15:0];
        end
        else begin
            if (hold_reg) begin
                inst_1 = inst_buffer[31:16];
                inst_0 = inst_buffer[15:0];
            end
            else begin
                if (fill) begin
                    inst_1 = inst_in[15:0];
                    inst_0 = inst_buffer[31:16];
                end
                else begin
                    inst_1 = inst_in[31:16];
                    inst_0 = inst_in[15:0];
                end  
            end
        end
    end

    wire [`WORD_WIDTH-1:0] inst_out_t = {inst_1, inst_0};
    
    assign inst_out = stall_hold ? last_inst : inst_out_t;
    
    
    always@(posedge clk) begin
        if (!nrst) begin
            last_inst <= 0;
            inst_buffer <= 0;
            fill <= 0;
            hold_reg <= 0;
            stall_hold <= 0;
        end
        else begin
            last_inst <= inst_out_t;
            inst_buffer <= inst_in;
            fill <= fill ^ comp;
            hold_reg <= hold;
            stall_hold <= stall;
        end
    end


endmodule