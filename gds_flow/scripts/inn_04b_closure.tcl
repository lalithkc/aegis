# ---------------------------------------------------------------------------
# Innovus stage 4b: post-route timing / DRC / antenna closure
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -effortLevel medium -coupled true
setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven true \
  -drouteFixAntenna true -routeInsertAntennaDiode true -routeAntennaCellName STD_ANTENNA_DIODE \
  -drouteEndIteration 100

# make room for optimisation: fillers come back at the end
deleteFiller -prefix FILL
setOptMode -setupTargetSlack 0.02 -holdTargetSlack 0.05 -fixHoldAllowSetupTnsDegrade false
optDesign -postRoute -incr -outDir $RPT/postroute_closure
optDesign -postRoute -hold -outDir $RPT/postroute_closure_hold
# DRC / antenna clean-up
ecoRoute -fix_drc
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe verify_drc -report $RPT/verify_drc_closure.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_closure.rpt
stage_db 04_route
rpt postRoute
puts "INN_STAGE_DONE closure"
