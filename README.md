# Aegis: Dual-Core RV32I SoC, RTL to Signed-off GDSII (180 nm)

Dual-core, 2-wide, 7-stage dual-issue RV32I SoC with MESI-lite coherence, a 64-entry BTB and a 4x4 INT8 systolic accelerator, taken from RTL through DFT, place and route and sign-off on a 180 nm foundry process.

## Architecture

```
 SPI boot ──► spi_bootloader ──► dualcore_imem (SRAM, READ→CAPTURE→RESP)
                                      │            │
                                   core0         core1     (7-stage, dual-issue)
                                      │  L1 write-through + snoop (MESI-lite)
                                      └──── bus_arbiter ───► main_memory (SPRAM)
                                                │
                                      AXI4-Lite ── 2x2 crossbar ── systolic_array_4x4
 aegis_chip: pad ring, reset synchroniser, test_mode pad, scan pins
```
TODO(you): replace with a proper diagram (draw.io/Mermaid) before publishing.

## Results

| Item | Result |
|---|---|
| Synthesis (Genus, SS/FF, 3 modes) | timing met @ 100 MHz, 45,462 cells, 131 mW |
| Clock gating | 343 ICGs, 98% of flops gated |
| DFT | 4 scan chains x ~4,042 flops, 0 DFT violations, Modus ATPG 99.20% test coverage |
| Equivalence (Conformal) | RTL ≡ synthesised netlist; synthesised ≡ routed netlist (16,512 compare points) |
| Final timing (Innovus, signoff RC) | setup +0.005 ns, hold +0.072 ns, 0 violations |
| Gate-level sim (SDF, SS and FF) | boot + program test pass (core0 x3=3, core1 x6=9) |
| Calibre LVS | CORRECT |
| Calibre DRC / antenna | only SRAM-placeholder artefacts (waived pending real SCL SRAM GDS) |
| Die | 3508 x 3513 µm, 40 pads |

## RTL bugs found and fixed
1. `dualcore_imem`: SRAM read captured on the same edge as the state change, so instruction outputs were X. Split into READ → CAPTURE → RESP.
2. `system_top`: boot deadlock. `dualcore_imem` was held in reset by `!boot_done`, but `boot_done` could only be set by a packet sent after loading. IMEM now uses the external reset.
3. TODO(you): `control_unit_1`: root cause, fix, Formality pass. I found no record of this in the server notes or logs, so I cannot write it from facts. Give me the story in 5 sentences and I will write it.

## Reproducing
```
xrun -64bit -sv -f scripts/sim_system_top.f -top tb_system_top   # boot + program test
```
Flow notes: `gds_flow/SESSION_NOTES.md`.

## Tools
Verilog · Cadence Genus, Innovus, Xcelium, Modus, Conformal, Tempus · Siemens Calibre · Synopsys Formality

## Repository layout
- `AUDIT_REPORT.md`: RTL audit findings and fixes.
- `gds_flow/rtl`, `gds_flow/tb`: design and testbenches (the chip top `aegis_chip.v` adds pads, reset synchroniser and test mode).
- `gds_flow/scripts`: Genus, Innovus, Tempus, Conformal and Calibre scripts, simulation filelists.
- `gds_flow/constraints`: SDC for functional, scan-shift and scan-capture modes.
- `gds_flow/SESSION_NOTES.md`: full flow log, decisions and waivers.

## Foundry data is placeholdered
This copy contains no foundry PDK data, cell names, paths or licence-server details. They are replaced by `__PLACEHOLDER__` tokens (for example `$PDK_ROOT`, `__STDCELL_LIB__`, `__IOPAD_LIB__`, `IO_PAD_CELL`, `MEM_SP_*` for the single-port SRAM macros). Set `PDK_ROOT`, `PROJ_ROOT` and `WORK_ROOT` and substitute your PDK's names to reproduce the flow.
