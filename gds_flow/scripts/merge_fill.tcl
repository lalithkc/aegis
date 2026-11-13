# Merge Calibre dummy fill into the assembled chip (__FOUNDRY__ chip-finishing step 4/5:
# fill top cell placed at the origin of the original top cell).
set FLOW $PROJ_ROOT
set F $FLOW/outputs/final
set L [layout create $F/aegis_chip_nofill.gds -dt_expand -preservePaths -preserveTextAttributes]
set D [layout create $FLOW/work/calibre/fill/aegis_chip_fill.gds -dt_expand]
set ftop [$D topcell]
puts "fill top cell: $ftop  layers: [lsort -dictionary [$D layers]]"
$L import layout $D FALSE rename
set newtop [lindex [lsearch -all -inline [$L cells] ${ftop}*] 0]
$L create ref aegis_chip $newtop 0 0 0 0 1
$L gdsout $F/aegis_chip.gds aegis_chip
puts "MERGE_DONE"
