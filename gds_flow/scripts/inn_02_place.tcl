# ---------------------------------------------------------------------------
# Innovus stage 2: placement + pre-CTS optimisation
# ---------------------------------------------------------------------------
source $PROJ_ROOT/scripts/inn_common.tcl
restoreDesign $DBS/01_floorplan.enc.dat aegis_chip

setDesignMode -process 180 -topRoutingLayer TOP_M -bottomRoutingLayer M1
setDontUse feedth true ; setDontUse feedth3 true ; setDontUse feedth9 true
setDontUse STD_ANTENNA_DIODE true ; setDontUse bh01d1 true ; setDontUse cload1 true
setAnalysisMode -analysisType onChipVariation -cppr both
setPlaceMode -place_global_timing_effort high -place_global_cong_effort high \
             -place_global_reorder_scan true -place_detail_check_route true
setOptMode -fixFanoutLoad true -addInstancePrefix PREPLACE_ -usefulSkew false
setTieHiLoMode -reset

place_opt_design -out_dir $RPT/place_opt
stage_db 02_place
# scan reorder already done in place_opt; report chains
safe reportScanChain -outfile $RPT/scan_chains_place.rpt
rpt preCTS
safe reportCongestion -hotSpot -overflow
puts "INN_STAGE_DONE place"
