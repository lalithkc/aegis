`timescale 1ns/1ps
// Chip-level test for aegis_chip (through the I/O pads).
//   1. reset, check IMEM is writable while cores are held in reset
//   2. load a short program into each core over SPI
//   3. release boot, let the cores run, check architectural results
// Define GATE_LEVEL for netlist simulation: internal-state checks are then
// replaced by the externally visible SPI handshake checks only.
module tb_aegis_chip;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg spi_sck = 1'b0;
    reg spi_cs_n = 1'b1;
    reg spi_mosi = 1'b0;
    wire spi_miso;
    reg test_mode = 1'b0;
    wire [3:0] scan_out;

    always #5 clk = ~clk;   // 100 MHz

    aegis_chip dut (
        .clk(clk), .rst(rst),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .test_mode(test_mode),
        .scan_enable(1'b0), .scan_in(4'b0000), .scan_out(scan_out)
    );

`ifdef GATE_LEVEL
    // architectural registers read straight from the netlist flops
    wire [31:0] g_x3 = {dut.u_core.\core0_rf_registers_reg[3][31] .Q, dut.u_core.\core0_rf_registers_reg[3][30] .Q, dut.u_core.\core0_rf_registers_reg[3][29] .Q, dut.u_core.\core0_rf_registers_reg[3][28] .Q, dut.u_core.\core0_rf_registers_reg[3][27] .Q, dut.u_core.\core0_rf_registers_reg[3][26] .Q, dut.u_core.\core0_rf_registers_reg[3][25] .Q, dut.u_core.\core0_rf_registers_reg[3][24] .Q, dut.u_core.\core0_rf_registers_reg[3][23] .Q, dut.u_core.\core0_rf_registers_reg[3][22] .Q, dut.u_core.\core0_rf_registers_reg[3][21] .Q, dut.u_core.\core0_rf_registers_reg[3][20] .Q, dut.u_core.\core0_rf_registers_reg[3][19] .Q, dut.u_core.\core0_rf_registers_reg[3][18] .Q, dut.u_core.\core0_rf_registers_reg[3][17] .Q, dut.u_core.\core0_rf_registers_reg[3][16] .Q, dut.u_core.\core0_rf_registers_reg[3][15] .Q, dut.u_core.\core0_rf_registers_reg[3][14] .Q, dut.u_core.\core0_rf_registers_reg[3][13] .Q, dut.u_core.\core0_rf_registers_reg[3][12] .Q, dut.u_core.\core0_rf_registers_reg[3][11] .Q, dut.u_core.\core0_rf_registers_reg[3][10] .Q, dut.u_core.\core0_rf_registers_reg[3][9] .Q, dut.u_core.\core0_rf_registers_reg[3][8] .Q, dut.u_core.\core0_rf_registers_reg[3][7] .Q, dut.u_core.\core0_rf_registers_reg[3][6] .Q, dut.u_core.\core0_rf_registers_reg[3][5] .Q, dut.u_core.\core0_rf_registers_reg[3][4] .Q, dut.u_core.\core0_rf_registers_reg[3][3] .Q, dut.u_core.\core0_rf_registers_reg[3][2] .Q, dut.u_core.\core0_rf_registers_reg[3][1] .Q, dut.u_core.\core0_rf_registers_reg[3][0] .Q};
    wire [31:0] g_x6 = {dut.u_core.\core1_rf_registers_reg[6][31] .Q, dut.u_core.\core1_rf_registers_reg[6][30] .Q, dut.u_core.\core1_rf_registers_reg[6][29] .Q, dut.u_core.\core1_rf_registers_reg[6][28] .Q, dut.u_core.\core1_rf_registers_reg[6][27] .Q, dut.u_core.\core1_rf_registers_reg[6][26] .Q, dut.u_core.\core1_rf_registers_reg[6][25] .Q, dut.u_core.\core1_rf_registers_reg[6][24] .Q, dut.u_core.\core1_rf_registers_reg[6][23] .Q, dut.u_core.\core1_rf_registers_reg[6][22] .Q, dut.u_core.\core1_rf_registers_reg[6][21] .Q, dut.u_core.\core1_rf_registers_reg[6][20] .Q, dut.u_core.\core1_rf_registers_reg[6][19] .Q, dut.u_core.\core1_rf_registers_reg[6][18] .Q, dut.u_core.\core1_rf_registers_reg[6][17] .Q, dut.u_core.\core1_rf_registers_reg[6][16] .Q, dut.u_core.\core1_rf_registers_reg[6][15] .Q, dut.u_core.\core1_rf_registers_reg[6][14] .Q, dut.u_core.\core1_rf_registers_reg[6][13] .Q, dut.u_core.\core1_rf_registers_reg[6][12] .Q, dut.u_core.\core1_rf_registers_reg[6][11] .Q, dut.u_core.\core1_rf_registers_reg[6][10] .Q, dut.u_core.\core1_rf_registers_reg[6][9] .Q, dut.u_core.\core1_rf_registers_reg[6][8] .Q, dut.u_core.\core1_rf_registers_reg[6][7] .Q, dut.u_core.\core1_rf_registers_reg[6][6] .Q, dut.u_core.\core1_rf_registers_reg[6][5] .Q, dut.u_core.\core1_rf_registers_reg[6][4] .Q, dut.u_core.\core1_rf_registers_reg[6][3] .Q, dut.u_core.\core1_rf_registers_reg[6][2] .Q, dut.u_core.\core1_rf_registers_reg[6][1] .Q, dut.u_core.\core1_rf_registers_reg[6][0] .Q};
