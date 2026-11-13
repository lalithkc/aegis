#!/usr/bin/env python3
"""Write a calibredrv Tcl script that builds SRAM placeholder cells from LEF.

Per pin: every LEF pin shape (drawing dt0) + pin-name text (texttype 7 on the
pin layer).  Where one pin has shapes on several metal layers at the same
spot (connected inside the real memory), a via stack joins them so LVS sees
one port.  Boundary on layer 235.  No OBS geometry: __FOUNDRY__ replaces these
cells with the real memory layout at tape-out.
usage: lef2gds_sram.py out.tcl a.lef [b.lef ...]
"""
import re
import sys

LMAP = {"M1": 40, "M2": 42, "M3": 44, "TOP_M": 50, "V2": 41, "V3": 43, "TOP_V": 49}
STACK = [40, 42, 44, 50]
VIA = {40: 41, 42: 43, 44: 49}          # via above each metal

out = open(sys.argv[1], "w")
out.write("set L [layout create]\n"
          "foreach l {40 41 42 43 44 49 50 40.7 42.7 44.7 50.7 235} {$L create layer $l}\n")


def poly(cell, layer, x1, y1, x2, y2):
    out.write("$L create polygon %s %d %d %d %d %d\n" % (cell, layer, x1, y1, x2, y2))


for lef in sys.argv[2:]:
    s = open(lef).read()
    m = re.search(r"MACRO\s+(\S+)(.*?)END\s+\1", s, re.S)
    name, body = m.group(1), m.group(2)
    W, H = map(float, re.search(r"SIZE\s+([\d.]+)\s+BY\s+([\d.]+)", body).groups())
    out.write("$L create cell %s\n" % name)
    poly(name, 235, 0, 0, round(W * 1000), round(H * 1000))
    for pm in re.finditer(r"PIN\s+(\S+)(.*?)END\s+\1", body, re.S):
        pin, pb = pm.group(1), pm.group(2)
        shapes = {}
        for lm in re.finditer(r"LAYER\s+(\S+)\s*;((?:\s*RECT[^;]*;)+)", pb):
            lay = lm.group(1)
            if lay not in LMAP:
                continue
            for r in re.findall(r"RECT\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)", lm.group(2)):
                x1, y1, x2, y2 = [round(float(v) * 1000) for v in r]
                x1, x2 = min(x1, x2), max(x1, x2)
                y1, y2 = min(y1, y2), max(y1, y2)
                poly(name, LMAP[lay], x1, y1, x2, y2)
                if LMAP[lay] in STACK:
                    out.write("$L create text %s %d.7 %d %d {%s}\n"
                              % (name, LMAP[lay], (x1 + x2) // 2, (y1 + y2) // 2, pin))
                    shapes.setdefault(LMAP[lay], []).append((x1, y1, x2, y2))
        used = [l for l in STACK if l in shapes]
        if len(used) < 2:
            continue
        lo, hi = STACK.index(used[0]), STACK.index(used[-1])
        # join each lowest-layer shape to an overlapping highest-layer shape
        for a in shapes[used[0]]:
            for b in shapes[used[-1]]:
                ux1, uy1 = min(a[0], b[0]), min(a[1], b[1])
                ux2, uy2 = max(a[2], b[2]), max(a[3], b[3])
                ox = min(a[2], b[2]) - max(a[0], b[0])
                oy = min(a[3], b[3]) - max(a[1], b[1])
                # overlapping, or tiny shapes within ~1 um of each other
                if (ox >= 0 and oy >= 0) or (ux2 - ux1 <= 1200 and uy2 - uy1 <= 1200):
                    if ox >= 0 and oy >= 0:
                        # overlapping shapes: 0.6 um stack centred on the overlap.
                        # (A box spanning both shapes reached other pins, e.g. a
                        # 21 um M1 bar shorted MEM_SP_64x32 A[2]-CE and A[3]-CSB.)
                        cx = (max(a[0], b[0]) + min(a[2], b[2])) // 2
                        cy = (max(a[1], b[1]) + min(a[3], b[3])) // 2
                        hx = hy = 300
                    else:
                        # tiny shapes within ~1 um of each other: cover both
                        cx, cy = (ux1 + ux2) // 2, (uy1 + uy2) // 2
                        hx = max(300, (ux2 - ux1) // 2 + 100)
                        hy = max(300, (uy2 - uy1) // 2 + 100)
                    for l in STACK[lo:hi + 1]:
                        poly(name, l, cx - hx, cy - hy, cx + hx, cy + hy)
                    for l in STACK[lo:hi]:
                        poly(name, VIA[l], cx - 130, cy - 130, cx + 130, cy + 130)
                    break

out.write("$L gdsout lib/sram_gds_lef/MEM_SP_placeholders.gds\nputs SRAM_GDS_DONE\n")
