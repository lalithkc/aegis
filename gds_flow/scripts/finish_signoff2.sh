#!/bin/bash
# ---------------------------------------------------------------------------
# Signoff round 2 (2026-11-07): fix SRAM placeholder pin shorts, re-stream,
# re-run Calibre fill/DRC/antenna/LVS, plus DRC area check with SRAM pins kept.
# Netlist/placement unchanged -> Tempus, LEC and SDF GLS from round 1 stand.
# Waits for the remote licence server (__LICENSE_HOST__:1717) like round 1.
# ---------------------------------------------------------------------------
FLOW=$PROJ_ROOT
cd $FLOW
R=$FLOW/run.sh
log() { echo "=== $(date "+%F %T") $*"; }
lic_up() {
  printf "puts LICTEST_OK\nexit\n" > $FLOW/work/lictest.tcl
  timeout 300 $R "cd work; innovus -no_gui -batch -files lictest.tcl -log lictest.log" 2>&1 | grep -q LICTEST_OK
}
wait_lic() { until lic_up; do log "licence servers unreachable, waiting"; sleep 120; done; }
CALLIC="could not be licensed|Cannot connect|license.*(fail|denied)"

log "1/5 SRAM placeholder GDS (fixed lef2gds_sram.py)"
python3 scripts/lef2gds_sram.py work/mk_sram.tcl lib/lef/MEM_SP_64x32.lef lib/lef/MEM_SP_2048x36.lef lib/lef/MEM_SP_4096x52.lef
for i in $(seq 1 40); do
  wait_lic
  timeout 1800 $R "calibredrv work/mk_sram.tcl" > logs/mk_sram.out 2>&1
  grep -q SRAM_GDS_DONE logs/mk_sram.out && break
  log "calibredrv failed/licence, retry $i"; tail -3 logs/mk_sram.out; sleep 120
done
grep -q SRAM_GDS_DONE logs/mk_sram.out || { log "ABORT: placeholder GDS not built"; exit 1; }

log "2/5 Innovus re-stream with new placeholders"
for i in $(seq 1 40); do
  wait_lic
  $R "cd work/innovus; innovus -no_gui -batch -files ../../scripts/inn_05b_restream.tcl -log ../../logs/inn_05b_restream.log" > logs/inn_05b.out 2>&1
  grep -q RESTREAM_DONE logs/inn_05b.out && break
  log "restream failed/licence, retry $i"; sleep 120
done
grep -q RESTREAM_DONE logs/inn_05b.out || { log "ABORT: restream failed"; exit 1; }

log "3/5 Calibre chip finishing + DRC/antenna/LVS"
for i in $(seq 1 40); do
  wait_lic
  bash scripts/run_calibre_signoff.sh > logs/calibre_signoff2.out 2>&1
  grep -qhE "$CALLIC" work/calibre/*/*.log logs/calibre_signoff2.out || break
  log "Calibre licence problem, retry $i"; sleep 120
done
tail -12 logs/calibre_signoff2.out

log "4/5 DRC area re-check with SRAM pins kept"
W=$FLOW/work/calibre/drc_pins; mkdir -p $W
sed "s#LAYOUT_GDS#$FLOW/outputs/final/aegis_chip.gds#" scripts/calibre/drc_srampins.svrf > $W/drc.svrf
for i in $(seq 1 40); do
  wait_lic
  $R "cd work/calibre/drc_pins; calibre -drc -hier -turbo 16 drc.svrf >& drc.log"
  grep -qE "$CALLIC" $W/drc.log || break
  log "Calibre licence problem, retry $i"; sleep 120
done
grep -E "^RULECHECK .* TOTAL Result Count" $W/drc_srampins.summary | head
cp $W/drc_srampins.summary reports/calibre/drc_srampins.summary

log "5/5 antenna violations -> nets (expect only SRAM-output nets)"
python3 scripts/ant_boxes.py work/calibre/ant/ant.results work/calibre/ant/ant_boxes2.txt 35
python3 scripts/box2net.py outputs/pnr/aegis_chip.def.gz work/calibre/ant/ant_boxes2.txt > reports/calibre/antenna_nets.txt
echo "antenna nets NOT driven by an SRAM O pin:"
tail -n +2 reports/calibre/antenna_nets.txt | grep -v "sram=\[.u_core/u_[a-z0-9_]*/O\[" || echo "  none"
log FINISH_SIGNOFF2_DONE
