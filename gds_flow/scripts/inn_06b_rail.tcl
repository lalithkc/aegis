source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/05_final.enc.dat aegis_chip
set PR $FLOW/reports/power
set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view func_ss -corner max -create_binary_db true -write_static_currents true
set_default_switching_activity -input_activity 0.2 -period 10.0 -seq_activity 0.2 -clock_gates_output 0.5
set_power_output_dir $PR/vs
report_power -rail_analysis_format VS -outfile $PR/power_static_vs.rpt
set_rail_analysis_mode -method static -accuracy xd -analysis_view func_ss \
  -power_grid_library $PR/pgv/techonly.cl -temp_directory_name $PR/tmp -ignore_shorts true
set_pg_nets -net VDD -voltage 1.62 -threshold 1.539
set_power_data -reset
set_power_data -format current -scale 1 $PR/static_VDD.ptiavg
set_power_pads -reset
set_power_pads -net VDD -format xy -file $PR/pads_VDD_wire.xy
analyze_rail -type net -results_directory $PR/rail VDD
puts RAIL_DONE
