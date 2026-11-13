# ---------------------------------------------------------------------------
# Innovus stage 1: init, pad ring, floorplan, macros, power grid
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl

# ---------------- design import ----------------
set init_lef_file [list \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/lef/__STDCELL___tech.lef \
  $PDK/stdcell/__STDCELL_DIR__/__METAL_STACK__/lef/__STDCELL___std.lef \
  $PDK/iopad/__IOPAD_DIR__/__METAL_STACK__/lef/__IOPAD_LIB___4lm.lef \
  $FLOW/lib/lef/MEM_SP_2048x36.lef \
  $FLOW/lib/lef/MEM_SP_4096x52.lef \
  $FLOW/lib/lef/MEM_SP_64x32.lef ]
set init_verilog   $SYN/aegis_chip.syn.v
set init_top_cell  aegis_chip
set init_design_settop 1
set init_pwr_net   {VDD VDDO}
set init_gnd_net   {VSS VSSO}
set init_mmmc_file $FLOW/scripts/inn_mmmc.tcl
setDesignMode -process 180
init_design

# ---------------- global PG connections ----------------
proc do_gnc {} {
  clearGlobalNets
  globalNetConnect VDD  -type pgpin -pin VDD  -inst * -override
  globalNetConnect VSS  -type pgpin -pin VSS  -inst * -override
  globalNetConnect VDDO -type pgpin -pin VDDO -inst * -override
  globalNetConnect VSSO -type pgpin -pin VSSO -inst * -override
  # no tie cells in __STDCELL_FAMILY__: constants connect straight to the rails
  globalNetConnect VDD -type tiehi -inst * -override
  globalNetConnect VSS -type tielo -inst * -override
}

# ---------------- physical-only pad cells ----------------
# Per side: 2x pvdi (core VDD), 2x pv0i (core VSS), pvda (VDDO), pv0a (VSSO)
set pads(N) {PVDD_N0 PVSS_N0 u_pad_spi_sck u_pad_spi_cs_n PVDDO_N PVSSO_N u_pad_spi_mosi u_pad_spi_miso PVSS_N1 PVDD_N1}
set pads(E) {PVDD_E0 PVSS_E0 u_pad_scan_in0 u_pad_scan_in1 PVDDO_E PVSSO_E u_pad_scan_in2 u_pad_scan_in3 PVSS_E1 PVDD_E1}
set pads(S) {PVDD_S0 PVSS_S0 u_pad_scan_out0 u_pad_scan_out1 PVDDO_S PVSSO_S u_pad_scan_out2 u_pad_scan_out3 PVSS_S1 PVDD_S1}
set pads(W) {PVDD_W0 PVSS_W0 u_pad_rst u_pad_clk PVDDO_W PVSSO_W u_pad_test_mode u_pad_scan_en PVSS_W1 PVDD_W1}
foreach s {N E S W} {
  foreach p $pads($s) {
    switch -glob $p {
      PVDDO_* { addInst -physical -cell pvda -inst $p }
      PVSSO_* { addInst -physical -cell pv0a -inst $p }
      PVDD_*  { addInst -physical -cell pvdi -inst $p }
      PVSS_*  { addInst -physical -cell pv0i -inst $p }
    }
  }
}
foreach c {CORNER_LL CORNER_LR CORNER_UL CORNER_UR} { addInst -physical -cell IO_CORNER_CELL -inst $c }
do_gnc

# ---------------- die / core sizing ----------------
# Core size from the synthesized std-cell area at target density plus the
# macro footprint (with halos); square core, snapped to the row grid.
set PAD_H 250.0 ;  set CORNER 250.0 ; set PAD_W 65.0
set GAP   70.0  ;# pad ring -> core: core rings + spacing
set std_area 0.0
foreach a [dbGet [dbGet -p2 top.insts.cell.subClass core].cell.size_x] b [dbGet [dbGet -p2 top.insts.cell.subClass core].cell.size_y] {
  set std_area [expr {$std_area + $a*$b}]
}
set macro_area 0.0
foreach i [dbGet -p2 top.insts.cell.subClass block] {
  set macro_area [expr {$macro_area + ([dbGet $i.cell.size_x]+50)*([dbGet $i.cell.size_y]+50)}]
}
set TARGET_UTIL 0.48
set core_side [expr {sqrt($std_area/$TARGET_UTIL + $macro_area)}]
set core_side [expr {max($core_side, 2700.0)}]
set CW [expr {ceil($core_side/0.56)*0.56}]
set CH [expr {ceil($core_side/5.6)*5.6}]
set M  [expr {$PAD_H + $GAP}]
# die = core + margins, rounded so (die - 2*corner) is a multiple of 0.01
set DW [expr {ceil(($CW + 2*$M)*100)/100.0}]
set DH [expr {ceil(($CH + 2*$M)*100)/100.0}]
puts "FLOORPLAN: std_area=[format %.0f $std_area] macro_area=[format %.0f $macro_area] core=${CW}x${CH} die=${DW}x${DH}"

