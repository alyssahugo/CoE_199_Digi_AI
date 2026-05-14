`timescale 1ns / 1ps

module DCache_Request (
    input wire clk,
    input wire nrst,
    input wire read,                 // Read signal (1 = read, 0 = write)
    input write,
    input wire hit,                  // Hit signal (1 = hit, 0 = miss)
    input wire [1:0] MESI_in_hold,   // carries address MESI state
    
    input wire ccu_req_in,           // Signal for internal state transitions and snoop handling
    input wire data_check,           // Response from another cache (1 = has data, 0 = no data)
    
    output reg snoop,                //to dcache controller for snoop_complete
    output reg [1:0] MESI_state,          // state: 00 = Invalid, 01 = Shared, 10 = Exclusive, 11 = Modified
    
    output reg data_request,       // Response to snoop check (1 = has data, 0 = no data)
    output reg snoop_hit_read_out,   // Snoop read hit indication
    output reg snoop_hit_write_out,  // Snoop write hit indication
    output reg scu_req_out,       // Snoop request output for external handling
    output reg mem_req_out,
    
    output reg exclusive             // Signal the Tag Array to change state to exclusive
);

    // State encoding
    localparam INVALID   = 2'b00;
    localparam SHARED    = 2'b01;
    localparam EXCLUSIVE = 2'b10;
    localparam MODIFIED  = 2'b11;

    reg [1:0] next_state;
    reg snoop_int;
    reg scu_req_out_int; // Indicates that this cache is requesting a snoop check
    reg data_req_int;

    // Sequential logic: Update state and handle reset
    always @(*) begin
        if (!nrst) begin
            MESI_state <= INVALID;
            data_request <= 0;
            snoop_hit_read_out <= 0;
            snoop_hit_write_out <= 0;
            scu_req_out <= 0;
            snoop <= 0;
        end else begin
            MESI_state <= next_state;
            scu_req_out <= scu_req_out_int;
            snoop <= snoop_int;
            data_request <= data_req_int;
        end
    end
    

    // Sequential logic: Request from DCache Controller (handled on posedge clk)
    always @(posedge clk) begin
        if (!nrst) exclusive <= 0;
        if (ccu_req_in) begin
            scu_req_out_int <= 0; // Default value
            snoop_int <= 0;           // Default snoop response inactive
            data_req_int <= 0;
            
            case (MESI_in_hold)
                INVALID: begin
                    
                    if (read && !hit) begin
                        data_req_int <= 1;
                        if (data_check) begin
                            next_state <= SHARED; // Transition to SHARED if another cache has the data
                            scu_req_out_int <= 1;
                            snoop_hit_read_out <= 1;
                            snoop_int <= 1;
                        end else begin
                            next_state <= EXCLUSIVE; // Transition to EXCLUSIVE if no other cache has the data
                            exclusive <= 1;
                            mem_req_out <= 1;
                            snoop_int <= 1;
                        end
                    end else if (write && !hit) begin
                        next_state <= MODIFIED; // Write miss
                        scu_req_out_int <= 1;
                        snoop_hit_write_out <= 1;
                        snoop_int <= 1;
                    end
                end

                SHARED: begin
                    if (write && hit) begin
                        next_state <= MODIFIED; // Write hit
                        scu_req_out_int <= 1;
                        snoop_hit_write_out <= 1;
                        snoop_int <= 1;
                    end else begin
                        next_state <= SHARED;
                        snoop_int <= 1;
                    end
                    if (!data_check && read) begin
                        exclusive <= 1;
                    end
                    if (write) exclusive <= 0;
                end

                EXCLUSIVE: begin
                    if (write && hit) begin
                        next_state <= MODIFIED; // Write hit
                        scu_req_out_int <= 1;
                        snoop_hit_write_out <= 1;
                        snoop_int <= 1;
                    end
                    if (write) exclusive <= 0;
                end

                MODIFIED: begin
                    // Stay in MODIFIED on read or write hit
                    next_state <= MODIFIED;
                    exclusive <= 0;
                    //
                end

                default: begin
                    next_state <= INVALID; // Default to INVALID
                    exclusive <= 0;
                end
            endcase
        end else begin
            exclusive <= 0;
        end
    end

endmodule
