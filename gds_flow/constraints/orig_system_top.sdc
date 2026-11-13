# Initial functional clock constraint; validate port and timing intent before signoff.
create_clock -name clk -period 10.000 [get_ports clk]
set_clock_uncertainty 0.150 [get_clocks clk]
set_clock_transition 0.100 [get_clocks clk]
# SPI is a separate source-synchronous serial input domain and is synchronized
# into clk via a toggle handshake. Constrain/declare asynchronous groups only
# after reviewing the exact supported SDC syntax and SPI timing requirements.
