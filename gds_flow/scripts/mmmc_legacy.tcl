# ---------------------------------------------------------------------------
# MMMC setup for aegis_chip (__PDK_180NM__ __METAL_STACK__) -- shared by Genus/Innovus/Tempus
#   Corners : SS (1.62 V, 125 C)  -> setup     FF (1.98 V, -40 C) -> hold
#   Modes   : func, scan_shift, scan_capture
# Legacy-UI variant (Innovus/Tempus legacy mode): delay corners take
# -library_set directly instead of timing conditions.
# Optional:  set SDC_DIR before sourcing to use mode SDCs from another place
#            (Innovus uses the Genus-written SDCs).
# ---------------------------------------------------------------------------
set PDK  $PDK_ROOT
set FLOW $PROJ_ROOT
if {![info exists SDC_DIR]} { set SDC_DIR $FLOW/constraints }
set SRAM $PDK/memory/__MEM_DIR__/__METAL_STACK__

set LIB_SS [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/liberty/lib_flow_ss/__STDCELL_LIB___ss.lib \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/liberty/__IOPAD_LIB___max.lib \
  $SRAM/MEM_SP_2048x36/MEM_SP_2048x36_max_SP.lib \
  $SRAM/MEM_SP_4096x52/MEM_SP_4096x52_max_SP.lib \
  $SRAM/MEM_SP_64x32/MEM_SP_64x32_max.lib ]
set LIB_FF [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/liberty/lib_flow_ff/__STDCELL_LIB___ff.lib \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/liberty/__IOPAD_LIB___min.lib \
  $SRAM/MEM_SP_2048x36/MEM_SP_2048x36_min_SP.lib \
  $SRAM/MEM_SP_4096x52/MEM_SP_4096x52_min_SP.lib \
  $SRAM/MEM_SP_64x32/MEM_SP_64x32_min.lib ]

create_library_set -name libs_ss -timing $LIB_SS
create_library_set -name libs_ff -timing $LIB_FF

# RC corners: one foundry stack (typical), evaluated at the corner temperature.
set QRC $FLOW/lib/qrc/qrcTechFile
if {[file exists $QRC]} {
  create_rc_corner -name rc_125 -T 125 -qx_tech_file $QRC
  create_rc_corner -name rc_m40 -T -40 -qx_tech_file $QRC
} else {
  create_rc_corner -name rc_125 -T 125
  create_rc_corner -name rc_m40 -T -40
}

create_delay_corner -name dc_ss -library_set libs_ss -rc_corner rc_125
create_delay_corner -name dc_ff -library_set libs_ff -rc_corner rc_m40

create_constraint_mode -name func         -sdc_files $SDC_DIR/aegis_chip_func.sdc
create_constraint_mode -name scan_shift   -sdc_files $SDC_DIR/aegis_chip_scan_shift.sdc
create_constraint_mode -name scan_capture -sdc_files $SDC_DIR/aegis_chip_scan_capture.sdc

foreach m {func scan_shift scan_capture} {
  create_analysis_view -name ${m}_ss -constraint_mode $m -delay_corner dc_ss
  create_analysis_view -name ${m}_ff -constraint_mode $m -delay_corner dc_ff
}

set_analysis_view \
  -setup [list func_ss scan_shift_ss scan_capture_ss] \
  -hold  [list func_ff scan_shift_ff scan_capture_ff func_ss]