`endif

    // Packet format: CMD[7:0], CORE[7:0], WORD_ADDR[15:0], DATA[31:0].
    task automatic send_packet(input [7:0] cmd, input [7:0] core,
                               input [15:0] word_addr, input [31:0] data);
        reg [63:0] packet;
        integer bit_index, timeout_count;
        begin
            packet = {cmd, core, word_addr, data};
            timeout_count = 0;
            while (spi_miso !== 1'b1 && timeout_count < 100) begin
                #6 spi_sck = 1'b1;
                #6 spi_sck = 1'b0;
                timeout_count = timeout_count + 1;
            end
            if (spi_miso !== 1'b1)
                $fatal(1, "SPI bootloader was not ready before packet %h", cmd);
            spi_cs_n = 1'b0;
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                spi_mosi = packet[bit_index];
                #6 spi_sck = 1'b1;
                #6 spi_sck = 1'b0;
            end
            spi_mosi = 1'b0;
            spi_cs_n = 1'b1;
            timeout_count = 0;
            while (spi_miso !== 1'b1 && timeout_count < 100) begin
                #6 spi_sck = 1'b1;
                #6 spi_sck = 1'b0;
                timeout_count = timeout_count + 1;
            end
            if (spi_miso !== 1'b1)
                $fatal(1, "SPI packet acknowledgement timed out: cmd=%h addr=%h", cmd, word_addr);
        end
    endtask

    // core0: x1=1, x2=2, x3=x1+x2 (=3), spin.   core1: x4=4, x5=5, x6=x4+x5 (=9), spin.
    reg [31:0] prog0 [0:15];
    reg [31:0] prog1 [0:15];
    integer k;
    initial begin
        for (k = 0; k < 16; k = k + 1) begin prog0[k] = 32'h00000013; prog1[k] = 32'h00000013; end
        prog0[1] = 32'h00100093;  // addi x1,x0,1
        prog0[2] = 32'h00200113;  // addi x2,x0,2
        prog0[3] = 32'h002081B3;  // add  x3,x1,x2
        prog0[6] = 32'h0000006F;  // jal  x0,0
        prog1[1] = 32'h00400213;  // addi x4,x0,4
        prog1[2] = 32'h00500293;  // addi x5,x0,5
        prog1[3] = 32'h00520333;  // add  x6,x4,x5
        prog1[6] = 32'h0000006F;  // jal  x0,0
    end

    initial begin
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (6) @(negedge clk);   // reset synchroniser adds 2 cycles
`ifndef GATE_LEVEL
        if (dut.u_core.u_imem.load_ready !== 1'b1)
            $fatal(1, "IMEM must be writable before boot release");
`endif
        for (k = 0; k < 16; k = k + 1) send_packet(8'h02, 8'h00, k[15:0], prog0[k]);
        for (k = 0; k < 16; k = k + 1) send_packet(8'h02, 8'h01, k[15:0], prog1[k]);
`ifndef GATE_LEVEL
        if (dut.u_core.u_imem.c0_imem_bank1.ram.memory[0][31:0] !== 32'h00100093)
            $fatal(1, "Core0 IMEM word 1 was not loaded correctly");
        if (dut.u_core.u_imem.c1_imem_bank1.ram.memory[0][31:0] !== 32'h00400213)
            $fatal(1, "Core1 IMEM word 1 was not loaded correctly");
`endif
        send_packet(8'h01, 8'h00, 16'd0, 32'd0);   // boot release
        repeat (200) @(negedge clk);
`ifndef GATE_LEVEL
        if (dut.u_core.u_bootloader.core_boot_done !== 1'b1)
            $fatal(1, "Boot-release command did not set core_boot_done");
        if (dut.u_core.core0.rf.registers[3] !== 32'd3)
            $fatal(1, "core0 x3 = %h, expected 3", dut.u_core.core0.rf.registers[3]);
        if (dut.u_core.core1.rf.registers[6] !== 32'd9)
            $fatal(1, "core1 x6 = %h, expected 9", dut.u_core.core1.rf.registers[6]);
        $display("core0 x3=%0d  core1 x6=%0d", dut.u_core.core0.rf.registers[3],
                 dut.u_core.core1.rf.registers[6]);
`else
        if (g_x3 !== 32'd3) $fatal(1, "GLS: core0 x3 = %h, expected 3", g_x3);
        if (g_x6 !== 32'd9) $fatal(1, "GLS: core1 x6 = %h, expected 9", g_x6);
        $display("GLS core0 x3=%0d  core1 x6=%0d", g_x3, g_x6);
`endif
        if (^scan_out === 1'bx) $fatal(1, "scan_out is X in functional mode");
        $display("AEGIS_CHIP SPI BOOT + PROGRAM TEST PASSED");
        $finish;
    end

    initial begin
        #400000;
        $fatal(1, "Global timeout in tb_aegis_chip");
    end
endmodule
