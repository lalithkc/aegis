#!/usr/bin/env python3
"""Snap off-grid LEF geometry to the manufacturing grid.

OBS rectangles are snapped OUTWARD (blockage only grows: conservative).
PIN rectangles are snapped INWARD (pin access stays inside real metal).
Usage: snap_lef.py in.lef out.lef [grid_um]
"""
import math, re, sys

src, dst = sys.argv[1], sys.argv[2]
grid = float(sys.argv[3]) if len(sys.argv) > 3 else 0.005
SC = round(1 / grid)

def on_grid(v):
    return abs(v * SC - round(v * SC)) < 1e-6

def dn(v): return math.floor(v * SC + 1e-6) / SC
def up(v): return math.ceil(v * SC - 1e-6) / SC

rect_re = re.compile(r"^(\s*RECT\s+)([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)(\s*;.*)$")
out, ctx = [], None
stats = {"obs": 0, "pin": 0, "pin_dropped": 0}
for line in open(src):
    s = line.strip()
    if s.startswith("PIN "):
        ctx = "pin"
    elif s.startswith("OBS"):
        ctx = "obs"
    elif s.startswith("END") and ctx == "obs" and s == "END":
        ctx = None
    m = rect_re.match(line)
    if m and ctx in ("pin", "obs"):
        x1, y1, x2, y2 = map(float, m.group(2, 3, 4, 5))
        if not all(on_grid(v) for v in (x1, y1, x2, y2)):
            lx, hx = min(x1, x2), max(x1, x2)
            ly, hy = min(y1, y2), max(y1, y2)
            if ctx == "obs":
                lx, ly, hx, hy = dn(lx), dn(ly), up(hx), up(hy)
                stats["obs"] += 1
            else:
                lx, ly, hx, hy = up(lx), up(ly), dn(hx), dn(hy)
                stats["pin"] += 1
                if hx <= lx or hy <= ly:
                    stats["pin_dropped"] += 1
                    continue
            line = "%s%.3f %.3f %.3f %.3f%s\n" % (m.group(1), lx, ly, hx, hy, m.group(6))
    out.append(line)
open(dst, "w").writelines(out)
print("%s: snapped %d OBS rects, %d PIN rects (%d degenerate dropped)" %
      (src.split("/")[-1], stats["obs"], stats["pin"], stats["pin_dropped"]))
