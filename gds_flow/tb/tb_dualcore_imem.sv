`timescale 1ns/1ps

module tb_dualcore_imem;

    localparam [31:0] NOP = 32'h00000013;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg         req0   = 1'b0;
    reg         ready0 = 1'b0;
    reg         flush0 = 1'b0;
    reg  [31:0] addr0  = 32'b0;
    wire        req_ready0;
    wire        valid0;
    wire [31:0] instr0_1;
    wire [31:0] instr0_2;

    reg         req1   = 1'b0;
    reg         ready1 = 1'b0;
    reg         flush1 = 1'b0;
    reg  [31:0] addr1  = 32'b0;
    wire        req_ready1;
    wire        valid1;
    wire [31:0] instr1_1;
    wire [31:0] instr1_2;

    reg         load_we    = 1'b0;
    reg         load_core  = 1'b0;
    reg  [11:0] load_addr  = 12'b0;
    reg  [31:0] load_wdata = 32'b0;
    wire        load_ready;

    dualcore_imem dut (
        .clk(clk), .rst(rst),
        .req0(req0), .addr0(addr0), .req_ready0(req_ready0),
        .valid0(valid0), .ready0(ready0), .flush0(flush0),
        .instr0_1(instr0_1), .instr0_2(instr0_2),
        .req1(req1), .addr1(addr1), .req_ready1(req_ready1),
        .valid1(valid1), .ready1(ready1), .flush1(flush1),
        .instr1_1(instr1_1), .instr1_2(instr1_2),
        .load_we(load_we), .load_core(load_core),
        .load_addr(load_addr), .load_wdata(load_wdata),
        .load_ready(load_ready)
    );

    task automatic write_word(
        input        core,
        input [11:0] word_addr,
        input [31:0] data
    );
        integer timeout_count;
        begin
            @(negedge clk);
            load_core  = core;
            load_addr  = word_addr;
            load_wdata = data;
            load_we    = 1'b1;

            timeout_count = 0;
            while (load_ready !== 1'b1 && timeout_count < 30) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end
            if (load_ready !== 1'b1)
                $fatal(1, "Boot write timed out: core=%0d word_addr=%h",
                       core, word_addr);

            // The selected SRAM writes on this rising edge.
            @(posedge clk);
            #1;
            @(negedge clk);
            load_we = 1'b0;
            #1;
        end
    endtask

    task automatic fetch(
        input        core,
        input [31:0] byte_addr,
        input [31:0] expected1,
        input [31:0] expected2
    );
        integer timeout_count;
        reg [31:0] got1, got2;
        reg req_ready;
        reg valid;
        begin
            @(negedge clk);
            if (core == 1'b0) begin
                addr0 = byte_addr;
                req0 = 1'b1;
                ready0 = 1'b0;
            end else begin
                addr1 = byte_addr;
                req1 = 1'b1;
                ready1 = 1'b0;
            end

            timeout_count = 0;
            req_ready = 1'b0;
            while (req_ready !== 1'b1 && timeout_count < 30) begin
                if (core == 1'b0)
                    req_ready = req_ready0;
                else
                    req_ready = req_ready1;
                if (req_ready !== 1'b1) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end
            end
            if (req_ready !== 1'b1)
                $fatal(1, "Fetch request timed out: core=%0d addr=%h",
                       core, byte_addr);

            @(posedge clk);
            #1;
            if (core == 1'b0)
                req0 = 1'b0;
            else
                req1 = 1'b0;

            timeout_count = 0;
            valid = 1'b0;
            while (valid !== 1'b1 && timeout_count < 30) begin
                if (core == 1'b0)
                    valid = valid0;
                else
                    valid = valid1;
                if (valid !== 1'b1) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end
            end
            if (valid !== 1'b1)
                $fatal(1, "Fetch response timed out: core=%0d addr=%h",
                       core, byte_addr);

            #0.1;
            if (core == 1'b0) begin
                got1 = instr0_1;
                got2 = instr0_2;
            end else begin
                got1 = instr1_1;
                got2 = instr1_2;
            end

            if (got1 !== expected1)
                $fatal(1, "Core%0d fetch @%h: instr1 expected %h, got %h",
                       core, byte_addr, expected1, got1);
            if (got2 !== expected2)
                $fatal(1, "Core%0d fetch @%h: instr2 expected %h, got %h",
                       core, byte_addr, expected2, got2);

            // Hold the response until the consumer accepts it.
            repeat (2) begin
                @(negedge clk);
                if (core == 1'b0) begin
                    if (valid0 !== 1'b1 || instr0_1 !== expected1 ||
                        instr0_2 !== expected2)
                        $fatal(1, "Core0 response did not remain stable");
                end else begin
                    if (valid1 !== 1'b1 || instr1_1 !== expected1 ||
                        instr1_2 !== expected2)
                        $fatal(1, "Core1 response did not remain stable");
                end
            end

            if (core == 1'b0)
                ready0 = 1'b1;
            else
                ready1 = 1'b1;

            @(posedge clk);
            #1;
            if (core == 1'b0)
                ready0 = 1'b0;
            else
                ready1 = 1'b0;

            $display("PASS core=%0d addr=%h instr1=%h instr2=%h",
                     core, byte_addr, got1, got2);
        end
    endtask

    initial begin
        $display("Starting dualcore_imem test");

        repeat (3) @(negedge clk);
        rst = 1'b0;

        // Core 0 instruction image.
        write_word(1'b0, 12'd0, 32'h00000013);
        write_word(1'b0, 12'd1, 32'h00100093);
        write_word(1'b0, 12'd2, 32'h00200113);
        write_word(1'b0, 12'd3, 32'h00300193);

        // Core 1 has an independent instruction image.
        write_word(1'b1, 12'd0, 32'h00400213);
        write_word(1'b1, 12'd1, 32'h00500293);

        fetch(1'b0, 32'h00000000, 32'h00000013, 32'h00100093);
        fetch(1'b0, 32'h00000004, 32'h00100093, 32'h00200113);
        fetch(1'b0, 32'h00000008, 32'h00200113, 32'h00300193);
        fetch(1'b1, 32'h00000000, 32'h00400213, 32'h00500293);

        // Misaligned and out-of-range requests must return NOPs.
        fetch(1'b0, 32'h00000002, NOP, NOP);
        fetch(1'b1, 32'h00004000, NOP, NOP);

        $display("DUALCORE_IMEM TEST PASSED");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Global timeout in tb_dualcore_imem");
    end

endmodule
