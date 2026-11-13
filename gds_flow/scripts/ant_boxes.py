#!/usr/bin/env python3
"""Calibre antenna results -> violation boxes in P&R (Innovus) coordinates."""
import re, sys
src, dst, off = sys.argv[1], sys.argv[2], float(sys.argv[3])
L = open(src).read().split("\n")
lay = {"AN.MTL.1.M1": "M1", "AN.MTL.1.M2": "M2", "AN.MTL.1.M3": "M3", "AN.MTL.1.MT": "TOP_M"}
cur, i, pts = None, 0, []
while i < len(L):
    l = L[i]
    if re.match(r"^[A-Za-z0-9_.]+$", l) and i + 1 < len(L) and re.match(r"^\d+ \d+ \d+ ", L[i + 1]):
        cur = l; i += 2 + int(L[i + 1].split()[2]); continue
    m = re.match(r"^p \d+ (\d+)", l)
    if m and cur in lay:
        n = int(m.group(1)); xs, ys = [], []
        for k in range(1, n + 1):
            t = L[i + k].split()
            if len(t) >= 2 and t[0].lstrip("-").isdigit():
                xs.append(int(t[0])); ys.append(int(t[1]))
        if xs:
            pts.append("%s %.3f %.3f %.3f %.3f" % (lay[cur], min(xs) / 1e3 - off, min(ys) / 1e3 - off,
                                                   max(xs) / 1e3 - off, max(ys) / 1e3 - off))
        i += n + 1; continue
    i += 1
open(dst, "w").write("\n".join(pts) + "\n")
print(len(pts), "antenna boxes")