# with pad cells present the margins are measured from the I/O ring inner edge
floorPlan -site CoreSite -d $DW $DH $GAP $GAP $GAP $GAP
# the die may be snapped to the track grid: use the real size from here on
lassign [lindex [dbGet top.fPlan.box] 0] - - DW DH
puts "FLOORPLAN: actual die ${DW}x${DH}"
# core box may be snapped slightly; read it back
set CX0 [dbGet top.fPlan.coreBox_llx] ; set CY0 [dbGet top.fPlan.coreBox_lly]
set CX1 [dbGet top.fPlan.coreBox_urx] ; set CY1 [dbGet top.fPlan.coreBox_ury]

# ---------------- I/O file (pads evenly spaced per side) ----------------
set iof [open $FLOW/scripts/aegis_chip.io w]
puts $iof "(globals\n  version = 3\n  io_order = default\n)"
puts $iof "(iopad"
puts $iof "  (topleft (inst name=\"CORNER_UL\"))"
puts $iof "  (topright (inst name=\"CORNER_UR\"))"
puts $iof "  (bottomleft (inst name=\"CORNER_LL\"))"
puts $iof "  (bottomright (inst name=\"CORNER_LR\"))"
foreach {s side len} [list N top $DW S bottom $DW E right $DH W left $DH] {
  set n [llength $pads($s)]
  set avail [expr {$len - 2*$CORNER}]
  set pitch [expr {floor(($avail / $n)*100)/100.0}]
  set first [expr {$CORNER + floor((($avail - $pitch*($n-1) - $PAD_W)/2.0)*100)/100.0}]
  puts $iof "  ($side"
  set k 0
  foreach p $pads($s) {
    set off [format %.2f [expr {$first + $k*$pitch}]]
    puts $iof "    (inst name=\"$p\" offset=$off place_status=fixed)"
    incr k
  }
  puts $iof "  )"
}
puts $iof ")"
close $iof
loadIoFile $FLOW/scripts/aegis_chip.io
# IO_CORNER_CELL is drawn as the BOTTOM-RIGHT corner in R0 (LEF: ENDCAP BOTTOMRIGHT):
# its pad-ring buses enter from its left and top edges.  Orient explicitly.
set CS 250.0
placeInstance CORNER_LR [expr {$DW-$CS}] 0                R0   -fixed
placeInstance CORNER_LL 0                0                MY   -fixed
placeInstance CORNER_UR [expr {$DW-$CS}] [expr {$DH-$CS}] MX   -fixed
placeInstance CORNER_UL 0                [expr {$DH-$CS}] R180 -fixed
# pad-ring fillers keep the VDDO/VDD/VSSO/VSS pad buses continuous
addIoFiller -cell {pfeed30000 pfeed10000 pfeed02000 pfeed01000 pfeed00540 pfeed00120 pfeed00040 pfeed00010} -prefix IOFILL -side n
addIoFiller -cell {pfeed30000 pfeed10000 pfeed02000 pfeed01000 pfeed00540 pfeed00120 pfeed00040 pfeed00010} -prefix IOFILL -side s
addIoFiller -cell {pfeed30000 pfeed10000 pfeed02000 pfeed01000 pfeed00540 pfeed00120 pfeed00040 pfeed00010} -prefix IOFILL -side e
addIoFiller -cell {pfeed30000 pfeed10000 pfeed02000 pfeed01000 pfeed00540 pfeed00120 pfeed00040 pfeed00010} -prefix IOFILL -side w
do_gnc

