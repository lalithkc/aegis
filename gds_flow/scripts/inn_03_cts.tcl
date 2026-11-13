# ---------------------------------------------------------------------------
# Innovus stage 3: clock tree synthesis (CCOpt) + post-CTS optimisation
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/02_place.enc.dat aegis_chip
setAnalysisMode -analysisType onChipVariation -cppr both

# double-width / double-space clock routes on M2/M3
add_ndr -name CLK_NDR -width {M1 0.23 M2 0.56 M3 0.56 TOP_M 0.88} -spacing {M1 0.23 M2 0.56 M3 0.56 TOP_M 0.92}
create_route_type -name clk_trunk -non_default_rule CLK_NDR -top_preferred_layer M3 -bottom_preferred_layer M2 -shield_net VSS
create_route_type -name clk_leaf  -top_preferred_layer M3 -bottom_preferred_layer M2
set_ccopt_property route_type clk_trunk -net_type trunk
set_ccopt_property route_type clk_leaf  -net_type leaf
set_ccopt_property buffer_cells   {STD_BUF_1 STD_BUF_2 STD_BUF_3 STD_BUF_4 STD_BUF_7 STD_BUF_a}
set_ccopt_property inverter_cells {invbd2 invbd4 invbd7 invbda}
set_ccopt_property clock_gating_cells {gclrsn1 gclrsn2 gclrsn4 gclrsn7 gclrsna gcnrnn1 gcnrnn2 gcnrnn4 gcnrnn7 gcnrnna}
set_ccopt_property target_max_trans 0.40
set_ccopt_property target_skew 0.20
set_ccopt_property use_inverters auto

create_ccopt_clock_tree_spec -file $RPT/ccopt.spec
source $RPT/ccopt.spec
ccopt_design -outDir $RPT/ccopt
safe report_ccopt_clock_trees -file $RPT/cts_clock_trees.rpt
safe report_ccopt_skew_groups -file $RPT/cts_skew_groups.rpt

set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
set_interactive_constraint_modes {}
setOptMode -fixHoldAllowSetupTnsDegrade false -holdTargetSlack 0.05 -setupTargetSlack 0.05
optDesign -postCTS -outDir $RPT/postcts_opt
optDesign -postCTS -hold -outDir $RPT/postcts_hold
stage_db 03_cts
rpt postCTS
puts "INN_STAGE_DONE cts"
