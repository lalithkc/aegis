# ---------------------------------------------------------------------------
# Common settings for all Innovus stages (aegis_chip, __PDK_180NM__ __METAL_STACK__)
# ---------------------------------------------------------------------------
set FLOW $PROJ_ROOT
set PDK  $PDK_ROOT
set SYN  $FLOW/outputs/syn
set DBS  $FLOW/outputs/pnr/dbs
set RPT  $FLOW/reports/pnr
set OUTP $FLOW/outputs/pnr
foreach d [list $DBS $RPT $OUTP] { file mkdir $d }

setMultiCpuUsage -localCpu 8

# reports never abort a stage
proc safe {args} { if {[catch {uplevel 1 $args} m]} { puts "REPORT_WARNING: $args -> $m" } }
proc rpt {stage} {
  global RPT
  safe timeDesign -$stage -outDir $RPT/timing_$stage -prefix $stage
  if {$stage ne "prePlace" && $stage ne "preCTS"} {
    safe timeDesign -$stage -hold -outDir $RPT/timing_$stage -prefix ${stage}_hold
  }
  safe report_area -out_file $RPT/area_$stage.rpt
  safe checkPlace $RPT/checkplace_$stage.rpt
}

proc stage_db {name} {
  global DBS
  saveDesign $DBS/$name.enc
}
