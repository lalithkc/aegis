# aegis.v2 RTL → GDSII — session notes (2026-11-05/06)

Flow root: `$PROJ_ROOT` (original `aegis.v2/` files untouched).
Run any tool inside the Cadence/Mentor env with `./run.sh "<cmd>"`.

## Status

| Step | Result |
|---|---|
| RTL lint (HAL) | no latches/loops/multi-drivers; CDC via toggle handshake (intended) |
| RTL sim | imem, system_top, chip-level boot + program test (core0 x3=3, core1 x6=9) PASS |
| Synthesis (Genus, SS/FF, 3 modes) | met @100 MHz; 45,462 cells; 343 ICGs (98% flops gated); 131 mW |
| DFT | 4 chains × ~4,042 flops, 0 DFT violations; Modus ATPG 99.20% TCov (99.60% adj.) |
| LEC (Conformal) | RTL ≡ synth netlist PASS; synth ≡ routed netlist PASS (16,512 pts, pre-ECO) |
| Floorplan | 40 pads (16 signal + 16 core PG + 8 IO PG), 4 corners (IO_CORNER_CELL, orient fixed), pfeed fillers |
| P&R | core 2868×2873 µm, die 3508×3513 µm (3578×3583 µm with seal ring) |
| Final timing (Innovus signoff RC) | setup +0.005 ns, hold +0.072 ns, 0 violations, no DRV |
| Innovus checks | connectivity clean; 9 DRC = pad-ring wire vs IO-filler abstract (Calibre-clean); 2 antenna |
| Post-syn GLS / SDF GLS (SS, FF) | PASS (pre-ECO netlist) |
| Calibre DRC (last run, pre-ECO) | 23 min-area at SRAM pin boundaries (placeholder artefact) |
| Calibre LVS (last run) | 285k nets matched; remaining = SRAM placeholder pin labelling (fixed, not re-run) |
| Voltus IR | not possible: __STDCELL_FAMILY__ Liberty has no pg_pin; hand estimate < 20 mV (~1.2%) |

## Still to run (needs licences — server internet was down)
`scripts/finish_signoff.sh` (started with `START=2`, waits for a real licence checkout):
2. Innovus signoff export (`inn_05_signoff_export.tcl`) → SPEF/SDF/netlists/GDS
3. `run_calibre_signoff.sh` → seal ring + VSS straps + labels, dummy fill, DRC, antenna, LVS
4. Tempus (`tempus_signoff.tcl`), 5. LEC syn↔routed, 6. SDF GLS SS/FF.
Log: `logs/finish_signoff.log` (ends with `FINISH_SIGNOFF_DONE`).
Final GDS: `outputs/final/aegis_chip.gds` (top `aegis_chip`).

## Key decisions / changes
- Added chip top `rtl/aegis_chip.v` (pads, reset synchroniser) and a `test_mode` pad;
  `system_top` gets `test_mode` gating of `core_rst`, scan pins moved to chip top.
- SDC exception `constraints/mcp_main_memory.sdc`: SRAM read is a 1.5-cycle path by design
  (main_memory.v §7). Appended to `outputs/syn/*func*.sdc`, `*scan_capture*.sdc`.
- Last setup path fixed by useful skew (`inn_04h_skew.tcl`: STD_BUF_1 on capture-flop clock);
  an upsizing ECO broke timing (−5.3 ns) and was reverted (`dbs/04_route_bad_upsize*`).
- Antenna: 3,367 `STD_ANTENNA_DIODE` cells attached on 330 nets from Calibre antenna boxes.
- Revision block / silicon number not added (as requested).

## Kit gaps & workarounds
- No SRAM layout in __FOUNDRY__ kit (Milkyway = abstracts). GDS carries `MEM_SP_*` placeholders built
  from LEF (`scripts/lef2gds_sram.py`); __FOUNDRY__ must merge real memory GDS by cell name.
- No QRC file: built `lib/qrc/qrcTechFile` from __FOUNDRY__ Calibre `.mipt` via hand-written ICT + Techgen.
- SRAM LEF OBS off-grid → snapped copies in `lib/lef/`.
- Seal ring regenerated at die size from `__SEAL_RING_CELL__` (DRC-clean), strapped to VSS pads.
- LVS: `LVS FILTER D(dwn2psub) OPEN LAYOUT` (diode in __FOUNDRY__ pad GDS, absent from pad CDL); `v2lvs` without `-i`.
- Raw TCP probes to licence servers are unreliable; test licences with a real Innovus checkout.

