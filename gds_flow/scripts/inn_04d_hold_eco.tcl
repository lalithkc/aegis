# Hold ECO for scan-in -> first-flop paths found by Tempus signoff (scan_shift_ff)
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -effortLevel signoff -coupled true
deleteFiller -prefix FILL
# Calibre antenna violations (__FOUNDRY__ plate-area rule) -> diodes on the gate pins
set antnets {}
if {[file exists $FLOW/work/calibre/ant/ant_boxes_pnr.txt]} {
  set f [open $FLOW/work/calibre/ant/ant_boxes_pnr.txt]
  while {[gets $f l] >= 0} {
    if {[llength $l] != 5} continue
    lassign $l ly x1 y1 x2 y2
    foreach w [dbQuery -area [list [expr {$x1-0.2}] [expr {$y1-0.2}] [expr {$x2+0.2}] [expr {$y2+0.2}]] -objType wire] {
      if {[dbGet $w.layer.name] ne $ly} continue
      set n [dbGet $w.net]
      if {[dbGet $n.isPwrOrGnd]} continue
      lappend antnets [dbGet $n.name]
    }
  }
  close $f
}
set antnets [lsort -unique $antnets]
puts "ANTENNA NETS ([llength $antnets]): $antnets"
set nd 0
foreach nn $antnets {
  foreach t [dbGet -e [dbGet -p top.nets.name $nn].instTerms] {
    if {![dbGet $t.isInput]} continue
    if {[dbGet $t.inst.cell.baseClass] ne "core"} continue
    safe attachDiode -diodeCell STD_ANTENNA_DIODE -pin [dbGet $t.inst.name] [dbGet $t.cellTerm.name] -prefix ANTCAL
    incr nd
  }
}
puts "ANTENNA DIODES ATTACHED: $nd"
# explicit delay cells on the scan-in first-flop SD pins (tester-input hold)
foreach t {u_core/core1_u_cache_tag_array_reg[7][6]/SD u_core/core0_u_cache_tag_array_reg[26][7]/SD u_core/core0_u_cache_tag_array_reg[58][10]/SD} {
  safe ecoAddRepeater -term $t -cell dl02d2 -name HOLDECO
}
setOptMode -holdTargetSlack 0.05 -setupTargetSlack 0.0 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -hold -outDir $RPT/hold_eco
refinePlace -preserveRouting true
ecoRoute
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_holdeco.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_holdeco.rpt
stage_db 04_route
safe timeDesign -signoff -outDir $RPT/timing_holdeco -prefix holdeco
safe timeDesign -signoff -hold -outDir $RPT/timing_holdeco -prefix holdeco_hold
puts "INN_STAGE_DONE holdeco"
