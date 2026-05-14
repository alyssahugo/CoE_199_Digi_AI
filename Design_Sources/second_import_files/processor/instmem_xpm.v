`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.03.2026 09:23:40
// Design Name: 
// Module Name: instmem_xpm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module instmem_xpm #(
    parameter ADDR_BITS   = 17,
    parameter DATA_WIDTH  = 32,
    parameter MEM_DEPTH   = (1 << ADDR_BITS)
)(
    input  wire                     clk,
    input  wire                     nrst,
    input  wire                     sel_ISR,      // kept for compatibility

    // old core-side interface
    input  wire [ADDR_BITS-1:0]     addr,
    output wire [DATA_WIDTH-1:0]    instruction,

    // old refill interface
    input  wire                     refill_valid,
    input  wire [DATA_WIDTH-1:0]    inst_refill
);

    reg [ADDR_BITS-1:0] refill_pointer;

    wire [DATA_WIDTH-1:0] doutb_unused;
    wire [DATA_WIDTH-1:0] douta_core;


    always @(posedge clk) begin
        if (!nrst) begin
            refill_pointer <= {ADDR_BITS{1'b0}};
        end else begin
            if (refill_valid)
                refill_pointer <= refill_pointer + 1'b1;
        end
    end


    xpm_memory_tdpram #(
        .ADDR_WIDTH_A        (ADDR_BITS),
        .ADDR_WIDTH_B        (ADDR_BITS),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (DATA_WIDTH),
        .BYTE_WRITE_WIDTH_B  (DATA_WIDTH),
        .CASCADE_HEIGHT      (0),
        .CLOCKING_MODE       ("common_clock"),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    ("none"),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (MEM_DEPTH * DATA_WIDTH),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_A   (DATA_WIDTH),
        .READ_DATA_WIDTH_B   (DATA_WIDTH),
        .READ_LATENCY_A      (1),
        .READ_LATENCY_B      (1),
        .READ_RESET_VALUE_A  ("0"),
        .READ_RESET_VALUE_B  ("0"),
        .RST_MODE_A          ("SYNC"),
        .RST_MODE_B          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_EMBEDDED_CONSTRAINT (0),
        .USE_MEM_INIT        (0),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (DATA_WIDTH),
        .WRITE_DATA_WIDTH_B  (DATA_WIDTH),
        .WRITE_MODE_A        ("read_first"),
        .WRITE_MODE_B        ("read_first")
    ) u_instmem_xpm (
        .clka    (clk),
        .rsta    (~nrst),
        .ena     (1'b1),
        .regcea  (1'b1),
        .wea     ({DATA_WIDTH/8{1'b0}}),
        .addra   (addr),
        .dina    ({DATA_WIDTH{1'b0}}),
        .douta   (douta_core),

        .clkb    (clk),
        .rstb    (~nrst),
        .enb     (1'b1),
        .regceb  (1'b1),
        .web     ({DATA_WIDTH/8{refill_valid}}),
        .addrb   (refill_pointer),
        .dinb    (inst_refill),
        .doutb   (doutb_unused),

        .sleep   (1'b0),
        .injectsbiterra (1'b0),
        .injectdbiterra (1'b0),
        .sbiterra (),
        .dbiterra ()
    );

    assign instruction = douta_core;

endmodule
