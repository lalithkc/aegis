-define GATE_LEVEL
-delay_mode unit
outputs/syn/aegis_chip.syn.v
$PDK_ROOT/stdcell/__STDCELL_DIR__/__METAL_STACK__/verilog/vcs_sim_model/__STDCELL_LIB__.v
-y $PDK_ROOT/iopad/__IOPAD_DIR__/__METAL_STACK__/verilog/__IOPAD_LIB__/zero
+libext+.v
$PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_2048x36/MEM_SP_2048x36.v
$PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_4096x52/MEM_SP_4096x52.v
$PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_64x32/MEM_SP_64x32.v
tb/tb_aegis_chip.v
