`timescale 1ns/1ps
// Minimal SPI mode-0 boot loader.
// 64-bit packet, MSB first: CMD[7:0], CORE[7:0], WORD_ADDR[15:0], DATA[31:0].
// CMD=0x02 writes one instruction word; CMD=0x01 releases both cores from reset.
// The SPI-domain packet bus is held stable until the clk-domain acknowledges it.
module spi_bootloader (
    input  wire        clk,
    input  wire        rst,
    input  wire        spi_sck,
    input  wire        spi_cs_n,
    input  wire        spi_mosi,
    output wire        spi_miso,
    output reg         core_boot_done,
    output reg         load_we,
    output reg         load_core,
    output reg  [11:0] load_addr,
    output reg  [31:0] load_wdata,
    input  wire        load_ready
);
    reg [63:0] shift_spi;
    reg [5:0] bit_count_spi;
    reg req_toggle_spi;
    reg [7:0] packet_cmd_spi, packet_core_spi;
    reg [15:0] packet_addr_spi;
    reg [31:0] packet_data_spi;
    reg ack_sync1_spi, ack_sync2_spi;
    reg ack_toggle_clk;
    wire spi_busy = (req_toggle_spi != ack_sync2_spi);
    wire [63:0] shift_next = {shift_spi[62:0], spi_mosi};

    // SPI mode 0: sample MOSI on rising SCK, MSB first.
    always @(posedge spi_sck or posedge rst or posedge spi_cs_n) begin
        if (rst) begin
            shift_spi <= 64'b0;
            bit_count_spi <= 6'b0;
            req_toggle_spi <= 1'b0;
            packet_cmd_spi <= 8'b0;
            packet_core_spi <= 8'b0;
            packet_addr_spi <= 16'b0;
            packet_data_spi <= 32'b0;
        end else if (spi_cs_n) begin
            shift_spi <= 64'b0;
            bit_count_spi <= 6'b0;
        end else begin
            if (bit_count_spi == 6'd63) begin
                bit_count_spi <= 6'b0;
                shift_spi <= 64'b0;
                if (!spi_busy) begin
                    packet_cmd_spi  <= shift_next[63:56];
                    packet_core_spi <= shift_next[55:48];
                    packet_addr_spi <= shift_next[47:32];
                    packet_data_spi <= shift_next[31:0];
                    req_toggle_spi <= ~req_toggle_spi;
                end
            end else begin
                shift_spi <= shift_next;
                bit_count_spi <= bit_count_spi + 6'd1;
            end
        end
    end

    // Synchronize acknowledgement back to the SPI clock domain.
    always @(posedge spi_sck or posedge rst) begin
        if (rst) begin
            ack_sync1_spi <= 1'b0;
            ack_sync2_spi <= 1'b0;
        end else begin
            ack_sync1_spi <= ack_toggle_clk;
            ack_sync2_spi <= ack_sync1_spi;
        end
    end

    reg req_sync1_clk, req_sync2_clk, req_seen_clk;
    reg cmd_pending;
    reg [7:0] cmd_clk, core_clk;
    reg [15:0] addr_clk;
    reg [31:0] data_clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_sync1_clk <= 1'b0;
            req_sync2_clk <= 1'b0;
            req_seen_clk <= 1'b0;
            ack_toggle_clk <= 1'b0;
            cmd_pending <= 1'b0;
            cmd_clk <= 8'b0;
            core_clk <= 8'b0;
            addr_clk <= 16'b0;
            data_clk <= 32'b0;
            core_boot_done <= 1'b0;
            load_we <= 1'b0;
            load_core <= 1'b0;
            load_addr <= 12'b0;
            load_wdata <= 32'b0;
        end else begin
            req_sync1_clk <= req_toggle_spi;
            req_sync2_clk <= req_sync1_clk;
            load_we <= 1'b0;

            if (!cmd_pending && req_sync2_clk != req_seen_clk) begin
                req_seen_clk <= req_sync2_clk;
                cmd_clk <= packet_cmd_spi;
                core_clk <= packet_core_spi;
                addr_clk <= packet_addr_spi;
                data_clk <= packet_data_spi;
                if (packet_cmd_spi == 8'h01) begin
                    core_boot_done <= 1'b1;
                    ack_toggle_clk <= ~ack_toggle_clk;
                end else if (packet_cmd_spi == 8'h02 && packet_core_spi[7:1] == 7'b0 && packet_addr_spi[15:12] == 4'b0) begin
                    cmd_pending <= 1'b1;
                end else begin
                    // Acknowledge unsupported/malformed command to unblock host.
                    ack_toggle_clk <= ~ack_toggle_clk;
                end
            end

            if (cmd_pending && load_ready && !load_we) begin
                load_core <= core_clk[0];
                load_addr <= addr_clk[11:0];
                load_wdata <= data_clk;
                load_we <= 1'b1;
            end else if (load_we) begin
                cmd_pending <= 1'b0;
                ack_toggle_clk <= ~ack_toggle_clk;
            end
        end
    end

    // MISO is a ready/busy indication (1=ready for another packet).
    assign spi_miso = !spi_busy;
endmodule
