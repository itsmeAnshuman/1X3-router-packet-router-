// Company: Personal Project / IIIT Ranchi
// Engineer: Anshuman verma
// 
// Create Date: 05.09.2025 09:46:04
// Design Name: 1x3_Packet_Router
// Module Name: router_top
// Project Name: 1X3Router_RTL_Design_and_Verification
// Target Devices: FPGA/ASIC (Generic)
// Tool Versions: Vivado
// Description: Comprehensive testbench for 1x3 packet router with 9 test cases
//              implementing scoreboard verification methodology
// Dependencies: router_top.sv
// 
// Revision:
// Revision 0.01 - Initial testbench with basic functionality
// Revision 0.02 - Added comprehensive test cases and scoreboard
// Additional Comments: Supports variable payload length, parity checking,
//                     and timeout mechanisms
// 1x3 Router Comprehensive Testbench
// Implements 9 test cases with scoreboard verification
// 1x3 Packet Router Top Module
// Routes input packets to one of three output ports based on 2-bit address
module router_top (
    input clock,
    input resetn,
    input packet_valid,
    input [7:0] data_in,
    input read_enb_0, read_enb_1, read_enb_2,
    
    output [7:0] data_out_0, data_out_1, data_out_2,
    output vld_out_0, vld_out_1, vld_out_2,
    output err,
    output busy
);

    // Internal interconnect signals
    wire [7:0] dout;
    wire [2:0] write_enb;
    wire [2:0] soft_reset;
    wire write_enb_reg;
    wire [2:0] read_enb;
    wire [2:0] empty;
    wire [2:0] full;
    wire lfd_state;
    wire detect_add;
    wire ld_state;
    wire laf_state;
    wire full_state;
    wire rst_int_reg;
    wire parity_done;
    wire low_packet_valid;
    
    assign read_enb = {read_enb_2, read_enb_1, read_enb_0};

    // FSM Controller - manages packet flow states
    router_fsm FSM (.clock(clock), .resetn(resetn), .packet_valid(packet_valid), .data_in(data_in), .parity_done(parity_done), .soft_reset_0(soft_reset[0]), .soft_reset_1(soft_reset[1]), .soft_reset_2(soft_reset[2]), .fifo_full(full_state), .low_packet_valid(low_packet_valid), .fifo_empty_0(empty[0]), .fifo_empty_1(empty[1]), .fifo_empty_2(empty[2]), .detect_add(detect_add), .ld_state(ld_state), .laf_state(laf_state), .lfd_state(lfd_state), .full_state(full_state), .write_enb_reg(write_enb_reg), .rst_int_reg(rst_int_reg), .busy(busy));

    // Register Block - handles data buffering and parity calculation
    router_register REG (.clock(clock), .resetn(resetn), .packet_valid(packet_valid), .data_in(data_in), .fifo_full(full_state), .detect_add(detect_add), .ld_state(ld_state), .laf_state(laf_state), .full_state(full_state), .lfd_state(lfd_state), .rst_int_reg(rst_int_reg), .err(err), .parity_done(parity_done), .low_packet_valid(low_packet_valid), .dout(dout));

    // Synchronizer - manages address decoding and timing control
    router_sync SYNC (.clock(clock), .resetn(resetn), .data_in(data_in), .detect_add(detect_add), .write_enb_reg(write_enb_reg), .read_enb_0(read_enb_0), .read_enb_1(read_enb_1), .read_enb_2(read_enb_2), .write_enb(write_enb), .fifo_full(full_state), .full_0(full[0]), .full_1(full[1]), .full_2(full[2]), .empty_0(empty[0]), .empty_1(empty[1]), .empty_2(empty[2]), .soft_reset_0(soft_reset[0]), .soft_reset_1(soft_reset[1]), .soft_reset_2(soft_reset[2]), .vld_out_0(vld_out_0), .vld_out_1(vld_out_1), .vld_out_2(vld_out_2));

    // Three 16-deep FIFO buffers for each output port
    router_fifo FIFO0 (.clock(clock), .resetn(resetn), .soft_reset(soft_reset[0]), .write_enb(write_enb[0]), .read_enb(read_enb[0]), .data_in({lfd_state, dout}), .lfd_state(lfd_state), .full(full[0]), .empty(empty[0]), .data_out(data_out_0));

    router_fifo FIFO1 (.clock(clock), .resetn(resetn), .soft_reset(soft_reset[1]), .write_enb(write_enb[1]), .read_enb(read_enb[1]), .data_in({lfd_state, dout}), .lfd_state(lfd_state), .full(full[1]), .empty(empty[1]), .data_out(data_out_1));

    router_fifo FIFO2 (.clock(clock), .resetn(resetn), .soft_reset(soft_reset[2]), .write_enb(write_enb[2]), .read_enb(read_enb[2]), .data_in({lfd_state, dout}), .lfd_state(lfd_state), .full(full[2]), .empty(empty[2]), .data_out(data_out_2));

    // Global FIFO full indication
    assign full_state = full[0] | full[1] | full[2];