## DB backups (outputs/pnr/dbs)
`04_route` (final, skew ECO) · `04_route_closure3` · `04_route_closure2` · `04_route_holdeco`
· `04_route_pre_holdeco` · `04_route_closed` · `04_route_pre_closure` · `04_route_bad_upsize` (do not use)

## Round 1 results (finish_signoff.sh, done 2026-11-06 11:26)
Export, Tempus, LEC syn↔routed, SDF GLS SS/FF (boot + program test PASS) all completed.
Calibre: LVS INCORRECT, DRC 23 (M1.A.1 9, M3.A.1 14), antenna 266 (AN.MTL.1.M3 63, .MT 203).

## Round 2 analysis (2026-11-07)
- **LVS (real bug, fixed):** `lef2gds_sram.py` built the M1–M3 joining stack as the *union* of two
  overlapping pin shapes → 21 µm bars. In MEM_SP_64x32 this shorted A[2]–CE and A[3]–CSB
  (CSB=VSS, CE=clock), which put address nets on VSS/clock; every other LVS discrepancy
  (core cells, 5 × IO_PAD_CELL pads, "ambiguity resolved arbitrarily") is knock-on from that.
  __FOUNDRY__'s own extracted IO_PAD_CELL netlist matches its CDL. Fix: 0.6 µm stack centred on the overlap
  (checked with `work/chk_ph.py`: 0 inter-pin shorts in all 3 macros). Originals kept as `*.orig`.
- **DRC 23 min-area (artefact):** drc.svrf has `EXCLUDE CELL MEM_SP_*`, so router landing patches
  on SRAM pins (all at the macros' pin edge, mapped with `work/drcmap.py`) look isolated. Proof
  run: `scripts/calibre/drc_srampins.svrf` (area rules, SRAM pins kept).
- **Antenna 266 (artefact/waiver):** all on 63 nets, every one driven by an SRAM `O[n]` pin
  (`scripts/box2net.py` → `reports/calibre/antenna_nets.txt`). SRAM LEF gives ANTENNADIFFAREA
  1.96 µm² on M1–M3 for O pins (driver diffusion); Innovus verifyProcessAntenna clean on them.
  The check excludes SRAM cells so the driver diode is invisible.
- Netlist/placement unchanged → round-1 Tempus/LEC/GLS remain valid.

Resume: `scripts/finish_signoff2.sh` (log `logs/finish_signoff2.log`, ends `FINISH_SIGNOFF2_DONE`):
placeholder GDS → Innovus re-stream → run_calibre_signoff.sh → pin-kept area DRC → antenna net map.

## Round 2 results (finish_signoff2.sh on __SERVER_HOST__ .70, done 2026-11-07 20:25)
__SERVER_HOST__ (.68) and __SERVER_HOST__ (.69) cannot reach __LICENSE_SERVER__ licence ports 1717/5280 (campus firewall);
__SERVER_HOST__ (.70) can, and shares $STORAGE_ROOT, so round 2 ran there. Campus server __LICENSE_SERVER_IP__:1717
serves neither Innovus nor Calibre.

| Check | Result |
|---|---|
| LVS (Calibre) | **CORRECT** — all nets/devices match. One report-level note: MEM_SP_64x32 box has 24 unnamed layout pins (split VDD/VSS islands of the placeholder; Calibre ignores them in comparison). Disappears with the real __FOUNDRY__ macro. |
| DRC full deck (SRAM excluded) | 23 min-area (M1.A.1 9, M3.A.1 14), all router landing patches on SRAM pins |
| DRC area, SRAM pins kept (`reports/calibre/drc_srampins.summary`) | 7 left (M1 3, M3 4): pins OEB/WEB/A[5,7,8,9] are 0.28×0.28 µm LEF stubs; LEF side-area shows long internal wires → met with real memory GDS. Waiver. |
| Antenna (`reports/calibre/antenna_nets.txt`) | 266 boxes on 63 nets, **all** SRAM `O[n]` outputs (LEF ANTENNADIFFAREA 1.96 µm²). Waiver. |
| Timing / LEC / SDF GLS | unchanged from round 1 (netlist & placement untouched) — PASS |

Final GDS: `outputs/final/aegis_chip.gds` (top `aegis_chip`, MEM_SP_* placeholders to be replaced by __FOUNDRY__).
Remaining waivers all depend on __FOUNDRY__ merging the real SRAM layout; ask __FOUNDRY__ to re-run DRC/antenna after merge.
