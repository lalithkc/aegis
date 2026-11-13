# ---------------------------------------------------------------------------
# Genus 21.1 -- synthesis + scan DFT for aegis_chip (__PDK_180NM__ __METAL_STACK__)
# run:  genus -no_gui -files scripts/genus_syn.tcl -log logs/genus_syn.log
# ---------------------------------------------------------------------------
set FLOW $PROJ_ROOT
set PDK  $PDK_ROOT
set OUT  $FLOW/outputs/syn
set RPT  $FLOW/reports/syn
file mkdir $OUT $RPT

set_db information_level 7
# clock gating must be enabled before any design/MMMC data is read
set_db lp_insert_clock_gating true
set_db hdl_error_on_blackbox true
set_db hdl_error_on_latch false
set_db max_cpus_per_server 8
set_db super_thread_servers {localhost localhost}

# ---------------- libraries (MMMC) + physical ----------------
read_mmmc $FLOW/scripts/mmmc.tcl
read_physical -lef [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/lef/__STDCELL___tech.lef \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/lef/__STDCELL___std.lef \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/lef/__IOPAD_LIB___4lm.lef \
  $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_2048x36/MEM_SP_2048x36.lef \
  $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_4096x52/MEM_SP_4096x52.lef \
  $PDK/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_64x32/MEM_SP_64x32.lef ]

# Cells not to be used for synthesis (special-purpose / no proper models)
foreach c {feedth feedth3 feedth9 STD_ANTENNA_DIODE bh01d1 cload1 clk2d2 jkbrb1 jkbrb2 jkbrb4 skbrb1 skbrb2 skbrb4} {
  catch {set_db [get_db lib_cells */$c] .dont_use true}
}

# ---------------- RTL ----------------
set RTL {}
foreach f [split [string trim [exec cat $FLOW/scripts/sim_rtl_files.f]] "\n"] {
  lappend RTL $FLOW/[string trim $f]
}
lappend RTL $FLOW/rtl/aegis_chip.v
read_hdl -language v2001 $RTL
elaborate aegis_chip
init_design
current_design aegis_chip

check_design -unresolved > $RPT/check_design_unresolved.rpt
check_design -all         > $RPT/check_design_elab.rpt
check_timing_intent       > $RPT/check_timing_intent.rpt

# Pads are instantiated cells: keep them exactly as written.
set_dont_touch [get_db insts u_pad_*] true

# ---------------- DFT setup ----------------
set_db dft_scan_style muxed_scan
set_db dft_prefix DFT_
set_db design:aegis_chip .dft_mix_clock_edges_in_scan_chains true
set_db design:aegis_chip .dft_lockup_element_type preferred_level_sensitive
set_db design:aegis_chip .dft_min_number_of_scan_chains 4

define_shift_enable -name se  -active high -hookup_pin u_pad_scan_en/CIN   scan_enable
define_test_mode    -name tm  -active high -hookup_pin u_pad_test_mode/CIN test_mode
define_test_mode    -name rsoff -active low -hookup_pin u_pad_rst/CIN      rst
define_test_mode    -name csoff -active low -hookup_pin u_pad_spi_cs_n/CIN spi_cs_n
# One tester clock domain feeds both functional clocks (lock-ups at crossings)
define_test_clock -name tclk -domain tdom -period 20000 -hookup_pin u_pad_clk/CIN     clk
define_test_clock -name tsck -domain tdom -period 20000 -hookup_pin u_pad_spi_sck/CIN spi_sck

check_dft_rules > $RPT/dft_rules_pre.rpt

# ---------------- clock-gating test control ----------------
set_db design:aegis_chip .lp_clock_gating_test_signal [get_db test_signals se]
# __STDCELL_FAMILY__ ICGs (gclrsn*/gcnrnn*) are latch_posedge_postcontrol
set_db design:aegis_chip .lp_clock_gating_control_point postcontrol
set_db design:aegis_chip .lp_clock_gating_min_flops 4

# ---------------- synthesis ----------------
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

syn_generic
write_snapshot -outdir $RPT -tag generic
syn_map
write_snapshot -outdir $RPT -tag map

check_dft_rules > $RPT/dft_rules_post_map.rpt
report_scan_registers > $RPT/dft_scan_registers.rpt

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
