# ---------------------------------------------------------------------------
# aegis_chip -- SCAN CAPTURE mode (test_mode = 1, scan_enable = 0)
# Tester drives clk and spi_sck from one 50 MHz test clock. rst and spi_cs_n
# (asynchronous resets) are held inactive (0) by the tester during scan.
# ---------------------------------------------------------------------------
set_units -time ns -capacitance pF

create_clock -name clk     -period 20.0 -waveform {0 10} [get_ports clk]
create_clock -name spi_sck -period 20.0 -waveform {0 10} [get_ports spi_sck]
# Capture: functional CDC paths between the domains are not tested at speed.
set_clock_groups -asynchronous -name async_clk_spi \
    -group [get_clocks clk] -group [get_clocks spi_sck]

set_clock_uncertainty -setup 0.30 [all_clocks]
set_clock_uncertainty -hold  0.10 [all_clocks]
set_clock_transition 0.20 [all_clocks]
set_clock_latency -source 0.50 [all_clocks]

set_case_analysis 1 [get_ports test_mode]
set_case_analysis 0 [get_ports scan_enable]
set_case_analysis 0 [get_ports rst]
set_case_analysis 0 [get_ports spi_cs_n]

set_input_transition 1.0 [remove_from_collection [all_inputs] [get_ports {clk spi_sck}]]
set_input_transition 0.5 [get_ports {clk spi_sck}]
set_load 10.0 [all_outputs]

set_input_delay  -clock clk -max 5.0 [get_ports {scan_in[*] spi_mosi}]
set_input_delay  -clock clk -min 0.5 [get_ports {scan_in[*] spi_mosi}]
set_output_delay -clock clk -max 5.0 [get_ports {scan_out[*] spi_miso}]
set_output_delay -clock clk -min 0.0 [get_ports {scan_out[*] spi_miso}]

set_max_transition 1.5 [current_design]
set_max_fanout 32 [current_design]
