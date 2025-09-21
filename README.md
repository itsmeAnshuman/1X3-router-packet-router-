# 1X3Router RTL Design and Verification

## Project Overview
This project involves the complete design and verification of a 1x3 packet router implemented in SystemVerilog. The router serves as a network switching device that receives packets on a single input port and routes them to one of three output ports based on destination address.

<img width="679" height="274" alt="Screenshot 2025-09-19 232619" src="https://github.com/user-attachments/assets/12f885fe-e814-4565-93f1-e50777677147" />

## block diagram.
<img width="951" height="572" alt="Screenshot 2025-09-21 114012" src="https://github.com/user-attachments/assets/4e3be74f-93ee-43ee-a817-6acb9e1480e8" />

## sate diagram for FSM
<img width="1099" height="679" alt="Screenshot 2025-09-21 004948" src="https://github.com/user-attachments/assets/10f3da86-e1eb-4d8b-94b0-878d88b12562" />


## Design Architecture
The router features a modular architecture with four main components: an FSM controller for state management, a register block for data processing and parity calculation, a synchronizer for address decoding and timing control, and three independent FIFO buffers (one per output port). Each FIFO has a depth of 16 entries and includes timeout mechanisms that trigger soft reset after 30 clock cycles of inactivity.

<img width="994" height="717" alt="Screenshot 2025-09-19 235022" src="https://github.com/user-attachments/assets/9c56872c-0d90-4005-baae-55932d7f8656" />

## Key Features
- Packet-based switching with 2-bit destination addressing (supports addresses 00, 01, 10)
- Variable payload length support (1 to 63 bytes per packet)
- Built-in parity checking for error detection
- Busy signal generation during packet processing
- Automatic timeout and soft reset functionality
- Tri-state output capability when FIFOs are empty or after timeout

  <img width="372" height="320" alt="Screenshot 2025-09-20 234404" src="https://github.com/user-attachments/assets/232a4b27-89d0-4747-a485-7598adda9bfd" />


## Verification Strategy
The verification environment includes 9 comprehensive test cases that validate all functional aspects including basic packet transmission, parity error handling, back-to-back packet scenarios, maximum/minimum payload lengths, FIFO timeout behavior, busy signal operation, and invalid address handling. The testbench uses advanced SystemVerilog features like dynamic arrays, scoreboards, and automatic result comparison to ensure thorough coverage.

##output log.
<img width="620" height="663" alt="Screenshot 2025-09-21 112748" src="https://github.com/user-attachments/assets/7589b52e-1a0b-4a69-a3ac-6d36ae939943" />

<img width="1829" height="433" alt="Screenshot 2025-09-21 112847" src="https://github.com/user-attachments/assets/cda3acbd-c30c-42ae-9c0b-f96893e4cf18" />

## Technical Skills Demonstrated
- Digital design principles
- SystemVerilog coding and advanced constructs
- Verification methodologies and testbench development
- Network routing protocol understanding
- FSM design and implementation
