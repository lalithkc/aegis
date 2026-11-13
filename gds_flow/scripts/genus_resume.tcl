# ---------------------------------------------------------------------------
# Genus continuation: resume from the post-syn_map snapshot, then scan
# stitching, incremental optimisation, reports and outputs.
# (identical to the tail of genus_syn.tcl)
# ---------------------------------------------------------------------------
set FLOW $PROJ_ROOT
set PDK  $PDK_ROOT
set OUT  $FLOW/outputs/syn
set RPT  $FLOW/reports/syn
file mkdir $OUT $RPT
set_db information_level 7
set_db max_cpus_per_server 8
set_db super_thread_servers {localhost localhost}
read_db $RPT/map_aegis_chip.db
current_design aegis_chip
# ---------------- scan chains ----------------
for {set i 0} {$i < 4} {incr i} {
  define_scan_chain -name chain$i -shift_enable se \
    -sdi scan_in[$i]  -hookup_pin_sdi u_pad_scan_in$i/CIN \
    -sdo scan_out[$i] -hookup_pin_sdo u_pad_scan_out$i/I -non_shared_output
}
redirect $RPT/dft_connect_preview.rpt {connect_scan_chains -preview}
connect_scan_chains -dont_exceed_min_number_of_scan_chains

syn_opt
syn_opt -incremental
write_snapshot -outdir $RPT -tag opt

# ---------------- reports ----------------
report_scan_chains           > $RPT/dft_scan_chains.rpt
report_scan_setup            > $RPT/dft_setup.rpt
check_dft_rules              > $RPT/dft_rules_final.rpt
check_design -all            > $RPT/check_design_final.rpt
report_qor                   > $RPT/qor.rpt
report_area                  > $RPT/area.rpt
report_gates                 > $RPT/gates.rpt
report_clock_gating          > $RPT/clock_gating.rpt
report_power                 > $RPT/power.rpt
foreach v {func_ss scan_shift_ss scan_capture_ss} {
  report_timing -views $v -max_paths 20 > $RPT/timing_$v.rpt
}
report_timing -views func_ss -lint > $RPT/timing_lint.rpt

# ---------------- outputs ----------------
write_hdl                > $OUT/aegis_chip.syn.v
foreach m {func scan_shift scan_capture} {
  write_sdc -view ${m}_ss > $OUT/aegis_chip_${m}.sdc
}
write_scandef            > $OUT/aegis_chip.scandef
write_do_lec -revised_design $OUT/aegis_chip.syn.v -logfile $FLOW/logs/lec_rtl2syn.log > $OUT/rtl2syn.lec.do

set PADV [glob $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/verilog/__IOPAD_LIB__/zero/p*.v]
set VLIB [concat $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/verilog/vcs_sim_model/__STDCELL_LIB__.v $PADV \
          $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_2048x36/MEM_SP_2048x36.v \
          $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_4096x52/MEM_SP_4096x52.v \
          $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_64x32/MEM_SP_64x32.v]
catch {write_dft_atpg -library $VLIB -directory $FLOW/outputs/atpg} atpg_msg
puts "write_dft_atpg: $atpg_msg"

write_db $OUT/aegis_chip.syn.db
puts "GENUS_SYN_DONE"
exit
