# 1X3-router-packet-router-
This project involves the complete design and verification of a 1x3 packet router implemented in SystemVerilog. The router serves as a network switching device that receives packets on a single input port and routes them to one of three output ports based on destination address.
Design Architecture:
The router features a modular architecture with four main components: an FSM controller for state management, a register block for data processing and parity calculation, a synchronizer for address decoding and timing control, and three independent FIFO buffers (one per output port). Each FIFO has a depth of 16 entries and includes timeout mechanisms that trigger soft reset after 30 clock cycles of inactivity.
