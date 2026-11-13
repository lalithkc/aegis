# Aegis RTL audit — findings and changes

Audit baseline: `logs.zip` supplied on 2026-10-28.

## Fixed in this package

1. **`rtl/dualcore_imem.v` — synchronous SRAM read/capture race**
   - The previous FSM captured SRAM output on the same edge that moved `READ` to `RESP`.
   - The SRAM read and response capture now use separate states: `READ -> CAPTURE -> RESP`.
   - `valid0/valid1` are asserted only after captured data is available.
   - A flush cancels requests in flight, and new requests are blocked while the corresponding flush is asserted.
   - Instruction SRAM writes remain available while the processor cores are held in reset.

2. **`rtl/system_top.v` — bootloader deadlock**
   - Previously, `dualcore_imem` used `core_rst = rst | !boot_done`.
   - `load_ready` is low while `dualcore_imem` is in reset, while `boot_done` could only be asserted by a packet sent after loading. This formed a boot deadlock.
   - `dualcore_imem` now uses external `rst`; the CPU, bus arbiter, and data memory still use `core_rst`. This allows the SPI bootloader to preload instruction SRAM before releasing the cores.

3. **`tb/tb_dualcore_imem.sv`**
   - Replaced internal SRAM/macro debug probing with public-interface checks.
   - Covers both cores, consecutive instruction words, response stability under backpressure, misaligned addresses, and out-of-range addresses.
   - This testbench is a proposed regression test; it has not been run in Xcelium in this environment.

4. **`rtl/tb_system_top.v` and `scripts/sim_system_top.f`**
   - The supplied system testbench instantiated ports that do not exist on the current `system_top`. It now uses the actual SPI/scan interface and sends bootloader packets to test instruction preload and boot release.
   - The new filelist includes behavioral SRAM models for system-level simulation and the unchanged PDK `MEM_SP_2048x36` model.

5. **Physical-design scripts**
   - `scripts/genus_elaborate.tcl`, `scripts/genus_synth.tcl`, `scripts/innovus_readiness.tcl`, and `scripts/mmmc.tcl` now use the uploaded project-root layout instead of a nonexistent `physical_design/` subdirectory.
   - The MMMC library set now includes the `MEM_SP_64x32` cache macro, and the Innovus LEF list includes that macro.

## Checks performed

- Inspected the uploaded RTL, testbench, simulation filelists, synthesis scripts, MMMC setup, SDC, and available simulation logs.
- Confirmed the updated `tb_system_top` named-port connections match the actual `system_top` interface.
- The supplied `imem_debug.log` reproduces the original failure: SRAM bank outputs resolve, while the public instruction outputs are X because the old FSM captured too early.
- The PDK SRAM model was not modified.

## Still requires tool-based verification

- No Xcelium, Genus, or Innovus executable is available in this environment, so no claim is made that simulation, elaboration, synthesis, or physical design passes.
- Run both regression filelists on the university server:
  - `xrun -64bit -sv -f scripts/sim_files.f -top tb_dualcore_imem -l logs/imem_regression.log`
  - `xrun -64bit -sv -f scripts/sim_system_top.f -top tb_system_top -l logs/system_boot_regression.log`
- `scripts/mmmc.tcl` is still only an initial MMMC template: it intentionally lacks a verified RC/delay corner. `scripts/innovus_readiness.tcl` is intentionally not a runnable signoff flow; I/O pad, power-grid, QRC, and physical-verification setup still need PDK-specific confirmation.
- `constraints/system_top.sdc` currently specifies a 10 ns clock. Confirm this target against the intended operating frequency before timing signoff.
- The full CPU/cache/bus/memory system still needs simulation and tool-based lint/elaboration. This package fixes confirmed issues; it is not a substitute for those checks.
