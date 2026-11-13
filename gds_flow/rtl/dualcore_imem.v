
`timescale 1ns/1ps

module dualcore_imem (
    input  wire        clk,
    input  wire        rst,

    input  wire        req0,
    input  wire [31:0] addr0,
    output wire        req_ready0,
    output wire        valid0,
    input  wire        ready0,
    input  wire        flush0,
    output wire [31:0] instr0_1,
    output wire [31:0] instr0_2,

    input  wire        req1,
    input  wire [31:0] addr1,
    output wire        req_ready1,
    output wire        valid1,
    input  wire        ready1,
    input  wire        flush1,
    output wire [31:0] instr1_1,
    output wire [31:0] instr1_2,

    input  wire        load_we,
    input  wire        load_core,
    input  wire [11:0] load_addr,
    input  wire [31:0] load_wdata,
    output wire        load_ready
);

    localparam [31:0] NOP  = 32'h00000013;
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] READ    = 2'd1;
    localparam [1:0] CAPTURE = 2'd2;
    localparam [1:0] RESP    = 2'd3;

    reg [1:0] state0, state1;
    reg [11:0] fetch_word0, fetch_word1;
    reg invalid0, invalid1;

    reg [31:0] instr0_reg1, instr0_reg2;
    reg [31:0] instr1_reg1, instr1_reg2;

    wire address0_valid =
        (addr0[31:14] == 18'b0) && (addr0[1:0] == 2'b00);

    wire address1_valid =
        (addr1[31:14] == 18'b0) && (addr1[1:0] == 2'b00);

    wire idle0 = (state0 == IDLE);
    wire idle1 = (state1 == IDLE);

    assign req_ready0 = idle0 && !load_we && !rst && !flush0;
    assign req_ready1 = idle1 && !load_we && !rst && !flush1;

    assign valid0 = (state0 == RESP);
    assign valid1 = (state1 == RESP);

    assign instr0_1 = instr0_reg1;
    assign instr0_2 = instr0_reg2;
    assign instr1_1 = instr1_reg1;
    assign instr1_2 = instr1_reg2;

    assign load_ready = idle0 && idle1 && !rst;

    wire accept0 = req0 && req_ready0;
    wire accept1 = req1 && req_ready1;
    wire load_fire = load_we && load_ready;

    wire [11:0] word01 = fetch_word0 + 12'd1;
    wire [11:0] word11 = fetch_word1 + 12'd1;

    wire [10:0] c0_b0_addr =
        fetch_word0[0] ? word01[11:1] : fetch_word0[11:1];

    wire [10:0] c0_b1_addr =
        fetch_word0[0] ? fetch_word0[11:1] : word01[11:1];

    wire [10:0] c1_b0_addr =
        fetch_word1[0] ? word11[11:1] : fetch_word1[11:1];

    wire [10:0] c1_b1_addr =
        fetch_word1[0] ? fetch_word1[11:1] : word11[11:1];

    wire [10:0] load_bank_addr = load_addr[11:1];

    wire c0_b0_load = load_fire && !load_core && !load_addr[0];
    wire c0_b1_load = load_fire && !load_core &&  load_addr[0];
    wire c1_b0_load = load_fire &&  load_core && !load_addr[0];
    wire c1_b1_load = load_fire &&  load_core &&  load_addr[0];

    // SRAM read is enabled for the complete READ state.
    wire c0_read = (state0 == READ) && !invalid0 && !flush0;
    wire c1_read = (state1 == READ) && !invalid1 && !flush1;

    wire [35:0] c0_b0_o, c0_b1_o;
    wire [35:0] c1_b0_o, c1_b1_o;

    MEM_SP_2048x36 c0_imem_bank0 (
        .A   (c0_b0_load ? load_bank_addr : c0_b0_addr),
        .CE  (clk),
        .WEB (c0_b0_load ? 1'b0 : 1'b1),
        .OEB (1'b0),
        .CSB (!(c0_b0_load || c0_read)),
        .I   ({4'b0000, load_wdata}),
        .O   (c0_b0_o)
    );

    MEM_SP_2048x36 c0_imem_bank1 (
        .A   (c0_b1_load ? load_bank_addr : c0_b1_addr),
        .CE  (clk),
        .WEB (c0_b1_load ? 1'b0 : 1'b1),
        .OEB (1'b0),
        .CSB (!(c0_b1_load || c0_read)),
        .I   ({4'b0000, load_wdata}),
        .O   (c0_b1_o)
    );

    MEM_SP_2048x36 c1_imem_bank0 (
        .A   (c1_b0_load ? load_bank_addr : c1_b0_addr),
        .CE  (clk),
        .WEB (c1_b0_load ? 1'b0 : 1'b1),
        .OEB (1'b0),
        .CSB (!(c1_b0_load || c1_read)),
        .I   ({4'b0000, load_wdata}),
        .O   (c1_b0_o)
    );

    MEM_SP_2048x36 c1_imem_bank1 (
        .A   (c1_b1_load ? load_bank_addr : c1_b1_addr),
        .CE  (clk),
        .WEB (c1_b1_load ? 1'b0 : 1'b1),
        .OEB (1'b0),
        .CSB (!(c1_b1_load || c1_read)),
        .I   ({4'b0000, load_wdata}),
        .O   (c1_b1_o)
    );

    // ------------------------------------------------------------
    // Request FSMs and response-data capture.
    // READ activates the synchronous SRAM. CAPTURE samples its output on
    // the following clock edge; RESP is asserted only after capture.
    // ------------------------------------------------------------

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state0      <= IDLE;
            state1      <= IDLE;
            fetch_word0 <= 12'd0;
            fetch_word1 <= 12'd0;
            invalid0    <= 1'b0;
            invalid1    <= 1'b0;

            instr0_reg1 <= NOP;
            instr0_reg2 <= NOP;
            instr1_reg1 <= NOP;
            instr1_reg2 <= NOP;
        end else begin

            case (state0)
                IDLE: begin
                    if (accept0) begin
                        fetch_word0 <= addr0[13:2];
                        invalid0    <= !address0_valid;
                        state0      <= READ;
                    end
                end

                // The SRAM sees READ active at this edge. Its registered
                // output becomes valid after the edge, so do not capture it
                // in this state.
                READ: begin
                    if (flush0)
                        state0 <= IDLE;
                    else
                        state0 <= CAPTURE;
                end

                // Capture one full cycle after the SRAM read edge.
                CAPTURE: begin
                    if (flush0) begin
                        state0 <= IDLE;
                    end else begin
                        if (invalid0) begin
                            instr0_reg1 <= NOP;
                            instr0_reg2 <= NOP;
                        end else begin
                            instr0_reg1 <= fetch_word0[0]
                                         ? c0_b1_o[31:0]
                                         : c0_b0_o[31:0];

                            instr0_reg2 <=
                                (fetch_word0 == 12'hfff) ? NOP :
                                (fetch_word0[0]
                                 ? c0_b0_o[31:0]
                                 : c0_b1_o[31:0]);
                        end
                        state0 <= RESP;
                    end
                end

                RESP: begin
                    if (flush0 || ready0)
                        state0 <= IDLE;
                end

                default: state0 <= IDLE;
            endcase

            case (state1)
                IDLE: begin
                    if (accept1) begin
                        fetch_word1 <= addr1[13:2];
                        invalid1    <= !address1_valid;
                        state1      <= READ;
                    end
                end

                READ: begin
                    if (flush1)
                        state1 <= IDLE;
                    else
                        state1 <= CAPTURE;
                end

                CAPTURE: begin
                    if (flush1) begin
                        state1 <= IDLE;
                    end else begin
                        if (invalid1) begin
                            instr1_reg1 <= NOP;
                            instr1_reg2 <= NOP;
                        end else begin
                            instr1_reg1 <= fetch_word1[0]
                                         ? c1_b1_o[31:0]
                                         : c1_b0_o[31:0];

                            instr1_reg2 <=
                                (fetch_word1 == 12'hfff) ? NOP :
                                (fetch_word1[0]
                                 ? c1_b0_o[31:0]
                                 : c1_b1_o[31:0]);
                        end
                        state1 <= RESP;
                    end
                end

                RESP: begin
                    if (flush1 || ready1)
                        state1 <= IDLE;
                end

                default: state1 <= IDLE;
            endcase
        end
    end

endmodule

