`timescale 1ns/1ps

module tb_system_top;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg spi_sck = 1'b0;
    reg spi_cs_n = 1'b1;
    reg spi_mosi = 1'b0;
    wire spi_miso;
    reg test_mode = 1'b0;

    always #5 clk = ~clk;

    system_top dut (
        .clk(clk),
        .rst(rst),
        .spi_sck(spi_sck),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .test_mode(test_mode)
    );

    // Packet format: CMD[7:0], CORE[7:0], WORD_ADDR[15:0], DATA[31:0].
    task automatic send_packet(
        input [7:0] cmd,
        input [7:0] core,
        input [15:0] word_addr,
        input [31:0] data
    );
        reg [63:0] packet;
        integer bit_index;
        integer timeout_count;
        begin
            packet = {cmd, core, word_addr, data};

            // The toggle handshake permits only one outstanding packet.
            timeout_count = 0;
            while (spi_miso !== 1'b1 && timeout_count < 100) begin
                // Clock the SPI-domain acknowledgement synchronizers.
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

            // Keep clocking SCK so the acknowledgement can cross back
            // into the SPI domain even though chip-select is deasserted.
            timeout_count = 0;
            while (spi_miso !== 1'b1 && timeout_count < 100) begin
                #6 spi_sck = 1'b1;
                #6 spi_sck = 1'b0;
                timeout_count = timeout_count + 1;
            end
            if (spi_miso !== 1'b1)
                $fatal(1, "SPI packet acknowledgement timed out: cmd=%h addr=%h",
                       cmd, word_addr);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (3) @(negedge clk);

        // The instruction SRAM must accept writes while the cores are held
        // in reset awaiting CMD=01.
        if (dut.u_imem.load_ready !== 1'b1)
            $fatal(1, "IMEM must be writable before boot release");

        send_packet(8'h02, 8'h00, 16'd0, 32'h00000013);
        send_packet(8'h02, 8'h00, 16'd1, 32'h00100093);
        send_packet(8'h02, 8'h01, 16'd0, 32'h00400213);
        send_packet(8'h02, 8'h01, 16'd1, 32'h00500293);

        if (dut.u_imem.c0_imem_bank0.ram.memory[0][31:0] !== 32'h00000013)
            $fatal(1, "Core0 IMEM word 0 was not loaded correctly");
        if (dut.u_imem.c0_imem_bank1.ram.memory[0][31:0] !== 32'h00100093)
            $fatal(1, "Core0 IMEM word 1 was not loaded correctly");
        if (dut.u_imem.c1_imem_bank0.ram.memory[0][31:0] !== 32'h00400213)
            $fatal(1, "Core1 IMEM word 0 was not loaded correctly");
        if (dut.u_imem.c1_imem_bank1.ram.memory[0][31:0] !== 32'h00500293)
            $fatal(1, "Core1 IMEM word 1 was not loaded correctly");

        send_packet(8'h01, 8'h00, 16'd0, 32'd0);
        repeat (5) @(negedge clk);
        if (dut.u_bootloader.core_boot_done !== 1'b1)
            $fatal(1, "Boot-release command did not set core_boot_done");

        $display("SYSTEM_TOP SPI BOOT TEST PASSED");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Global timeout in tb_system_top");
    end

endmodule
