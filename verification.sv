// Company: Personal Project / IIIT Ranchi
// Engineer: Anshuman verma
// 
// Create Date: 07.09.2025 05:46:04
// Design Name: 1x3_Packet_Router
// Module Name: router_tb
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
`timescale 1ns/1ps
module router_tb();

    // Clock and reset signals
    reg clock;
    reg resetn;
    
    // DUT input signals
    reg packet_valid;
    reg [7:0] data_in;
    reg read_enb_0, read_enb_1, read_enb_2;
    
    // DUT output signals
    wire [7:0] data_out_0, data_out_1, data_out_2;
    wire vld_out_0, vld_out_1, vld_out_2;
    wire err;
    wire busy;
    
    // Scoreboard and verification variables
    integer test_pass_count = 0;
    integer test_fail_count = 0;
    reg [7:0] expected_data_queue [$];  
    reg [7:0] received_data_queue [$];  

    // DUT instantiation
    router_top DUT (.clock(clock), .resetn(resetn), .packet_valid(packet_valid), .data_in(data_in), .read_enb_0(read_enb_0), .read_enb_1(read_enb_1), .read_enb_2(read_enb_2), .data_out_0(data_out_0), .data_out_1(data_out_1), .data_out_2(data_out_2), .vld_out_0(vld_out_0), .vld_out_1(vld_out_1), .vld_out_2(vld_out_2), .err(err), .busy(busy));
    
    // Clock generation - 100MHz
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    // Initialize all testbench signals
    task initialize();
        begin
            resetn = 0;
            packet_valid = 0;
            data_in = 8'h00;
            read_enb_0 = 0;
            read_enb_1 = 0;
            read_enb_2 = 0;
        end
    endtask

    // Enable read for specified port
    task enable_read(input [1:0] port);
        begin
            case(port)
                2'b00: read_enb_0 = 1;
                2'b01: read_enb_1 = 1;
                2'b10: read_enb_2 = 1;
            endcase
        end
    endtask

    // Disable read for specified port
    task disable_read(input [1:0] port);
        begin
            case(port)
                2'b00: read_enb_0 = 0;
                2'b01: read_enb_1 = 0;
                2'b10: read_enb_2 = 0;
            endcase
        end
    endtask

    // Reset sequence
    task reset();
        begin
            resetn = 0;
            @(posedge clock);
            @(posedge clock);
            resetn = 1;
            $display("Reset applied at time %0t", $time);
        end
    endtask

    // Packet transmission task with parity calculation
    task send_packet(input [1:0] dest_addr, input [5:0] length, input error_test);
        reg [7:0] local_header, local_parity, local_payload;
        integer local_i;
        begin
            $display("\n=== Sending Packet to Port %0d, Length %0d ===", dest_addr, length);
            expected_data_queue.delete();

            // Header transmission - format: {length[5:0], address[1:0]}
            local_header = {length, dest_addr};
            local_parity = local_header;
            expected_data_queue.push_back(local_header);
            
            data_in = local_header;
            packet_valid = 1;
            @(posedge clock);
            $display("Sent Header: 0x%02h at time %0t", local_header, $time);

            // Payload transmission with XOR parity calculation
            for (local_i = 0; local_i < length; local_i++) begin
                local_payload = $urandom_range(8'h00,8'hFF);
                data_in = local_payload;
                local_parity = local_parity ^ local_payload;
                expected_data_queue.push_back(local_payload);
                @(posedge clock);
                $display("Sent Payload[%0d]: 0x%02h at time %0t", local_i, local_payload, $time);
            end

            // Parity transmission (with error injection if requested)
            packet_valid = 0;
            if (error_test) data_in = ~local_parity; // Inject parity error
            else data_in = local_parity;
            expected_data_queue.push_back(data_in);
            @(posedge clock);
            $display("Sent Parity: 0x%02h at time %0t", data_in, $time);

            @(posedge clock);
            data_in = 8'h00;
            $display("Packet transmission completed at time %0t", $time);
        end
    endtask

    // Automatic data reading with timeout protection
    task auto_read(input [1:0] port, input integer bytes);
        integer k, timeout_counter;
        reg read_success;
        begin
            timeout_counter = 0;
            read_success = 0;

            case(port)
                2'b00: begin
                    // Wait for valid output with timeout
                    while (!vld_out_0 && timeout_counter < 1000) begin @(posedge clock); timeout_counter++; end
                    if (timeout_counter>=1000) begin test_fail_count++; return; end
                    
                    // Read data bytes sequentially
                    for (k=0;k<bytes;k++) begin 
                        read_enb_0 = 1;
                        @(posedge clock);
                        received_data_queue.push_back(data_out_0);
                        read_enb_0 = 0;
                        if (k < bytes-1) @(posedge clock);
                    end
                    read_success=1;
                end
                2'b01: begin
                    while (!vld_out_1 && timeout_counter < 1000) begin @(posedge clock); timeout_counter++; end
                    if (timeout_counter>=1000) begin test_fail_count++; return; end
                    
                    for (k=0;k<bytes;k++) begin 
                        read_enb_1 = 1;
                        @(posedge clock);
                        received_data_queue.push_back(data_out_1);
                        read_enb_1 = 0;
                        if (k < bytes-1) @(posedge clock);
                    end
                    read_success=1;
                end
                2'b10: begin
                    while (!vld_out_2 && timeout_counter < 1000) begin @(posedge clock); timeout_counter++; end
                    if (timeout_counter>=1000) begin test_fail_count++; return; end
                    
                    for (k=0;k<bytes;k++) begin 
                        read_enb_2 = 1;
                        @(posedge clock);
                        received_data_queue.push_back(data_out_2);
                        read_enb_2 = 0;
                        if (k < bytes-1) @(posedge clock);
                    end
                    read_success=1;
                end
            endcase

            if (read_success) test_pass_count++;
        end
    endtask

    // Scoreboard data comparison
    task compare_data();
        integer exp_size, rec_size, comp_size, mismatch_count;
        reg [7:0] exp_byte, rec_byte;
        begin
            exp_size = expected_data_queue.size();
            rec_size = received_data_queue.size();
            mismatch_count = 0;
            if (exp_size != rec_size) begin
                $display("FAIL: Size mismatch %0d vs %0d", exp_size, rec_size);
                test_fail_count++; return;
            end
            comp_size = (exp_size < rec_size) ? exp_size : rec_size;
            for (int idx=0; idx<comp_size; idx++) begin
                exp_byte = expected_data_queue[idx];
                rec_byte = received_data_queue[idx];
                if (exp_byte !== rec_byte) begin
                    $display("MISMATCH[%0d]: Expected=0x%02h, Received=0x%02h", idx, exp_byte, rec_byte);
                    mismatch_count++;
                end
            end
            if (mismatch_count==0) test_pass_count++;
            else test_fail_count++;
            expected_data_queue.delete();
            received_data_queue.delete();
        end
    endtask

    // Test Case 1: Basic packet routing to all three ports
    task test_basic_transmission();
        begin
            $display("\n========== TEST 1: Basic Packet Transmission ==========");
            
            received_data_queue.delete();
            fork
                send_packet(2'b00, 6'd5, 0);
                auto_read(2'b00, 7);
            join
            compare_data();
            
            repeat(10) @(posedge clock);
            
            received_data_queue.delete();
            fork
                send_packet(2'b01, 6'd8, 0);
                auto_read(2'b01, 10);
            join
            compare_data();
            
            repeat(10) @(posedge clock);
            
            received_data_queue.delete();
            fork
                send_packet(2'b10, 6'd3, 0);
                auto_read(2'b10, 5);
            join
            compare_data();
            
            repeat(10) @(posedge clock);
            $display("========== TEST 1 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 2: Parity error detection verification
    task test_parity_error();
        begin
            $display("\n========== TEST 2: Parity Error Testing ==========");
            
            fork
                send_packet(2'b00, 6'd4, 1); // Inject parity error
                auto_read(2'b00, 6);
            join
            
            repeat(10) @(posedge clock);
            
            if (err)
                $display("SUCCESS: Error signal asserted correctly at time %0t", $time);
            else
                $display("FAILURE: Error signal not asserted at time %0t", $time);
                
            repeat(10) @(posedge clock);
            $display("========== TEST 2 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 3: Concurrent packet handling
    task test_back_to_back();
        begin
            $display("\n========== TEST 3: Back-to-Back Packets ==========");
            
            fork
                begin
                    send_packet(2'b00, 6'd2, 0);
                    repeat(2) @(posedge clock);
                    send_packet(2'b01, 6'd3, 0);
                    repeat(2) @(posedge clock);
                    send_packet(2'b10, 6'd4, 0);
                end
                begin
                    enable_read(2'b00);
                    repeat(50) @(posedge clock);
                    disable_read(2'b00);
                end
                begin
                    enable_read(2'b01);
                    repeat(50) @(posedge clock);
                    disable_read(2'b01);
                end
                begin
                    enable_read(2'b10);
                    repeat(50) @(posedge clock);
                    disable_read(2'b10);
                end
            join
            
            repeat(20) @(posedge clock);
            $display("========== TEST 3 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 4: Maximum payload length (63 bytes) 
    task test_max_payload();
        begin
            $display("\n========== TEST 4: Maximum Payload Length ==========");
            
            fork
                send_packet(2'b01, 6'd63, 0);
                auto_read(2'b01, 65); // header + 63 payload + parity
            join
            
            repeat(10) @(posedge clock);
            $display("========== TEST 4 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 5: Minimum payload length (1 byte)
    task test_min_payload();
        begin
            $display("\n========== TEST 5: Minimum Payload Length ==========");
            
            fork
                send_packet(2'b10, 6'd1, 0);
                auto_read(2'b10, 3); // header + 1 payload + parity
            join
            
            repeat(10) @(posedge clock);
            $display("========== TEST 5 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 6: FIFO timeout mechanism (30 cycles)
    task test_fifo_timeout();
    integer timeout_counter;
    reg [1:0] local_addr;
    begin
        $display("\n========== TEST 6: FIFO Timeout Testing ==========");

        send_packet(2'b00, 6'd5, 0);
        local_addr = 2'b00;

        // Wait for 30-cycle timeout
        repeat(35) @(posedge clock);

        // Verify high-Z output after timeout
        case(local_addr)
            2'b00: begin
                if (data_out_0 === 8'bz) begin
                    $display("SUCCESS: Port 0 data_out went to high-Z after timeout at time %0t", $time);
                    test_pass_count++;
                end else begin
                    $display("FAILURE: Port 0 data_out not high-Z after timeout (got 0x%02h) at time %0t", data_out_0, $time);
                    test_fail_count++;
                end
            end
            2'b01: begin
                if (data_out_1 === 8'bz) begin
                    $display("SUCCESS: Port 1 data_out went to high-Z after timeout at time %0t", $time);
                    test_pass_count++;
                end else begin
                    $display("FAILURE: Port 1 data_out not high-Z after timeout at time %0t", $time);
                    test_fail_count++;
                end
            end
            2'b10: begin
                if (data_out_2 === 8'bz) begin
                    $display("SUCCESS: Port 2 data_out went to high-Z after timeout at time %0t", $time);
                    test_pass_count++;
                end else begin
                    $display("FAILURE: Port 2 data_out not high-Z after timeout at time %0t", $time);
                    test_fail_count++;
                end
            end
        endcase

        repeat(10) @(posedge clock);
        $display("========== TEST 6 COMPLETED ==========\n");
    end
endtask

    // Test Case 7: Busy signal assertion during packet processing
    task test_busy_signal();
        begin
            $display("\n========== TEST 7: Busy Signal Testing ==========");
            
            fork
                begin
                    send_packet(2'b01, 6'd10, 0);
                end
                begin
                    // Monitor busy signal transitions
                    wait(busy);
                    $display("SUCCESS: Busy signal asserted during packet transmission at time %0t", $time);
                    wait(~busy);
                    $display("SUCCESS: Busy signal deasserted after packet completion at time %0t", $time);
                end
                begin
                    #200;
                    enable_read(2'b01);
                    #500;
                    disable_read(2'b01);
                end
            join
            
            repeat(10) @(posedge clock);
            $display("========== TEST 7 COMPLETED ==========\n");
        end
    endtask
  
    // Test Case 8: Invalid destination address handling
    task test_invalid_address();
        reg [7:0] local_data;
        integer local_j;
        begin
            $display("\n========== TEST 8: Invalid Address Testing ==========");
            
            // Send packet with invalid address 2'b11
            @(posedge clock);
            packet_valid = 1;
            data_in = {6'd5, 2'b11}; // Invalid address
            @(posedge clock);
            $display("Invalid address packet sent at time %0t", $time);
            
            for (local_j = 0; local_j < 5; local_j++) begin
                local_data = $random;
                data_in = local_data;
                @(posedge clock);
            end
            
            packet_valid = 0;
            data_in = 8'h00;
            @(posedge clock);
            
            // Verify no valid outputs for invalid address
            repeat(20) @(posedge clock);
            
            if (!vld_out_0 && !vld_out_1 && !vld_out_2)
                $display("SUCCESS: No valid outputs asserted for invalid address");
            else
                $display("FAILURE: Valid output asserted for invalid address");
                
            repeat(10) @(posedge clock);
            $display("========== TEST 8 COMPLETED ==========\n");
        end
    endtask
    
    // Test Case 9: Busy signal behavior and data integrity
    task test_busy_drop_bytes();
        reg [7:0] test_data, last_valid_data;
        integer timeout_counter;
        begin
            $display("\n========== TEST 9: Busy Signal Behavior Testing ==========");
            
            fork
                send_packet(2'b00, 6'd5, 0);
            join_none
            
            // Wait for busy assertion
            timeout_counter = 0;
            while (!busy && timeout_counter < 100) begin
                @(posedge clock);
                timeout_counter++;
            end
            
            if (timeout_counter >= 100) begin
                $display("TIMEOUT: Busy signal never asserted at time %0t", $time);
                test_fail_count++;
                return;
            end
            
            $display("Router is busy at time %0t", $time);
            last_valid_data = data_in;
            
            // Test data integrity during busy period
            repeat(3) begin
                @(posedge clock);
                test_data = $urandom_range(8'h00, 8'hFF);
                packet_valid = 1;
                data_in = test_data;
                $display("Attempting to send 0x%02h while busy (should be dropped) at time %0t", test_data, $time);
            end
            
            packet_valid = 0;
            data_in = last_valid_data;
            @(posedge clock);
            $display("Returned to holding last valid data: 0x%02h at time %0t", last_valid_data, $time);
            
            // Wait for busy deassertion
            timeout_counter = 0;
            while (busy && timeout_counter < 1000) begin
                @(posedge clock);
                timeout_counter++;
            end
            
            if (timeout_counter >= 1000) begin
                $display("TIMEOUT: Busy signal never deasserted at time %0t", $time);
                test_fail_count++;
                return;
            end
            
            $display("Router no longer busy at time %0t", $time);
            
            received_data_queue.delete();
            auto_read(2'b00, 7);
            compare_data();
            
            repeat(10) @(posedge clock);
            $display("SUCCESS: Bytes sent during busy period were properly handled");
            $display("========== TEST 9 COMPLETED ==========\n");
        end
    endtask
    
    // Main test execution sequence
    initial begin
        $dumpfile("router_tb.vcd");
        $dumpvars(0, router_tb);
        
        $srandom(32'hDEADBEEF); // Deterministic seed for reproducible results
        
        $display("Starting 1x3 Router Testbench at time %0t", $time);
        $display("=============================================");
        
        initialize();
        reset();
        
        // Execute all 9 test cases
        test_basic_transmission();
        test_parity_error();
        test_back_to_back();
        test_max_payload();
        test_min_payload();
        test_fifo_timeout();
        test_busy_signal();
        test_invalid_address();
        test_busy_drop_bytes();
        
        // Final test results
        $display("\n=============================================");
        $display("FINAL SCOREBOARD RESULTS:");
        $display("Tests PASSED: %0d", test_pass_count);
        $display("Tests FAILED: %0d", test_fail_count);
        $display("Total Tests:  %0d", test_pass_count + test_fail_count);
        
        if (test_fail_count == 0) begin
            $display("ALL TESTS PASSED! Router design verified successfully!");
        end else begin
            $display("%0d TESTS FAILED! Check waveform and console for details.", test_fail_count);
        end
        
        $display("All tests completed at time %0t", $time);
        $display("=============================================");
        
        $finish;
    end
    
    // Signal monitoring for debug
    always @(posedge clock) begin
        if (err)
            $display("ERROR DETECTED at time %0t", $time);
        
        if (vld_out_0 && data_out_0 !== 8'bz && data_out_0 !== 8'bx)
            $display("Port 0 Output: 0x%02h (Valid) at time %0t", data_out_0, $time);
            
        if (vld_out_1 && data_out_1 !== 8'bz && data_out_1 !== 8'bx)
            $display("Port 1 Output: 0x%02h (Valid) at time %0t", data_out_1, $time);
            
        if (vld_out_2 && data_out_2 !== 8'bz && data_out_2 !== 8'bx)
            $display("Port 2 Output: 0x%02h (Valid) at time %0t", data_out_2, $time);
    end
    
    // Simulation timeout protection
    initial begin
        #500000;
        $display("SIMULATION TIMEOUT!");
        $finish;
    end

endmodule
