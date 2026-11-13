#!/bin/bash
# Chip finishing + physical signoff (run after Innovus stage 5)
#   assemble (seal ring, VSS straps, pad labels) -> dummy fill -> merge
#   -> DRC (CHIP) -> antenna -> LVS (+ERC)
set -e
FLOW=$PROJ_ROOT
R=$FLOW/run.sh
W=$FLOW/work/calibre; mkdir -p $W/{fill,drc,ant,lvs} $FLOW/reports/calibre
step() { echo "=== $(date +%T) $*"; }

step assemble
$R "calibredrv scripts/assemble_chip.tcl >& logs/assemble.log"
grep -E "ASSEMBLY_DONE|VSS strap" $FLOW/logs/assemble.log

step dummy fill
sed "s#LAYOUT_GDS#$FLOW/outputs/final/aegis_chip_nofill.gds#" $FLOW/scripts/calibre/fill.svrf > $W/fill/fill.svrf
$R "cd work/calibre/fill; calibre -drc -hier -turbo 16 fill.svrf >& fill.log"

step merge fill
$R "calibredrv scripts/merge_fill.tcl >& logs/merge_fill.log"
grep -E "MERGE_DONE|fill top" $FLOW/logs/merge_fill.log

GDS=$FLOW/outputs/final/aegis_chip.gds
step DRC
sed "s#LAYOUT_GDS#$GDS#" $FLOW/scripts/calibre/drc.svrf > $W/drc/drc.svrf
$R "cd work/calibre/drc; calibre -drc -hier -turbo 16 drc.svrf >& drc.log"
cp $W/drc/drc.summary $FLOW/reports/calibre/drc.summary

step antenna
sed "s#LAYOUT_GDS#$GDS#" $FLOW/scripts/calibre/ant.svrf > $W/ant/ant.svrf
$R "cd work/calibre/ant; calibre -drc -hier -turbo 16 ant.svrf >& ant.log"
cp $W/ant/ant.summary $FLOW/reports/calibre/antenna.summary

step v2lvs
P=$PDK_ROOT
CDLS="-s $P/stdcell/__STDCELL_DIR__/__METAL_STACK__/cdl/__STDCELL___supply_pins.cdl -s $P/iopad/__IOPAD_DIR__/__METAL_STACK__/cdl/__IOPAD_LIB__.cdl -s $P/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_2048x36/MEM_SP_2048x36.cdl -s $P/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_4096x52/MEM_SP_4096x52.cdl -s $P/memory/__MEM_DIR__/__METAL_STACK__/MEM_SP_64x32/MEM_SP_64x32.cdl"
$R "v2lvs -v outputs/pnr/aegis_chip.lvs.v -o work/calibre/lvs/aegis_chip.cdl $CDLS -s0 VSS -s1 VDD >& logs/v2lvs.log"

step LVS
sed -e "s#LAYOUT_GDS#$GDS#" -e "s#SOURCE_CDL#$W/lvs/aegis_chip.cdl#" $FLOW/scripts/calibre/lvs.svrf > $W/lvs/lvs.svrf
$R "cd work/calibre/lvs; calibre -lvs -hier -spice aegis_chip.sp -turbo 16 lvs.svrf >& lvs.log"
cp $W/lvs/lvs.report $FLOW/reports/calibre/lvs.report

step summary
grep -E "^RULECHECK .* TOTAL Result Count = [1-9]" $W/drc/drc.summary | sort -t= -k2 -rn | head -40 || true
grep -E "^RULECHECK .* TOTAL Result Count = [1-9]" $W/ant/ant.summary | head || true
grep -A3 "OVERALL COMPARISON RESULTS" $W/lvs/lvs.report | head -8 || true
echo CALIBRE_SIGNOFF_DONE
