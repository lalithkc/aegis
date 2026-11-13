# ---------------------------------------------------------------------------
# Tempus signoff STA: all modes x corners, SI-aware, Quantus SPEF
# ---------------------------------------------------------------------------
set FLOW $PROJ_ROOT
set R $FLOW/reports/sta
file mkdir $R
set SDC_DIR $FLOW/outputs/syn
read_view_definition $FLOW/scripts/mmmc_legacy.tcl
read_verilog $FLOW/outputs/pnr/aegis_chip.pnr.v
set_top_module aegis_chip
read_spef -rc_corner rc_125 $FLOW/outputs/pnr/spef/aegis_chip_rc_125.spef.gz
read_spef -rc_corner rc_m40 $FLOW/outputs/pnr/spef/aegis_chip_rc_m40.spef.gz
set_analysis_view -setup {func_ss scan_shift_ss scan_capture_ss} \
                  -hold  {func_ff scan_shift_ff scan_capture_ff func_ss}
set_delay_cal_mode -siAware true
set_si_mode -enable_glitch_report true
set_analysis_mode -analysisType onChipVariation -cppr both
set_interactive_constraint_modes [all_constraint_modes]
set_propagated_clock [all_clocks]
set_interactive_constraint_modes {}
update_timing -full
report_analysis_summary          > $R/analysis_summary.rpt
report_analysis_coverage         > $R/coverage.rpt
check_timing -verbose            > $R/check_timing.rpt
foreach v {func_ss scan_shift_ss scan_capture_ss} {
  report_timing -late  -view $v -max_paths 50 -path_type full_clock > $R/setup_$v.rpt
}
foreach v {func_ff scan_shift_ff scan_capture_ff func_ss} {
  report_timing -early -view $v -max_paths 50 -path_type full_clock > $R/hold_$v.rpt
}
report_constraint -all_violators -drv_violation_type {max_transition max_capacitance max_fanout} > $R/drv.rpt
report_noise -failure            > $R/si_glitch.rpt
report_clocks                    > $R/clocks.rpt
puts "TEMPUS_DONE"
exit
