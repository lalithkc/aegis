# ---------------------------------------------------------------------------
# Innovus stage 5: physical verification, signoff extraction, exports
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route.enc.dat aegis_chip
file mkdir $OUTP/spef $OUTP/sdf

# ---------------- verification in Innovus ----------------
set_verify_drc_mode -limit 100000
safe verify_drc -report $RPT/verify_drc.rpt
safe verifyConnectivity -type all -error 100000 -warning 100000 -report $RPT/verify_conn.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna.rpt
safe redirect $RPT/verify_pg_short.rpt {verify_PG_short -no_routing_blkg}
safe checkPlace $RPT/checkplace_final.rpt
safe checkDesign -all -outdir $RPT/checkDesign_final
safe reportGateCount -level 1 -outfile $RPT/gate_count.rpt
safe summaryReport -noHtml -outfile $RPT/summary.rpt
safe report_power -view func_ss -outfile $RPT/power_route.rpt

# ---------------- signoff RC extraction (Quantus) ----------------
setExtractRCMode -engine postRoute -effortLevel signoff -coupled true
extractRC
foreach c {rc_125 rc_m40} {
  rcOut -spef $OUTP/spef/aegis_chip_$c.spef.gz -rc_corner $c
}
safe timeDesign -signoff -outDir $RPT/timing_signoff -prefix signoff
safe timeDesign -signoff -hold -outDir $RPT/timing_signoff -prefix signoff_hold
write_sdf -view func_ss -recompute_delay_calc $OUTP/sdf/aegis_chip_func_ss.sdf
write_sdf -view func_ff -recompute_delay_calc $OUTP/sdf/aegis_chip_func_ff.sdf


# ---------------- pad placement dump (for GDS labels / seal ring) ----------------
set pf [open $OUTP/pads.txt w]
puts $pf "DIE [dbGet top.fPlan.box]"
foreach i [concat [dbGet -p2 top.insts.cell.baseClass pad] [dbGet -p2 top.insts.cell.baseClass corner]] {
  set cell [dbGet $i.cell.name]
  if {[string match pfeed* $cell]} continue
  set net ""
  set t [dbGet -e $i.instTerms.name */PAD]
  if {$t ne ""} { set net [dbGet [dbGet -p $i.instTerms.name */PAD].net.name] }
  if {[string match pvd* $cell] || [string match pv0* $cell]} {
    set net [expr {[string match pvda $cell] ? "VDDO" : [string match pv0a $cell] ? "VSSO" : [string match pvdi $cell] ? "VDD" : "VSS"}]
  }
  puts $pf "PAD [dbGet $i.name] $cell [dbGet $i.box] [dbGet $i.orient] $net"
}
close $pf

# ---------------- netlists ----------------
saveNetlist $OUTP/aegis_chip.pnr.v
saveNetlist $OUTP/aegis_chip.lvs.v -includePowerGround -includePhysicalInst \
  -excludeCellInst {feedth feedth3 feedth9 IO_CORNER_CELL pfeed00010 pfeed00040 pfeed00120 pfeed00540 pfeed01000 pfeed02000 pfeed10000 pfeed30000}
saveNetlist $OUTP/aegis_chip.pg.v -includePowerGround

# ---------------- physical data ----------------
defOut -floorplan -netlist -routing $OUTP/aegis_chip.def.gz
write_lef_abstract -5.8 $OUTP/aegis_chip.lef
set GDSIN [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/gds/__STDCELL__.gds \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/gds/__IOPAD_LIB___4lm.gds \
  $FLOW/lib/sram_gds_lef/MEM_SP_placeholders.gds ]
streamOut $OUTP/aegis_chip_pnr.gds -mapFile $FLOW/lib/innovus_gds.map -libName aegis -structureName aegis_chip_pr \
  -units 1000 -mode ALL -merge $GDSIN -outputMacros -uniquifyCellNames
saveDesign $DBS/05_final.enc
puts "INN_STAGE_DONE signoff_export"
