// Conformal LEC: synthesized netlist (golden) vs post-route netlist (revised)
set log file $PROJ_ROOT/logs/lec_syn2pnr.log -replace
set parallel option -threads 8
read library -liberty -both \
  $PDK_ROOT/stdcell/__STDCELL_DIR__/__METAL_STACK__/liberty/lib_flow_ss/__STDCELL_LIB___ss.lib \
  $PDK_ROOT/iopad/__IOPAD_DIR__/__METAL_STACK__/liberty/__IOPAD_LIB___max.lib \
  $PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_2048x36/MEM_SP_2048x36_max_SP.lib \
  $PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_4096x52/MEM_SP_4096x52_max_SP.lib \
  $PDK_ROOT/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_64x32/MEM_SP_64x32_max.lib
read design -verilog -golden  $PROJ_ROOT/outputs/syn/aegis_chip.syn.v
read design -verilog -revised $PROJ_ROOT/outputs/pnr/aegis_chip.pnr.v
// scan chains are re-ordered in P&R: compare the functional (non-shift) behaviour
add pin constraints 0 scan_enable -both
set system mode lec
map key points
analyze setup
add compare points -all
compare
report compare data -class nonequivalent -class abort -class notcompared
report verification -verbose
report statistics
exit -force