# ---------------- macro placement ----------------
# SRAM 2048x36 / 4096x52: control+address on the bottom edge, data on the
# right edge, PG on TOP_M at top/bottom.  Orient so those edges face logic.
set H 30.0   ;# macro-to-core-edge / macro-to-macro clearance (block ring + halo)
proc inst_of {pat} { return [lindex [dbGet -e top.insts.name $pat] 0] }
proc place_m {pat x y orient} {
  set n [inst_of $pat]
  if {$n eq ""} { puts "WARNING: macro $pat not found"; return }
  placeInstance $n [expr {round($x/0.005)*0.005}] [expr {round($y/0.005)*0.005}] $orient -fixed
  puts "MACRO $n at $x $y $orient"
}
set IW 1137.24 ; set IH 373.99 ; set DMW 1625.56 ; set DMH 697.83 ; set CWm 308.88 ; set CHm 89.55
# core0 instruction banks: top edge
place_m *c0_imem_bank0 [expr {$CX0+$H}]          [expr {$CY1-$H-$IH}] R0
place_m *c0_imem_bank1 [expr {$CX1-$H-$IW}]      [expr {$CY1-$H-$IH}] MY
# core1 instruction banks: bottom edge
place_m *c1_imem_bank0 [expr {$CX0+$H}]          [expr {$CY0+$H}]     MX
place_m *c1_imem_bank1 [expr {$CX1-$H-$IW}]      [expr {$CY0+$H}]     R180
# shared data memory: left edge, vertically centred
place_m *u_main_mem*sram_inst [expr {$CX0+$H}]   [expr {($CY0+$CY1)/2.0-$DMH/2.0}] R0
# per-core cache data RAMs: right edge, above / below centre
set cache_insts [dbGet -e [dbGet -p2 top.insts.cell.name MEM_SP_64x32].name]
puts "CACHE RAMs: $cache_insts"
set ci 0
foreach c [lsort $cache_insts] {
  set y [expr {$ci==0 ? ($CY0+$CY1)/2.0+150.0 : ($CY0+$CY1)/2.0-150.0-$CHm}]
  placeInstance $c [expr {round(($CX1-$H-$CWm)/0.005)*0.005}] [expr {round($y/0.005)*0.005}] MY -fixed
  incr ci
}
addHaloToBlock 25 25 25 25 -allBlock
# keep std cells out of the narrow channels beside the macros' PG rings
setPlaceMode -place_detail_check_route true

# ---------------- power planning ----------------
# core ring: M3 horizontal / TOP_M vertical, 20 um wide
addRing -nets {VDD VSS} -type core_rings -follow core \
  -layer {top M3 bottom M3 left TOP_M right TOP_M} \
  -width 20 -spacing 3 -offset 5 -center 0
# a ring around every SRAM (inside its halo)
addRing -nets {VDD VSS} -type block_rings -around each_block \
  -layer {top M3 bottom M3 left TOP_M right TOP_M} \
  -width 5 -spacing 1.5 -offset 2
# stripes stop at block rings so they never cross SRAM TOP_M obstructions
setAddStripeMode -break_at {block_ring} -stacked_via_bottom_layer M1 -stacked_via_top_layer TOP_M
addStripe -nets {VDD VSS} -layer TOP_M -direction vertical \
  -width 8 -spacing 2 -set_to_set_distance 100 -start_from left -start_offset 40 \
  -block_ring_top_layer_limit TOP_M -block_ring_bottom_layer_limit M3 \
  -padcore_ring_top_layer_limit TOP_M -padcore_ring_bottom_layer_limit M3
addStripe -nets {VDD VSS} -layer M3 -direction horizontal \
  -width 4 -spacing 2 -set_to_set_distance 280 -start_from bottom -start_offset 140 \
  -block_ring_top_layer_limit TOP_M -block_ring_bottom_layer_limit M3 \
  -padcore_ring_top_layer_limit TOP_M -padcore_ring_bottom_layer_limit M3
# pad core-supply stubs -> core ring
# Same-layer only (M3 to the horizontal ring sides, TOP_M to the vertical
# sides): no vias are dropped inside the 2.5 um deep pad pin stubs.
sroute -connect {padPin} -nets {VDD VSS} -padPinPortConnect {allPort allGeom} \
  -padPinLayerRange {M3 TOP_M} -padPinTarget {ring} -allowJogging 0 -allowLayerChange 0
# pad-ring buses through the pfeed fillers (filler LEFs carry no pins)
sroute -connect {padRing} -nets {VDD VSS VDDO VSSO}
# SRAM PG pins -> block rings
sroute -connect {blockPin} -nets {VDD VSS} -blockPinTarget {blockring} \
  -blockPin useLef -allowJogging 1 -allowLayerChange 1 -layerChangeRange {M1 TOP_M}
# std-cell M1 follow-pins
sroute -connect {corePin} -nets {VDD VSS} -corePinTarget {ring stripe blockring} \
  -allowJogging 1 -allowLayerChange 1 -layerChangeRange {M1 TOP_M}

verify_PG_short -no_routing_blkg > $RPT/pg_short_fp.rpt
verifyConnectivity -type special -noAntenna -error 1000 -report $RPT/pg_conn_fp.rpt
checkDesign -all -outdir $RPT/checkDesign_fp

# scan chains for reorder during placement
defIn $SYN/aegis_chip.scandef

stage_db 01_floorplan
puts "INN_STAGE_DONE floorplan"
