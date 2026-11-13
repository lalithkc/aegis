# Manual ECO: upsize the weak gates on the last critical setup path (core0 ALU adder)
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -effortLevel signoff -coupled true
setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven true \
  -drouteFixAntenna true -routeInsertAntennaDiode true -routeAntennaCellName STD_ANTENNA_DIODE -drouteEndIteration 100
deleteFiller -prefix FILL
set n 0
set f [open $FLOW/work/innovus/upsize.txt]
while {[gets $f l] >= 0} {
  set cell [lindex [split $l " "] end]
  set inst [string range $l 0 [expr {[string length $l]-[string length $cell]-2}]]
  regsub {d[012]$} $cell d4 new
  if {[dbGet -e head.libCells.name $new] eq ""} continue
  if {![catch {ecoChangeCell -inst $inst -cell $new} m]} { incr n }
}
close $f
puts "UPSIZED $n cells"
refinePlace -preserveRouting true
ecoRoute
setOptMode -holdTargetSlack 0.05 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -hold -outDir $RPT/upsize_hold
ecoRoute -fix_drc
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_final.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_final.rpt
safe checkPlace $RPT/checkplace_final.rpt
stage_db 04_route
safe timeDesign -signoff -outDir $RPT/timing_final -prefix fin
safe timeDesign -signoff -hold -outDir $RPT/timing_final -prefix fin_hold
puts "INN_STAGE_DONE upsize"
