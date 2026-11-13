`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// aegis_chip : padded chip top for Aegis (__PDK_180NM__, __IOPAD_FAMILY__ __METAL_STACK__ I/O library)
//
//   * Every top-level signal goes through a __IOPAD_FAMILY__ pad cell.
//       clk          : IO_PAD_CELL  (CMOS input)
//       other inputs : IO_PAD_CELL  (Schmitt-trigger CMOS input)
//       outputs      : IO_PAD_CELL  (4x CMOS output)
//   * Power/ground, corner and filler pads are physical-only cells placed
//     in Innovus (pvdi/pv0i core supply, pvda/pv0a I/O supply, IO_CORNER_CELL,
//     pfeed*). They are written into the LVS netlist at export time.
//   * rst is synchronised (async assert, sync de-assert). test_mode
//     bypasses the synchroniser so scan has direct reset control.
//   * scan_enable/scan_in/scan_out are hooked to scan chains by Genus DFT.
// ---------------------------------------------------------------------------
module aegis_chip (
    input  wire       clk,
    input  wire       rst,
    input  wire       spi_sck,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output wire       spi_miso,
    input  wire       test_mode,
    input  wire       scan_enable,
    input  wire [3:0] scan_in,
    output wire [3:0] scan_out
);
    // core-side pad nets
    wire clk_c, rst_c, sck_c, csn_c, mosi_c, miso_c, tm_c, se_c;
    wire [3:0] si_c;
    wire [3:0] so_c;

    // ---------------- input pads ----------------
    IO_PAD_CELL u_pad_clk       (.PAD(clk),         .CIN(clk_c));
    IO_PAD_CELL u_pad_rst       (.PAD(rst),         .CIN(rst_c));
    IO_PAD_CELL u_pad_spi_sck   (.PAD(spi_sck),     .CIN(sck_c));
    IO_PAD_CELL u_pad_spi_cs_n  (.PAD(spi_cs_n),    .CIN(csn_c));
    IO_PAD_CELL u_pad_spi_mosi  (.PAD(spi_mosi),    .CIN(mosi_c));
    IO_PAD_CELL u_pad_test_mode (.PAD(test_mode),   .CIN(tm_c));
    IO_PAD_CELL u_pad_scan_en   (.PAD(scan_enable), .CIN(se_c));
    IO_PAD_CELL u_pad_scan_in0  (.PAD(scan_in[0]),  .CIN(si_c[0]));
    IO_PAD_CELL u_pad_scan_in1  (.PAD(scan_in[1]),  .CIN(si_c[1]));
    IO_PAD_CELL u_pad_scan_in2  (.PAD(scan_in[2]),  .CIN(si_c[2]));
    IO_PAD_CELL u_pad_scan_in3  (.PAD(scan_in[3]),  .CIN(si_c[3]));

    // ---------------- output pads ----------------
    IO_PAD_CELL u_pad_spi_miso  (.I(miso_c),  .PAD(spi_miso));
    IO_PAD_CELL u_pad_scan_out0 (.I(so_c[0]), .PAD(scan_out[0]));
    IO_PAD_CELL u_pad_scan_out1 (.I(so_c[1]), .PAD(scan_out[1]));
    IO_PAD_CELL u_pad_scan_out2 (.I(so_c[2]), .PAD(scan_out[2]));
    IO_PAD_CELL u_pad_scan_out3 (.I(so_c[3]), .PAD(scan_out[3]));

    // Functional value of the scan outputs; Genus DFT replaces these
    // drivers with the scan-chain outputs.
    assign so_c = 4'b0000;

    // ---------------- reset synchroniser ----------------
    reg [1:0] rst_sync;
    always @(posedge clk_c or posedge rst_c) begin
        if (rst_c) rst_sync <= 2'b11;
        else       rst_sync <= {rst_sync[0], 1'b0};
    end
    wire rst_core = tm_c ? rst_c : rst_sync[1];

    // ---------------- functional core ----------------
    system_top u_core (
        .clk       (clk_c),
        .rst       (rst_core),
        .spi_sck   (sck_c),
        .spi_cs_n  (csn_c),
        .spi_mosi  (mosi_c),
        .spi_miso  (miso_c),
        .test_mode (tm_c)
    );
endmodule
