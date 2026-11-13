#!/bin/bash
# ---------------------------------------------------------------------------
# Finish the sign-off once the (remote) licence servers are reachable again:
#   hold + antenna ECO -> Innovus export -> Calibre (fill/DRC/antenna/LVS)
#   -> Tempus STA -> LEC (syn vs routed) -> SDF gate-level sims (SS, FF)
# Every tool step is retried while the licence servers refuse checkout.
# ---------------------------------------------------------------------------
FLOW=$PROJ_ROOT
cd $FLOW
R=$FLOW/run.sh
log() { echo "=== $(date '+%F %T') $*"; }

lic_up() {
  # real licence checkout test (raw TCP probes are unreliable on this network)
  printf "puts LICTEST_OK\nexit\n" > $FLOW/work/lictest.tcl
  timeout 300 $R "cd work; innovus -no_gui -batch -files lictest.tcl -log lictest.log" 2>&1 | grep -q LICTEST_OK
}
wait_lic() {
  until lic_up; do log "licence servers unreachable, waiting"; sleep 120; done
}
# run_tool <logfile> <pattern-that-means-licence-failure> <command...>
run_tool() {
  local lf=$1 pat=$2; shift 2
  for i in $(seq 1 40); do
    wait_lic
    $R "$*" > $lf 2>&1
    grep -qiE "$pat" $lf || return 0
    log "licence checkout failed ($lf), retry $i"; sleep 120
  done
  log "giving up on $lf"; return 1
}
INNLIC="Fail to find any innovus license|Cannot connect to license server"

if [ "${START:-1}" -le 1 ]; then
log "1/6 critical-path ECO"
run_tool logs/inn_04h.out "$INNLIC" "cd work/innovus; innovus -no_gui -batch -files ../../scripts/inn_04h_skew.tcl -log ../../logs/inn_04h.log"
fi

log "2/6 Innovus signoff export"
run_tool logs/inn_05.out "$INNLIC" "cd work/innovus; innovus -no_gui -batch -files ../../scripts/inn_05_signoff_export.tcl -log ../../logs/inn_05_signoff.log"
grep -E "INN_STAGE_DONE" logs/inn_05.out

log "3/6 Calibre chip finishing + DRC/antenna/LVS"
for i in $(seq 1 40); do
  wait_lic
  bash scripts/run_calibre_signoff.sh > logs/calibre_signoff.out 2>&1
  grep -qhE "could not be licensed|Cannot connect" work/calibre/*/*.log logs/calibre_signoff.out || break
  log "Calibre licence problem, retry $i"; sleep 120
done
tail -12 logs/calibre_signoff.out

log "4/6 Tempus"
run_tool logs/tempus.out "$INNLIC|Tempus.*licen" "cd work/tempus; tempus -no_gui -files ../../scripts/tempus_signoff.tcl -log ../../logs/tempus_signoff.log"

log "5/6 LEC synthesized vs routed netlist"
run_tool logs/lec_syn2pnr.out "license.*(fail|denied)|Cannot connect" "cd work/lec2; lec -XL -nogui -dofile ../../scripts/lec_syn2pnr.do"

log "6/6 SDF gate-level simulation"
for c in ss ff; do
  run_tool logs/gls_sdf_$c.out "license.*(fail|denied)|Cannot connect" "xrun -64bit -sv -timescale 1ns/1ps +neg_tchk -sdf_cmd_file scripts/sdf_$c.cmd -f scripts/sim_gls.f -top tb_aegis_chip -xmlibdirname work/gls_sdf/x_$c.d -l logs/gls_sdf_$c.log"
  grep -hE "PASSED|GLS core|expected" logs/gls_sdf_$c.log
done
log FINISH_SIGNOFF_DONE
