# Closure pass 2: remaining antenna diodes (bracketed names) + setup recovery
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
set ok 0; set bad 0
set f [open $FLOW/work/innovus/diode_retry.txt]
while {[gets $f l] >= 0} {
  if {[llength [split $l " "]] < 2} continue
  set term [lindex [split $l " "] end]
  set inst [string range $l 0 [expr {[string length $l]-[string length $term]-2}]]
  if {[catch {attachDiode -diodeCell STD_ANTENNA_DIODE -pin $inst $term -prefix ANTCAL2} m]} { incr bad } else { incr ok }
}
close $f
puts "DIODE RETRY: ok=$ok failed=$bad"
refinePlace -preserveRouting true
ecoRoute
setOptMode -setupTargetSlack 0.02 -holdTargetSlack 0.05 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -incr -outDir $RPT/closure2
optDesign -postRoute -hold -outDir $RPT/closure2_hold
ecoRoute -fix_drc
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_closure2.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_closure2.rpt
safe checkPlace $RPT/checkplace_closure2.rpt
stage_db 04_route
safe timeDesign -signoff -outDir $RPT/timing_closure2 -prefix c2
safe timeDesign -signoff -hold -outDir $RPT/timing_closure2 -prefix c2_hold
puts "INN_STAGE_DONE closure2"
