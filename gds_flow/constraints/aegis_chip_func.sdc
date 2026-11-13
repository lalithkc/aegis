# ---------------------------------------------------------------------------
# aegis_chip -- FUNCTIONAL mode constraints (test_mode = 0, scan_enable = 0)
# Ports are chip pads; all I/O timing is referenced at the PAD pins.
# ---------------------------------------------------------------------------
set_units -time ns -capacitance pF

# --- clocks ----------------------------------------------------------------
# System clock: 100 MHz
create_clock -name clk     -period 10.0 -waveform {0 5}  [get_ports clk]
# SPI serial clock: up to 50 MHz, asynchronous to clk (toggle handshake CDC)
create_clock -name spi_sck -period 20.0 -waveform {0 10} [get_ports spi_sck]

set_clock_groups -asynchronous -name async_clk_spi \
    -group [get_clocks clk] -group [get_clocks spi_sck]

set_clock_uncertainty -setup 0.30 [all_clocks]
set_clock_uncertainty -hold  0.10 [all_clocks]
set_clock_transition 0.20 [all_clocks]
set_clock_latency -source 0.50 [all_clocks]

# --- mode ------------------------------------------------------------------
set_case_analysis 0 [get_ports test_mode]
set_case_analysis 0 [get_ports scan_enable]

# --- external environment -------------------------------------------------
set_input_transition 1.0 [remove_from_collection [all_inputs] [get_ports {clk spi_sck}]]
set_input_transition 0.5 [get_ports {clk spi_sck}]
set_load 10.0 [all_outputs]

# --- I/O delays ------------------------------------------------------------
# SPI mode 0: MOSI/CS_N launched by the host on the falling SCK edge.
set_input_delay  -clock spi_sck -clock_fall -max 4.0 [get_ports {spi_mosi spi_cs_n}]
set_input_delay  -clock spi_sck -clock_fall -min 0.5 [get_ports {spi_mosi spi_cs_n}]
# MISO is a ready/busy level sampled by the host on the next rising SCK.
set_output_delay -clock spi_sck -max 4.0 [get_ports spi_miso]
set_output_delay -clock spi_sck -min 0.0 [get_ports spi_miso]

# rst is asynchronous; it is synchronised on-chip (async assert, sync release).
set_false_path -from [get_ports rst]
# Scan pins carry no functional data in this mode.
set_false_path -from [get_ports {scan_in[*]}]
set_false_path -to   [get_ports {scan_out[*]}]

# --- design rules ------------------------------------------------------------
set_max_transition 1.5 [current_design]
set_max_fanout 32 [current_design]
