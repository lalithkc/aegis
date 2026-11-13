// Synthesis-only black-box declaration for the __PDK_180NM__ MEM_SP_64x32 macro.
// Do NOT compile together with the behavioral MEM_SP_64x32 model.
// Physical/timing implementation is supplied by the PDK Liberty and LEF views.
(* black_box *) module MEM_SP_64x32 (
    input  [5:0]  A,
    input         CE,
    input         WEB,
    input         OEB,
    input         CSB,
    input  [31:0] I,
    output [31:0] O
);
endmodule
