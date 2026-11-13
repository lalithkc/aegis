# ---------------------------------------------------------------------------
# Final chip assembly (Calibre DESIGNrev, calibredrv)
#   in : outputs/pnr/aegis_chip_pnr.gds (top aegis_chip_pr), outputs/pnr/pads.txt
#   out: outputs/final/aegis_chip_nofill.gds (top aegis_chip)
#
#   * __FOUNDRY__ __METAL_STACK__ seal ring (__SEAL_RING_CELL__) regenerated at the chip
#     size: every layer keeps __FOUNDRY__'s exact ring widths and offsets.
#   * die edge -> seal ring 10 um (DRM 10.3.2: >= 10 um),
#     seal ring inner edge -> pad ring 14 um (SR.D.1: >= 10 um).
#   * seal-ring metals strapped to the bond pad of one VSS pad per side
#     (DRM 10.3.1: connect seal ring metals to the Vss bus).
#   * port-name text on every bond pad (texttype 7 on TOP_M) for chip LVS.
#   * revision block / silicon number intentionally NOT added.
# ---------------------------------------------------------------------------
set FLOW $PROJ_ROOT
set PDK  $PDK_ROOT
set S    35.0     ;# P&R die origin offset inside the final die (um)
set SEAL_GAP 10.0 ;# die edge -> seal ring outer edge (um)
file mkdir $FLOW/outputs/final

# ---------------- read P&R die and pads ----------------
set pads {}
set f [open $FLOW/outputs/pnr/pads.txt]
while {[gets $f line] >= 0} {
  if {[lindex $line 0] eq "DIE"} {
    set box [lindex $line 1]; if {[llength $box] == 1} { set box [lindex $box 0] }
    lassign $box dx1 dy1 DW DH
  } elseif {[lindex $line 0] eq "PAD"} {
    lassign $line - name cell bb orient net
    if {[llength $bb] == 1} { set bb [lindex $bb 0] }
    lappend pads [list $name $cell $bb $orient $net]
  }
}
close $f
set FW [expr {$DW + 2*$S}] ; set FH [expr {$DH + 2*$S}]
puts "P&R die ${DW} x ${DH} um -> final die ${FW} x ${FH} um"

proc dbu {v} { return [expr {int(round($v*1000.0))}] }

# ---------------- load layouts ----------------
set L [layout create $FLOW/outputs/pnr/aegis_chip_pnr.gds -dt_expand -preservePaths -preserveTextAttributes]
set SR [layout create $PDK/ext_str/SEALRING_PAD_PDK2020.gds -dt_expand]
set src __SEAL_RING_CELL__
lassign [$SR bbox $src] sx1 sy1 sx2 sy2

# ---------------- seal ring cell at chip size ----------------
set ox1 [dbu $SEAL_GAP] ; set oy1 [dbu $SEAL_GAP]
set ox2 [dbu [expr {$FW-$SEAL_GAP}]] ; set oy2 [dbu [expr {$FH-$SEAL_GAP}]]
$L create cell SEALRING___METAL_STACK___AEGIS
foreach ly [$SR layers -cell $src] {
  if {[catch {set polys [$SR iterator poly $src $ly range 0 100000]}]} continue
  if {![llength [split $ly .]] } continue
  set lyr [lindex [split $ly .] 0]; set dt [expr {[llength [split $ly .]]>1 ? [lindex [split $ly .] 1] : 0}]
  if {[lsearch [$L layers] $ly] < 0} { $L create layer $ly }
  foreach p $polys {
    set xs {}; set ys {}; foreach {x y} $p { lappend xs $x; lappend ys $y }
    set xs [lsort -integer -unique $xs]; set ys [lsort -integer -unique $ys]
    # ring polygon: outer box (min/max) and inner box (2nd/3rd values)
    if {[llength $xs] < 4 || [llength $ys] < 4} { puts "skip non-ring poly on $ly"; continue }
    set dl [expr {[lindex $xs 0]-$sx1}] ; set dli [expr {[lindex $xs 1]-$sx1}]
    set dr [expr {$sx2-[lindex $xs end]}] ; set dri [expr {$sx2-[lindex $xs end-1]}]
    set db [expr {[lindex $ys 0]-$sy1}] ; set dbi [expr {[lindex $ys 1]-$sy1}]
    set dt_ [expr {$sy2-[lindex $ys end]}] ; set dti [expr {$sy2-[lindex $ys end-1]}]
    set a1 [expr {$ox1+$dl}]  ; set b1 [expr {$oy1+$db}]
    set a2 [expr {$ox2-$dr}]  ; set b2 [expr {$oy2-$dt_}]
    set i1 [expr {$ox1+$dli}] ; set j1 [expr {$oy1+$dbi}]
    set i2 [expr {$ox2-$dri}] ; set j2 [expr {$oy2-$dti}]
    $L create polygon SEALRING___METAL_STACK___AEGIS $ly \
      $a1 $b1  $a1 $b2  $i2 $b2  $i2 $j2  $i1 $j2  $i1 $j1  $i2 $j1  $i2 $b2  $a2 $b2  $a2 $b1
  }
}
# __FOUNDRY__ metal-option label carried by the sample seal ring (if any)
catch {
  foreach ly [$SR layers -cell __SEAL_RING_PADS_CELL__] {
    foreach t [$SR iterator text $src $ly range 0 100] { puts "seal text: $t" }
  }
}

