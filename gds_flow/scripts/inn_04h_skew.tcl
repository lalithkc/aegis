# Targeted useful-skew ECO on the last setup endpoint(s): delay the capture clock
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -effortLevel signoff -coupled true
setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven true -drouteEndIteration 100
deleteFiller -prefix FILL
timeDesign -signoff -outDir $RPT/timing_skew_pre -prefix pre
set eps [get_property [report_timing -collection -max_paths 20 -max_slack 0.0 -view func_ss] capturing_point]
set done 0
foreach ep [lsort -unique [get_object_name $eps]] {
  set inst [file dirname $ep]
  # slack of paths launched from this flop (setup) and arriving at it (hold)
  set lpath [report_timing -collection -from $inst/CP -view func_ss]
  set ls [get_property $lpath slack]
  set hpath [report_timing -collection -early -to $ep -view func_ff]
  set hs [get_property $hpath slack]
  puts "SKEW CAND $inst launch_slack=$ls"
  if {$ls ne "" && $ls > 0.25} {
    if {![catch {ecoAddRepeater -term $inst/CP -cell STD_BUF_1 -name SKEWECO} m]} { incr done; puts "SKEW ADDED $inst" }
  }
}
puts "SKEW ECOS: $done"
refinePlace -preserveRouting true
ecoRoute
setOptMode -holdTargetSlack 0.05 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -hold -outDir $RPT/skew_hold
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_final.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_final.rpt
safe verifyConnectivity -type regular -error 1000 -report $RPT/verify_conn_skew.rpt
safe checkPlace $RPT/checkplace_final.rpt
timeDesign -signoff -outDir $RPT/timing_final -prefix fin
timeDesign -signoff -hold -outDir $RPT/timing_final -prefix fin_hold
stage_db 04_route
puts "INN_STAGE_DONE skew"
