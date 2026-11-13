# ---------------------------------------------------------------------------
# Design-intent exception (rtl/main_memory.v section 7 "READ RESPONSE PIPELINE"):
# the data SRAM is accessed on the falling clock edge N (CE = ~clk) and its
# output O is sampled into mem_rdata_r on rising edge N+2, i.e. 1.5 periods
# later (read_pending -> read_pending_d pipeline).  Default STA would check
# falling N -> rising N+1 (half a period).  Setup 2 / hold 1 = 1.5-cycle path
# with the hold check left at the original edge.
# ---------------------------------------------------------------------------
set_multicycle_path -setup 2 -from [get_cells u_core/u_main_mem_sram_inst] -to [get_cells u_core/u_main_mem_mem_rdata_r_reg*]
set_multicycle_path -hold  1 -from [get_cells u_core/u_main_mem_sram_inst] -to [get_cells u_core/u_main_mem_mem_rdata_r_reg*]
