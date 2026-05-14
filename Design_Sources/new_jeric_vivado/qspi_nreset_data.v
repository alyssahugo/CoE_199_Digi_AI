`timescale 1ns / 1ps

module qspi_data_nreset(
    input  wire nrst,
    input  wire qspi_inst_done,
    input  wire init_calib_complete,
    output wire qspi_data_nrst
);

    assign qspi_data_nrst =
        nrst &
        qspi_inst_done &
        init_calib_complete;

endmodule