`timescale 1ns / 1ps

module External_Request (
    input wire clk,
    input wire nrst,
    input wire [1:0] MESI_in_hold,   // carries address MESI state
    
    input wire snoop_hit_read,       // Snoop hit due to a read
    input wire snoop_hit_write,      // Snoop hit due to a write
    input wire scu_req_in,           // Signal for external snoop request handling

    output reg response,             // 1 if core has valid data pertaining to the external request
    output reg [1:0] MESI_state,          // 2-bit state: 00 = Invalid, 01 = Shared, 10 = Exclusive, 11 = Modified
    output reg invalidate,
    output reg shared
);

    // State encoding
    // Changed this to match the Tag Array
    localparam INVALID   = 2'b00;
    localparam SHARED    = 2'b01;
    localparam EXCLUSIVE = 2'b11;
    localparam MODIFIED  = 2'b10;

    reg [1:0] next_state;
    reg snoop_int;
    always @ (posedge clk) begin
        if (!nrst) begin
            MESI_state <= INVALID;
            //snoop <= 0;
            invalidate <= 0;
            shared <= 0;
            response <= 0;
        end
        else 
            MESI_state <= next_state;
    end

    // Combinational logic: External snoop request handling
    always @(*) begin
        if (scu_req_in) begin
            snoop_int = 1'b1;
            
            case (MESI_in_hold)
                SHARED: begin
                    if (snoop_hit_write) begin
                        invalidate = 1; // Snoop hit write
                        shared = 0;
                    end
                    response <= 1;
                end

                EXCLUSIVE: begin
                    if (snoop_hit_read) begin
                        shared = 1; // Snoop hit read
                        invalidate = 0;
                    end else if (snoop_hit_write) begin
                        invalidate = 1; // Snoop hit write
                        shared = 0;
                    end
                    response <= 1;
                end

                MODIFIED: begin
                    if (snoop_hit_read) begin
                        // Actually if write back dapat mag flush muna eh
                        // since write through naman, oks lang
                        // pero if MODIFIED -> automatic na mapupunta sa SHARED via Tag Array
                        shared = 1; // Snoop hit read
                        invalidate = 0;
                    end else if (snoop_hit_write) begin
                        invalidate = 1; // Snoop hit write
                        shared = 0;
                    end
                    response <= 0;
                end

                default: begin
                    shared = 0;
                    invalidate = 0;
                    response = 0;
                    
                end  // Default case
            endcase
        end
    end

endmodule
