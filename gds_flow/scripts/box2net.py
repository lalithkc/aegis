"""Calibre antenna boxes (P&R coords) -> DEF nets, plus diode / sink info per net."""
import gzip, re, sys
from collections import defaultdict
defp, boxf = sys.argv[1], sys.argv[2]
boxes = [l.split() for l in open(boxf) if l.strip()]
boxes = [(b[0], tuple(float(v) for v in b[1:])) for b in boxes]
G = 20.0
grid = defaultdict(list)
for i, (ly, r) in enumerate(boxes):
    for gx in range(int(r[0] // G), int(r[2] // G) + 1):
        for gy in range(int(r[1] // G), int(r[3] // G) + 1):
            grid[(ly, gx, gy)].append(i)
hits = defaultdict(lambda: defaultdict(float))
conns = {}
net = None; U = 1000.0; insec = False
pt = re.compile(r'\(\s*(\S+)\s+(\S+)(?:\s+\S+)?\s*\)')
with gzip.open(defp, 'rt') as f:
    for line in f:
        if line.startswith('UNITS DISTANCE'): U = float(line.split()[3])
        if line.startswith('NETS '): insec = True; continue
        if line.startswith('END NETS'): break
        if not insec: continue
        s = line.strip()
        if s.startswith('- '):
            t = s.split(); net = t[1]; conns[net] = re.findall(r'\(\s*(\S+)\s+(\S+)\s*\)', s); continue
        if net and s.startswith('(') and not ('ROUTED' in s or 'NEW' in s):
            conns[net] += re.findall(r'\(\s*(\S+)\s+(\S+)\s*\)', s)
        m = re.search(r'(?:ROUTED|NEW)\s+(\S+)\s+(?:(\d+)\s+)?(.*)', s)
        if not (net and m): continue
        ly = m.group(1); w = (float(m.group(2)) / U) if m.group(2) else 0.28
        ps = pt.findall(m.group(3))
        if len(ps) < 2: continue
        x0, y0 = float(ps[0][0]) / U, float(ps[0][1]) / U
        x1 = x0 if ps[1][0] == '*' else float(ps[1][0]) / U
        y1 = y0 if ps[1][1] == '*' else float(ps[1][1]) / U
        h = w / 2
        r = (min(x0, x1) - h, min(y0, y1) - h, max(x0, x1) + h, max(y0, y1) + h)
        seen = set()
        for gx in range(int(r[0] // G), int(r[2] // G) + 1):
            for gy in range(int(r[1] // G), int(r[3] // G) + 1):
                for i in grid.get((ly, gx, gy), ()):
                    if i in seen: continue
                    seen.add(i); b = boxes[i][1]
                    ox = min(r[2], b[2]) - max(r[0], b[0]); oy = min(r[3], b[3]) - max(r[1], b[1])
                    if ox > 0 and oy > 0: hits[i][net] += ox * oy
res = defaultdict(list)
for i in range(len(boxes)):
    if hits[i]:
        n = max(hits[i].items(), key=lambda kv: kv[1])[0]; res[n].append(boxes[i][0])
    else: res['<unmatched>'].append(boxes[i][0])
print('boxes', len(boxes), 'nets', len(res))
for n, l in sorted(res.items(), key=lambda kv: -len(kv[1])):
    c = conns.get(n, [])
    dio = sum(1 for a, p in c if 'ANT' in a.upper() or 'DIODE' in a.upper() or p == 'I' and 'STD_ANTENNA_DIODE' in a)
    sram = [a + '/' + p for a, p in c if 'ram' in a.lower() or 'imem' in a.lower() or 'mem_sram' in a.lower()]
    print('%-55s boxes=%-3d %s pins=%d diodes?=%d sram=%s' % (n, len(l), ','.join(sorted(set(l))), len(c), dio, sram[:3]))
