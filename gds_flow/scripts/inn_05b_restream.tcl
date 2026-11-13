source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/05_final.enc.dat aegis_chip
set GDSIN [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/gds/__STDCELL__.gds \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/gds/__IOPAD_LIB___4lm.gds \
  $FLOW/lib/sram_gds_lef/MEM_SP_placeholders.gds ]
streamOut $OUTP/aegis_chip_pnr.gds -mapFile $FLOW/lib/innovus_gds.map -libName aegis -structureName aegis_chip_pr \
  -units 1000 -mode ALL -merge $GDSIN -outputMacros -uniquifyCellNames
puts RESTREAM_DONE
exit
