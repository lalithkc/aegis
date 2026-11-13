`timescale 1ns/1ps
module system_top (
    input  wire       clk,
    input  wire       rst,       // active-high reset pulse; bootloader is reset too
    input  wire       spi_sck,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output wire       spi_miso,
    // DFT: test_mode=1 holds the internal boot-gated reset under direct
    // control of rst so scan can control every asynchronous reset.
    // Scan pads/chains live in the chip top (aegis_chip) and are stitched
    // by Genus DFT; they are not part of this functional core.
    input  wire       test_mode
);
    wire boot_done;
    wire core_rst = rst | (!boot_done & !test_mode);
    wire load_we, load_core, load_ready;
    wire [11:0] load_addr;
    wire [31:0] load_wdata;

    spi_bootloader u_bootloader (
        .clk(clk), .rst(rst),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .core_boot_done(boot_done), .load_we(load_we), .load_core(load_core),
        .load_addr(load_addr), .load_wdata(load_wdata), .load_ready(load_ready)
    );

    wire c0_imem_req, c0_imem_req_ready, c0_imem_valid, c0_imem_ready, c0_imem_flush;
    wire [31:0] c0_pc, c0_instr1, c0_instr2;
    wire c1_imem_req, c1_imem_req_ready, c1_imem_valid, c1_imem_ready, c1_imem_flush;
    wire [31:0] c1_pc, c1_instr1, c1_instr2;

    wire c0_bus_req, c0_bus_we, c0_bus_ack;
    wire [31:0] c0_bus_addr, c0_bus_wdata, c0_bus_rdata;
    wire c0_snoop_valid, c0_snoop_we;
    wire [31:0] c0_snoop_addr;

    wire c1_bus_req, c1_bus_we, c1_bus_ack;
    wire [31:0] c1_bus_addr, c1_bus_wdata, c1_bus_rdata;
    wire c1_snoop_valid, c1_snoop_we;
    wire [31:0] c1_snoop_addr;

    wire mem_req, mem_we, mem_rvalid;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;

    core_top core0 (
        .clk(clk), .rst(core_rst),
        .instr_req(c0_imem_req), .instr_req_ready(c0_imem_req_ready),
        .instr_valid(c0_imem_valid), .instr_ready(c0_imem_ready), .instr_flush(c0_imem_flush),
        .instr_in1(c0_instr1), .instr_in2(c0_instr2), .pc_out(c0_pc),
        .bus_req(c0_bus_req), .bus_we(c0_bus_we), .bus_addr(c0_bus_addr), .bus_wdata(c0_bus_wdata),
        .bus_rdata(c0_bus_rdata), .bus_ack(c0_bus_ack),
        .snoop_valid(c0_snoop_valid), .snoop_we(c0_snoop_we), .snoop_addr(c0_snoop_addr)
    );

    core_top core1 (
        .clk(clk), .rst(core_rst),
        .instr_req(c1_imem_req), .instr_req_ready(c1_imem_req_ready),
        .instr_valid(c1_imem_valid), .instr_ready(c1_imem_ready), .instr_flush(c1_imem_flush),
        .instr_in1(c1_instr1), .instr_in2(c1_instr2), .pc_out(c1_pc),
        .bus_req(c1_bus_req), .bus_we(c1_bus_we), .bus_addr(c1_bus_addr), .bus_wdata(c1_bus_wdata),
        .bus_rdata(c1_bus_rdata), .bus_ack(c1_bus_ack),
        .snoop_valid(c1_snoop_valid), .snoop_we(c1_snoop_we), .snoop_addr(c1_snoop_addr)
    );

    // Keep instruction SRAM out of core reset so the SPI bootloader can
    // preload it before boot_done releases the processors.
    dualcore_imem u_imem (
        .clk(clk), .rst(rst),
        .req0(c0_imem_req), .addr0(c0_pc), .req_ready0(c0_imem_req_ready),
        .valid0(c0_imem_valid), .ready0(c0_imem_ready), .flush0(c0_imem_flush),
        .instr0_1(c0_instr1), .instr0_2(c0_instr2),
        .req1(c1_imem_req), .addr1(c1_pc), .req_ready1(c1_imem_req_ready),
        .valid1(c1_imem_valid), .ready1(c1_imem_ready), .flush1(c1_imem_flush),
        .instr1_1(c1_instr1), .instr1_2(c1_instr2),
        .load_we(load_we), .load_core(load_core), .load_addr(load_addr),
        .load_wdata(load_wdata), .load_ready(load_ready)
    );

    bus_arbiter arb (
        .clk(clk), .rst(core_rst),
        .req0(c0_bus_req), .we0(c0_bus_we), .addr0(c0_bus_addr), .wdata0(c0_bus_wdata),
        .ack0(c0_bus_ack), .rdata0(c0_bus_rdata),
        .req1(c1_bus_req), .we1(c1_bus_we), .addr1(c1_bus_addr), .wdata1(c1_bus_wdata),
        .ack1(c1_bus_ack), .rdata1(c1_bus_rdata),
        .snoop_valid0(c0_snoop_valid), .snoop_we0(c0_snoop_we), .snoop_addr0(c0_snoop_addr),
        .snoop_valid1(c1_snoop_valid), .snoop_we1(c1_snoop_we), .snoop_addr1(c1_snoop_addr),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_rvalid(mem_rvalid)
    );

    main_memory u_main_mem (
        .clk(clk), .rst(core_rst),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_rvalid(mem_rvalid)
    );

endmodule
