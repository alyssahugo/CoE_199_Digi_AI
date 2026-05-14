//`timescale 1ns / 1ps

//module new_instmem
//#(
//    parameter ADDR_BITS = 16
//)
//(
//    input  wire                 clk,
//    input  wire                 nrst,
//    input  wire                 sel_ISR,      // kept for compatibility

//    // old core-side interface
//    input  wire [ADDR_BITS-1:0] addr,
//    output wire [31:0]          instruction,

//    // old refill interface
//    input  wire                 refill_valid,
//    input  wire [31:0]          inst_refill,

//    // BRAM Port A (write side)
//    output wire                 bram_ena,
//    output wire                 bram_wea,
//    output wire [ADDR_BITS-1:0] bram_addra,
//    output wire [31:0]          bram_dina,

//    // BRAM Port B (read side)
//    output wire                 bram_enb,
//    output wire [ADDR_BITS-1:0] bram_addrb,
//    input  wire [31:0]          bram_doutb
//);

//    reg [ADDR_BITS-1:0] refill_pointer;

//    // old-like refill behavior
//    always @(posedge clk) begin
//        if (!nrst) begin
//            refill_pointer <= {ADDR_BITS{1'b0}};
//        end else begin
//            if (refill_valid)
//                refill_pointer <= refill_pointer + 1'b1;
//        end
//    end

//    // write side toward BRAM
//    assign bram_ena   = refill_valid;
//    assign bram_wea   = refill_valid;
//    assign bram_addra = refill_pointer;
//    assign bram_dina  = inst_refill;

//    // read side toward BRAM
//    assign bram_enb   = 1'b1;
//    assign bram_addrb = addr;

//    // runtime instruction return
//    assign instruction = bram_doutb;

//endmodule



`timescale 1ns / 1ps

module new_instmem
#(
    parameter ADDR_BITS = 16
)
(
    input  wire                 clk,
    input  wire                 nrst,
    input  wire                 sel_ISR,      // kept only for compatibility

    // Old core-side interface
    input  wire [ADDR_BITS-1:0] addr,
    output wire [31:0]          instruction,

    // Old refill interface
    input  wire                 refill_valid,
    input  wire [31:0]          inst_refill,

    // BRAM Port A (write side)
    output wire                 bram_ena,
    output wire                 bram_wea,
    output wire [ADDR_BITS-1:0] bram_addra,
    output wire [31:0]          bram_dina,

    // BRAM Port B (read side)
    output wire                 bram_enb,
    output wire [ADDR_BITS-1:0] bram_addrb,
    input  wire [31:0]          bram_doutb
);

    reg [ADDR_BITS-1:0] refill_pointer;
    reg [ADDR_BITS-1:0] addr_r;

    // -----------------------------
    // Old-like internal refill pointer
    // -----------------------------
    always @(posedge clk) begin
        if (!nrst) begin
            refill_pointer <= {ADDR_BITS{1'b0}};
        end else begin
            if (refill_valid)
                refill_pointer <= refill_pointer + 1'b1;
        end
    end

    // -----------------------------
    // Read-side address phasing
    // This is the important change:
    // register the incoming fetch address before driving BRAM Port B
    // -----------------------------
    always @(posedge clk) begin
        if (!nrst) begin
            addr_r <= {ADDR_BITS{1'b0}};
        end else begin
            addr_r <= addr;
        end
    end

    // -----------------------------
    // BRAM write side
    // -----------------------------
    assign bram_ena   = refill_valid;
    assign bram_wea   = refill_valid;
    assign bram_addra = refill_pointer;
    assign bram_dina  = inst_refill;

    // -----------------------------
    // BRAM read side
    // Keep Port B always enabled
    // -----------------------------
    assign bram_enb   = 1'b1;
    assign bram_addrb = addr_r;

    // -----------------------------
    // Instruction return to core
    // No extra output register here yet
    // -----------------------------
    assign instruction = bram_doutb;

endmodule