endmodule

// Finite State Machine Controller
// Manages packet routing states and flow control
module router_fsm (
    input clock, resetn,
    input packet_valid,
    input [7:0] data_in,
    input fifo_full, fifo_empty_0, fifo_empty_1, fifo_empty_2,
    input soft_reset_0, soft_reset_1, soft_reset_2,
    input parity_done, low_packet_valid,
    
    output reg detect_add, ld_state, laf_state, lfd_state, full_state,
    output reg write_enb_reg, rst_int_reg, busy
);

    // FSM state encoding
    parameter DECODE_ADDRESS = 3'b000,
              LOAD_FIRST_DATA = 3'b001,
              LOAD_DATA = 3'b010,
              LOAD_PARITY = 3'b011,
              FIFO_FULL_STATE = 3'b100,
              LOAD_AFTER_FULL = 3'b101,
              DECODE_ADDRESS_WAIT = 3'b110,
              CHECK_PARITY_ERROR = 3'b111;

    reg [2:0] state, next_state;
    reg [1:0] addr;

    // State register with soft reset capability
    always @(posedge clock) begin
        if (~resetn)
            state <= DECODE_ADDRESS;
        else if ((soft_reset_0 && addr == 2'b00) ||
                 (soft_reset_1 && addr == 2'b01) ||
                 (soft_reset_2 && addr == 2'b10))
            state <= DECODE_ADDRESS;
        else
            state <= next_state;
    end

    // Address register - captures destination from header
    always @(posedge clock) begin
        if (~resetn)
            addr <= 2'b00;
        else if (detect_add)
            addr <= data_in[1:0];
    end

    // Next state logic - handles packet flow transitions
    // Moore FSM output logic - generates control signals
    always @(*) begin
        next_state = state;
        case (state)
            DECODE_ADDRESS: begin
                if ((packet_valid && (data_in[1:0] == 2'b00) && fifo_empty_0) ||
                    (packet_valid && (data_in[1:0] == 2'b01) && fifo_empty_1) ||
                    (packet_valid && (data_in[1:0] == 2'b10) && fifo_empty_2))
                    next_state = LOAD_FIRST_DATA;
                else if ((packet_valid && (data_in[1:0] == 2'b00) && ~fifo_empty_0) ||
                         (packet_valid && (data_in[1:0] == 2'b01) && ~fifo_empty_1) ||
                         (packet_valid && (data_in[1:0] == 2'b10) && ~fifo_empty_2))
                    next_state = DECODE_ADDRESS_WAIT;
            end
            
            DECODE_ADDRESS_WAIT: begin
                if ((addr == 2'b00 && fifo_empty_0) ||
                    (addr == 2'b01 && fifo_empty_1) ||
                    (addr == 2'b10 && fifo_empty_2))
                    next_state = LOAD_FIRST_DATA;
            end
            
            LOAD_FIRST_DATA: begin
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else
                    next_state = LOAD_DATA;
            end
            
            LOAD_DATA: begin
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else if (~packet_valid)
                    next_state = LOAD_PARITY;
            end
            
            LOAD_PARITY: begin
                next_state = CHECK_PARITY_ERROR;
            end
            
            FIFO_FULL_STATE: begin
                if (~fifo_full)
                    next_state = LOAD_AFTER_FULL;
            end
            
            LOAD_AFTER_FULL: begin
                if (~parity_done && low_packet_valid)
                    next_state = LOAD_PARITY;
                else if (~parity_done && ~low_packet_valid)
                    next_state = LOAD_DATA;
                else if (parity_done)
                    next_state = DECODE_ADDRESS;
            end
            
            CHECK_PARITY_ERROR: begin
                if (~fifo_full)
                    next_state = DECODE_ADDRESS;
                else
                    next_state = FIFO_FULL_STATE;
            end
        endcase
    end

    always @(*) begin
        detect_add = 0;
        ld_state = 0;
        laf_state = 0;
        lfd_state = 0;
        full_state = 0;
        write_enb_reg = 0;
        rst_int_reg = 0;
        busy = 0;
        
        case (state)
            DECODE_ADDRESS: begin
                detect_add = 1;
            end
            
            DECODE_ADDRESS_WAIT: begin
                detect_add = 1;
            end
            
            LOAD_FIRST_DATA: begin
                lfd_state = 1;
                busy = 1;
            end
            
            LOAD_DATA: begin
                ld_state = 1;
                write_enb_reg = 1;
                busy = 1;
            end
            
            LOAD_PARITY: begin
                busy = 1;
            end
            
            FIFO_FULL_STATE: begin
                full_state = 1;
                busy = 1;
            end
            
            LOAD_AFTER_FULL: begin
                laf_state = 1;
                busy = 1;
            end
            
            CHECK_PARITY_ERROR: begin
                rst_int_reg = 1;
                busy = 1;
            end
        endcase
    end

endmodule

// Register Block - Data buffering and parity calculation
// Handles packet data storage, parity computation, and error detection
module router_register (
    input clock, resetn, packet_valid,
    input [7:0] data_in,
    input fifo_full, detect_add, ld_state, laf_state, full_state, lfd_state, rst_int_reg,
    
    output reg err, parity_done, low_packet_valid,
    output reg [7:0] dout
);

    reg [7:0] hold_header_byte, fifo_full_header_byte, internal_parity, packet_parity_byte;
    reg [7:0] fifo_full_data_reg; // Stores data when FIFO is full
    reg [5:0] count; // Payload byte counter

    always @(posedge clock) begin
        if (~resetn)
            hold_header_byte <= 8'b0;
        else if (detect_add && packet_valid)
            hold_header_byte <= data_in;
    end

    always @(posedge clock) begin
        if (~resetn)
            fifo_full_header_byte <= 8'b0;
        else if (detect_add && packet_valid)
            fifo_full_header_byte <= data_in;
    end

    always @(posedge clock) begin
        if (~resetn)
            fifo_full_data_reg <= 8'b0;
        else if (ld_state && fifo_full)
            fifo_full_data_reg <= data_in;
    end

    // Data output multiplexer - selects appropriate data source
    always @(*) begin
        if (lfd_state)
            dout = hold_header_byte;
        else if (ld_state && ~fifo_full)
            dout = data_in;
        else if (ld_state && fifo_full)
            dout = fifo_full_data_reg;
        else if (laf_state)
            dout = fifo_full_header_byte;
        else
            dout = 8'b0;
    end

    // XOR parity calculation
    always @(posedge clock) begin
        if (~resetn)
            internal_parity <= 8'b0;
        else if (detect_add)
            internal_parity <= 8'b0;
        else if (lfd_state && packet_valid)
            internal_parity <= internal_parity ^ hold_header_byte;
        else if (ld_state && packet_valid && ~full_state)
            internal_parity <= internal_parity ^ data_in;
    end

    always @(posedge clock) begin
        if (~resetn)
            packet_parity_byte <= 8'b0;
        else if (detect_add && packet_valid)
            packet_parity_byte <= 8'b0;
        else if ((ld_state && ~packet_valid) || (laf_state && ~packet_valid && ~parity_done))
            packet_parity_byte <= data_in;
    end

    // Payload length counter - decrements with each data byte
    always @(posedge clock) begin
        if (~resetn)
            count <= 6'b0;
        else if (detect_add)
            count <= data_in[7:2]; // Extract length from header
        else if (ld_state && packet_valid)
            count <= count - 1;
    end

    always @(posedge clock) begin
        if (~resetn)
            low_packet_valid <= 0;
        else
            low_packet_valid <= ~packet_valid;
    end

    always @(posedge clock) begin
        if (~resetn)
            parity_done <= 0;
        else if (detect_add)
            parity_done <= 0;
        else if ((count == 0) && (ld_state || laf_state) && (~packet_valid))
            parity_done <= 1;
    end

    always @(posedge clock) begin
        if (~resetn)
            err <= 0;
        else if (rst_int_reg)
            err <= 0;
        else if (parity_done)
            err <= (internal_parity != packet_parity_byte);
    end

endmodule

// Synchronizer Module - Address decoding and timing control
// Manages write enables, timeouts, and valid output signals for three FIFOs
module router_sync (
    input clock, resetn,
    input [7:0] data_in,
    input detect_add, write_enb_reg,
    input read_enb_0, read_enb_1, read_enb_2,
    input empty_0, empty_1, empty_2,
    input full_0, full_1, full_2,
    
    output reg [2:0] write_enb,
    output reg fifo_full,
    output reg vld_out_0, vld_out_1, vld_out_2,
    output reg soft_reset_0, soft_reset_1, soft_reset_2
);

    reg [1:0] internal_addr;
    reg [4:0] timer_0, timer_1, timer_2; // 30-cycle timeout counters

    always @(posedge clock) begin
        if (~resetn)
            internal_addr <= 2'b0;
        else if (detect_add)
            internal_addr <= data_in[1:0];
    end

    // Write enable decoder - enables correct FIFO based on address
    always @(*) begin
        case (internal_addr)
            2'b00: write_enb = {2'b0, write_enb_reg};
            2'b01: write_enb = {1'b0, write_enb_reg, 1'b0};
            2'b10: write_enb = {write_enb_reg, 2'b0};
            default: write_enb = 3'b0;
        endcase
    end

    // FIFO full multiplexer - selects correct FIFO full status
    always @(*) begin
        case (internal_addr)
            2'b00: fifo_full = full_0;
            2'b01: fifo_full = full_1;
            2'b10: fifo_full = full_2;
            default: fifo_full = 0;
        endcase
    end

    // FIFO 0 valid output and timeout logic (30 cycles)
    always @(posedge clock) begin
        if (~resetn) begin
            vld_out_0 <= 0;
            timer_0 <= 0;
            soft_reset_0 <= 0;
        end else begin
            if (~empty_0)
                vld_out_0 <= 1;
            else
                vld_out_0 <= 0;
                
            if (vld_out_0 && ~read_enb_0)
                timer_0 <= timer_0 + 1;
            else
                timer_0 <= 0;
                
            if (timer_0 == 29) begin
                soft_reset_0 <= 1;
                vld_out_0 <= 0;
                timer_0 <= 0;
            end else
                soft_reset_0 <= 0;
        end
    end

    always @(posedge clock) begin
        if (~resetn) begin
            vld_out_1 <= 0;
            timer_1 <= 0;
            soft_reset_1 <= 0;
        end else begin
            if (~empty_1)
                vld_out_1 <= 1;
            else
                vld_out_1 <= 0;
                
            if (vld_out_1 && ~read_enb_1)
                timer_1 <= timer_1 + 1;
            else
                timer_1 <= 0;
                
            if (timer_1 == 29) begin
                soft_reset_1 <= 1;
                vld_out_1 <= 0;
                timer_1 <= 0;
            end else
                soft_reset_1 <= 0;
        end
    end

    always @(posedge clock) begin
        if (~resetn) begin
            vld_out_2 <= 0;
            timer_2 <= 0;
            soft_reset_2 <= 0;
        end else begin
            if (~empty_2)
                vld_out_2 <= 1;
            else
                vld_out_2 <= 0;
                
            if (vld_out_2 && ~read_enb_2)
                timer_2 <= timer_2 + 1;
            else
                timer_2 <= 0;
                
            if (timer_2 == 29) begin
                soft_reset_2 <= 1;
                vld_out_2 <= 0;
                timer_2 <= 0;
            end else
                soft_reset_2 <= 0;
        end
    end

endmodule

// FIFO Buffer Module - 16-deep circular buffer
// Stores packet data with read/write pointers and full/empty flags
module router_fifo (
    input clock, resetn, soft_reset,
    input write_enb, read_enb, lfd_state,
    input [8:0] data_in, // 9-bit data includes header flag
    
    output reg [7:0] data_out, // 8-bit output data
    output reg full, empty
);

    reg [8:0] mem [15:0]; // 16 locations of 9-bit memory
    reg [3:0] wr_ptr, rd_ptr; // 4-bit pointers for 16 locations
    reg [4:0] count; // 5-bit counter (0 to 16)
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 9'b0;
    end

    always @(posedge clock) begin
        if (~resetn || soft_reset)
            wr_ptr <= 0;
        else if (write_enb && ~full)
            wr_ptr <= wr_ptr + 1;
    end

    always @(posedge clock) begin
        if (~resetn || soft_reset)
            rd_ptr <= 0;
        else if (read_enb && ~empty)
            rd_ptr <= rd_ptr + 1;
    end

    always @(posedge clock) begin
        if (~resetn || soft_reset)
            count <= 0;
        else begin
            case ({write_enb & ~full, read_enb & ~empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    always @(*) begin
        full = (count == 16);
        empty = (count == 0);
    end

    always @(posedge clock) begin
        if (write_enb && ~full)
            mem[wr_ptr] <= data_in;
    end

    always @(posedge clock) begin
        if (~resetn)
            data_out <= 8'b0;
        else if (soft_reset)
            data_out <= 8'bz;
        else if (read_enb && ~empty)
            data_out <= mem[rd_ptr][7:0];
        else if (empty)
            data_out <= 8'bz;
    end

endmodule
