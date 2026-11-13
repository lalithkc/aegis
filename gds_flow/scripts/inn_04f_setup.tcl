# Closure pass 3: final setup recovery (high effort, useful skew) with signoff RC
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
setOptMode -effort high -usefulSkew true -usefulSkewPostRoute true -setupTargetSlack 0.03 \
  -holdTargetSlack 0.05 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -outDir $RPT/closure3
optDesign -postRoute -hold -outDir $RPT/closure3_hold
ecoRoute -fix_drc
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_closure3.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_closure3.rpt
safe checkPlace $RPT/checkplace_closure3.rpt
stage_db 04_route
safe timeDesign -signoff -outDir $RPT/timing_closure3 -prefix c3
safe timeDesign -signoff -hold -outDir $RPT/timing_closure3 -prefix c3_hold
puts "INN_STAGE_DONE closure3"
