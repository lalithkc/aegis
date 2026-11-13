#!/bin/bash
# retry Calibre LVS until a licence is available (shared licence server)
cd $PROJ_ROOT
for i in $(seq 1 60); do
  ./run.sh "cd work/calibre/lvs; calibre -lvs -hier -spice aegis_chip.sp -turbo 16 lvs.svrf >& lvs.log"
  grep -q "could not be licensed" work/calibre/lvs/lvs.log || { echo "LVS ran (attempt $i)"; exit 0; }
  sleep 60
done
echo "LVS licence unavailable"
