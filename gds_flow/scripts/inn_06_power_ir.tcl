# ---------------------------------------------------------------------------
# Power signoff: vectorless static power + static IR drop / EM (Voltus engine)
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/05_final.enc.dat aegis_chip
set PR $FLOW/reports/power
file mkdir $PR

# ---------- power (SS corner, 100 MHz, 20% input / 20% flop toggle) ----------
set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view func_ss -corner max \
  -create_binary_db true -write_static_currents true -honor_negative_energy true
set_default_switching_activity -input_activity 0.2 -period 10.0 -seq_activity 0.2 -clock_gates_output 0.5
set_power_output_dir $PR/static
report_power -outfile $PR/power_static.rpt -hierarchy all

# ---------- tech-only power-grid views ----------
set_pg_library_mode -celltype techonly -default_area_cap 0.5 -power_pins {VDD 1.62} -ground_pins {VSS} \
  -extraction_tech_file $FLOW/lib/qrc/qrcTechFile -lef_layermap {}
catch {generate_pg_library -output $PR/pgv}

# ---------- core-supply pad locations (pvdi / pv0i core-side stubs) ----------
foreach {net cell} {VDD pvdi VSS pv0i} {
  set fp [open $PR/pads_$net.xy w]
  foreach i [dbGet -p2 top.insts.cell.name $cell] {
    set b [lindex [dbGet $i.box] 0]
    puts $fp "[dbGet $i.name] [expr {([lindex $b 0]+[lindex $b 2])/2.0}] [expr {([lindex $b 1]+[lindex $b 3])/2.0}] TOP_M"
  }
  close $fp
}

# ---------- static rail analysis ----------
set_rail_analysis_mode -method static -accuracy xd -analysis_view func_ss \
  -power_grid_library $PR/pgv/techonly.cl -process_techgen_em_rules true \
  -temp_directory_name $PR/tmp -ignore_shorts true
set_pg_nets -net VDD -voltage 1.62 -threshold 1.539
set_pg_nets -net VSS -voltage 0.0  -threshold 0.081
set_power_data -reset
set_power_data -format current -scale 1 [list $PR/static/static_VDD.ptiavg $PR/static/static_VSS.ptiavg]
set_power_pads -reset
set_power_pads -net VDD -format xy -file $PR/pads_VDD.xy
set_power_pads -net VSS -format xy -file $PR/pads_VSS.xy
analyze_rail -type net -results_directory $PR/rail VDD
analyze_rail -type net -results_directory $PR/rail VSS
puts "POWER_IR_DONE"
