// Synthesis-only black-box declaration. Do NOT compile alongside the behavioral
// MEM_SP_2048x36 model in simulation. Bind this module to the PDK Liberty/LEF.
(* black_box *) module MEM_SP_2048x36 (
    input [10:0] A, input CE, WEB, OEB, CSB,
    input [35:0] I, output [35:0] O
);
endmodule
