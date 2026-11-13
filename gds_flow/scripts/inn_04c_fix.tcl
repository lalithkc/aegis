# ---------------------------------------------------------------------------
# Innovus stage 4c: targeted DRC / antenna fixes after closure
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/04_route_closed.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes {func scan_capture}
source $FLOW/constraints/mcp_main_memory.sdc
set_interactive_constraint_modes {}
setDelayCalMode -SIAware true

# free the rows for diode cells (fillers are re-inserted at the end)
deleteFiller -prefix FILL
# 1) antenna: diode on every pin still reported by verifyProcessAntenna
verifyProcessAntenna -report $RPT/ant_before_fix.rpt
set pins {}
set f [open $RPT/ant_before_fix.rpt]
set prev ""
while {[gets $f l] >= 0} {
  if {[regexp {^\s+(\S+)\s+\((\S+)\)\s+(\S+)\s*$} $l -> inst cell term]} { lappend pins [list $inst $term] }
}
close $f
puts "ANTENNA PINS: $pins"
foreach p $pins {
  lassign $p inst term
  safe attachDiode -diodeCell STD_ANTENNA_DIODE -pin $inst $term -prefix ANTFIX
}

# 2) reroute nets that touch SRAM obstructions
set bad {u_core/core0_u_cache_n_13641}
deselectAll
foreach n $bad { safe editDelete -net $n ; selectNet $n }
setNanoRouteMode -routeSelectedNetOnly true -drouteEndIteration 100
safe routeDesign -selected
setNanoRouteMode -routeSelectedNetOnly false
deselectAll
# legalise any diode cells and patch routing
refinePlace -preserveRouting true
ecoRoute -fix_drc
addFiller -cell {feedth9 feedth3 feedth} -prefix FILL
ecoRoute
safe checkPlace $RPT/checkplace_fix.rpt

safe verify_drc -report $RPT/verify_drc_fix.rpt
safe verifyProcessAntenna -report $RPT/verify_antenna_fix.rpt
stage_db 04_route
rpt postRoute
puts "INN_STAGE_DONE fix"