# ---------------- new top ----------------
$L create cell aegis_chip
$L create ref aegis_chip aegis_chip_pr [dbu $S] [dbu $S] 0 0 1
$L create ref aegis_chip SEALRING___METAL_STACK___AEGIS 0 0 0 0 1
foreach ly {40 42 44 50 235} { if {[lsearch [$L layers] $ly] < 0} { $L create layer $ly } }
foreach ly {50.7} { if {[lsearch [$L layers] $ly] < 0} { $L create layer $ly } }
# chip boundary marker
$L create polygon aegis_chip 235 0 0 [dbu $FW] [dbu $FH]

# ---------------- per-pad: side, bond-pad centre ----------------
proc pad_side {bb DW DH} {
  lassign $bb x1 y1 x2 y2
  set d [list [list S $y1] [list N [expr {$DH-$y2}]] [list W $x1] [list E [expr {$DW-$x2}]]]
  return [lindex [lsort -real -index 1 $d] 0 0]
}
set metal_inner [expr {$SEAL_GAP + 10.0}]   ;# seal-ring metal inner edge from die edge
set strapped {}
foreach p $pads {
  lassign $p name cell bb orient net
  lassign $bb x1 y1 x2 y2
  set side [pad_side $bb $DW $DH]
  # bond pad = outer 61 um of the pad cell (metal 2..63 um across)
  switch $side {
    S { set cx [expr {($x1+$x2)/2+$S}]; set cy [expr {$y1+$S+30.5}] }
    N { set cx [expr {($x1+$x2)/2+$S}]; set cy [expr {$y2+$S-30.5}] }
    W { set cx [expr {$x1+$S+30.5}];    set cy [expr {($y1+$y2)/2+$S}] }
    E { set cx [expr {$x2+$S-30.5}];    set cy [expr {($y1+$y2)/2+$S}] }
  }
  if {[string match IO_CORNER_CELL $cell] || $net eq ""} continue
  $L create text aegis_chip 50.7 [dbu $cx] [dbu $cy] $net
  # VSS strap: first pv0i of each side
  if {$cell eq "pv0i" && [lsearch $strapped $side] < 0} {
    lappend strapped $side
    set hw 10.0
    switch $side {
      S { set r [list [expr {$cx-$hw}] [expr {$metal_inner-1}] [expr {$cx+$hw}] [expr {$y1+$S+1}]] }
      N { set r [list [expr {$cx-$hw}] [expr {$y2+$S-1}] [expr {$cx+$hw}] [expr {$FH-$metal_inner+1}]] }
      W { set r [list [expr {$metal_inner-1}] [expr {$cy-$hw}] [expr {$x1+$S+1}] [expr {$cy+$hw}]] }
      E { set r [list [expr {$x2+$S-1}] [expr {$cy-$hw}] [expr {$FW-$metal_inner+1}] [expr {$cy+$hw}]] }
    }
    foreach ly {40 42 44 50} {
      $L create polygon aegis_chip $ly [dbu [lindex $r 0]] [dbu [lindex $r 1]] [dbu [lindex $r 2]] [dbu [lindex $r 3]]
    }
    puts "VSS strap side $side via $name"
  }
}

$L gdsout $FLOW/outputs/final/aegis_chip_nofill.gds aegis_chip
puts "ASSEMBLY_DONE die ${FW} x ${FH}"
