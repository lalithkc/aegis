# ---------------------------------------------------------------------------
# Innovus stage 4: detailed routing + post-route (SI) optimisation, fillers
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/03_cts.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
# main_memory 1.5-cycle SRAM read exception (also appended to the mode SDCs)
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
safe timeDesign -postCTS -outDir $RPT/timing_postCTS_mcp -prefix postCTS_mcp

setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven true \
  -routeTopRoutingLayer 4 -routeBottomRoutingLayer 1 \
  -drouteFixAntenna true -routeInsertAntennaDiode true -routeAntennaCellName STD_ANTENNA_DIODE \
  -drouteUseMultiCutViaEffort high -routeConcurrentMinimizeViaCountEffort high \
  -drouteEndIteration 80
setDelayCalMode -SIAware true
routeDesign -globalDetail

setExtractRCMode -engine postRoute -effortLevel medium -coupled true
setOptMode -fixHoldAllowSetupTnsDegrade false -holdTargetSlack 0.05 -setupTargetSlack 0.05
optDesign -postRoute -outDir $RPT/postroute_opt
optDesign -postRoute -hold -outDir $RPT/postroute_hold
# a last incremental route clean-up after optimisation ECOs
routeDesign -wireOpt

# core fillers (__STDCELL_FAMILY__ has no decap / tap cells)
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
stage_db 04_route
rpt postRoute
puts "INN_STAGE_DONE route"
