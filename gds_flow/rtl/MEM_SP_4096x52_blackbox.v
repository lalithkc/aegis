// Synthesis-only black-box declaration for the PDK SRAM macro.
// Do NOT compile together with the behavioral MEM_SP_4096x52 model.
(* black_box *) module MEM_SP_4096x52 (
    input [11:0] A, input CE, WEB, OEB, CSB,
    input [51:0] I, output [51:0] O
);
endmodule
