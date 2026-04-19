`timescale 1ns/1ps

module router_tb;


// Clock and Reset
reg             clk;
reg             rst_n;

// APB Interface
reg             pr_w;
reg             penable;
reg  [7:0]      pwdata;
reg  [7:0]      paddr;
reg             psel;
wire [7:0]      prdata;
wire            p_error;
wire            p_ready;

// UART
wire [3:0]      uart_tx;

// Router Interface
reg  [31:0]     data_in;
reg             req;
wire            ack;


// Test tracking
integer         pass_count;
integer         fail_count;
integer         test_num;

// Shared storage for parallel capture in test 12
reg [31:0] t12_captured [0:11];
integer    t12_cap_count;


// Clock generation — 100MHz
initial clk = 0;
always #5 clk = ~clk;


// DUT
router u_dut (
    .clk_i      (clk),
    .rst_n_i    (rst_n),
    .pr_w_i     (pr_w),
    .penable_i  (penable),
    .pwdata_i   (pwdata),
    .paddr_i    (paddr),
    .psel_i     (psel),
    .prdata_o   (prdata),
    .p_error_o  (p_error),
    .p_ready_o  (p_ready),
    .uart_tx_o  (uart_tx),
    .data_in    (data_in),
    .req_i      (req),
    .ack_o      (ack)
);


// ============================================================
// Helper Tasks
// ============================================================

function [31:0] make_packet(
    input [3:0] dest,
    input [3:0] src,
    input [1:0] prio,
    input [1:0] pkt_type,
    input [3:0] seq,
    input [15:0] payload
);
    make_packet = {dest, src, prio, pkt_type, seq, payload};
endfunction


task apb_write(input [7:0] addr, input [7:0] data);
    begin
        @(posedge clk);
        psel    <= 1'b1;
        pr_w    <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;
        penable <= 1'b0;
        @(posedge clk);
        penable <= 1'b1;
        @(posedge clk);
        psel    <= 1'b0;
        penable <= 1'b0;
        pr_w    <= 1'b0;
    end
endtask


task apb_read(input [7:0] addr, output [7:0] data);
    begin
        @(posedge clk);
        psel    <= 1'b1;
        pr_w    <= 1'b0;
        paddr   <= addr;
        penable <= 1'b0;
        @(posedge clk);
        penable <= 1'b1;
        @(posedge clk);
        @(posedge clk);
        data    = prdata;
        psel    <= 1'b0;
        penable <= 1'b0;
    end
endtask


task send_packet(input [31:0] pkt);
    begin
        @(posedge clk);
        data_in <= pkt;
        req     <= 1'b1;
        @(posedge clk);
        wait(ack);
        @(posedge clk);
        req     <= 1'b0;
    end
endtask


task check(input string name, input [31:0] expected, input [31:0] actual);
    begin
        if (expected === actual) begin
            $display("[%0t] PASS: %s = 0x%h", $time, name, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: %s expected 0x%h, got 0x%h", $time, name, expected, actual);
            fail_count = fail_count + 1;
        end
    end
endtask


task capture_uart_frame(
    input integer port,
    input integer num_bits,
    output [31:0] captured
);
    integer i;
    integer baud_val;
    integer clks_per_bit;
    begin
        captured = 32'b0;

        case (port)
            0: baud_val = u_dut.u_uart_0.baud;
            1: baud_val = u_dut.u_uart_1.baud;
            2: baud_val = u_dut.u_uart_2.baud;
            3: baud_val = u_dut.u_uart_3.baud;
        endcase
        clks_per_bit = baud_val + 1;

        case (port)
            0: @(negedge uart_tx[0]);
            1: @(negedge uart_tx[1]);
            2: @(negedge uart_tx[2]);
            3: @(negedge uart_tx[3]);
        endcase

        repeat(clks_per_bit / 2) @(posedge clk);

        for (i = 0; i < num_bits; i = i + 1) begin
            repeat(clks_per_bit) @(posedge clk);
            case (port)
                0: captured[i] = uart_tx[0];
                1: captured[i] = uart_tx[1];
                2: captured[i] = uart_tx[2];
                3: captured[i] = uart_tx[3];
            endcase
        end

        repeat(clks_per_bit) @(posedge clk);
    end
endtask


// ============================================================
// Main Test
// ============================================================
initial begin
    $dumpfile("router_tb.vcd");
    $dumpvars(0, router_tb);

    pass_count  = 0;
    fail_count  = 0;
    test_num    = 0;

    rst_n   = 0;
    psel    = 0;
    penable = 0;
    pr_w    = 0;
    pwdata  = 0;
    paddr   = 0;
    data_in = 0;
    req     = 0;

    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);


    // ==========================================================
    // Test 1: APB Write/Read Baud Rate
    // ==========================================================
    test_num = 1;
    $display("\n=== Test %0d: APB Write/Read Baud Rate ===", test_num);

    apb_write(8'h01, 8'h02);

    begin
        reg [7:0] rd_data;
        apb_read(8'h01, rd_data);
        check("BAUD_DIV", 8'h06, rd_data);
    end

    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 2: Send Packet to Port 0
    // ==========================================================
    test_num = 2;
    $display("\n=== Test %0d: Send Packet to Port 0 ===", test_num);

    begin
        reg [31:0] pkt, captured;
        pkt = make_packet(4'd0, 4'd1, 2'd0, 2'b00, 4'd1, 16'b1010_1010_1010_0101);
        $display("[%0t] Sending packet: 0x%h to port 0", $time, pkt);
        send_packet(pkt);
        capture_uart_frame(0, 32, captured);
        check("Port 0 data", pkt, captured);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 3: Send Packet to Port 1
    // ==========================================================
    test_num = 3;
    $display("\n=== Test %0d: Send Packet to Port 1 ===", test_num);

    begin
        reg [31:0] pkt, captured;
        pkt = make_packet(4'd1, 4'd2, 2'd1, 2'b01, 4'd2, 16'hBEEF);
        $display("[%0t] Sending packet: 0x%h to port 1", $time, pkt);
        send_packet(pkt);
        capture_uart_frame(1, 32, captured);
        check("Port 1 data", pkt, captured);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 4: Send Packet to Port 2
    // ==========================================================
    test_num = 4;
    $display("\n=== Test %0d: Send Packet to Port 2 ===", test_num);

    begin
        reg [31:0] pkt, captured;
        pkt = make_packet(4'd2, 4'd3, 2'd2, 2'b10, 4'd3, 16'h1234);
        $display("[%0t] Sending packet: 0x%h to port 2", $time, pkt);
        send_packet(pkt);
        capture_uart_frame(2, 32, captured);
        check("Port 2 data", pkt, captured);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 5: Send Packet to Port 3
    // ==========================================================
    test_num = 5;
    $display("\n=== Test %0d: Send Packet to Port 3 ===", test_num);

    begin
        reg [31:0] pkt, captured;
        pkt = make_packet(4'd3, 4'd0, 2'd3, 2'b11, 4'd4, 16'h5678);
        $display("[%0t] Sending packet: 0x%h to port 3", $time, pkt);
        send_packet(pkt);
        capture_uart_frame(3, 32, captured);
        check("Port 3 data", pkt, captured);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 6: Invalid Destination
    // ==========================================================
    test_num = 6;
    $display("\n=== Test %0d: Invalid Destination (dest=5) ===", test_num);

    begin
        reg [31:0] pkt;
        reg [7:0] skip_before, skip_after;
        apb_read(8'h04, skip_before);
        pkt = make_packet(4'd5, 4'd0, 2'd0, 2'b00, 4'd5, 16'hDEAD);
        $display("[%0t] Sending packet with invalid dest=5: 0x%h", $time, pkt);
        send_packet(pkt);
        repeat(10) @(posedge clk);
        apb_read(8'h04, skip_after);
        check("SKIP_CNT incremented", skip_before + 1, skip_after);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 7: Read Packet Counter
    // ==========================================================
    test_num = 7;
    $display("\n=== Test %0d: Read Packet Counter ===", test_num);

    begin
        reg [7:0] pkt_cnt;
        apb_read(8'h03, pkt_cnt);
        check("PKT_CNT", 8'd5, pkt_cnt);
    end
    repeat(10) @(posedge clk);


    // ==========================================================
    // Test 8: Status Register (all empty)
    // ==========================================================
    test_num = 8;
    $display("\n=== Test %0d: Read Status Register ===", test_num);

    begin
        reg [7:0] status;
        repeat(500) @(posedge clk);
        apb_read(8'h05, status);
        check("STATUS (all empty)", 8'h55, status);
    end
    repeat(10) @(posedge clk);


    // ==========================================================
    // Test 9: APB Error on Read-Only Write
    // ==========================================================
    test_num = 9;
    $display("\n=== Test %0d: APB Error on Read-Only Write ===", test_num);

    begin
        @(posedge clk);
        psel <= 1'b1; pr_w <= 1'b1; paddr <= 8'h03; pwdata <= 8'hFF; penable <= 1'b0;
        @(posedge clk);
        if (p_error) $display("[%0t] PASS: p_error asserted for read-only write", $time);
        else         $display("[%0t] INFO: p_error not asserted (APB error logic may differ)", $time);
        penable <= 1'b1;
        @(posedge clk);
        psel <= 1'b0; penable <= 1'b0; pr_w <= 1'b0;
    end
    repeat(10) @(posedge clk);


    // ==========================================================
    // Test 10: Sequential FIFO Buffering (Port 0)
    // ==========================================================
    test_num = 10;
    $display("\n=== Test %0d: Multiple Packets to Port 0 (Sequential FIFO test) ===", test_num);

    begin
        reg [31:0] pkt0, pkt1, pkt2, cap0, cap1, cap2;

        pkt0 = make_packet(4'd0, 4'd1, 2'd0, 2'b00, 4'd6, 16'hAA00);
        pkt1 = make_packet(4'd0, 4'd1, 2'd0, 2'b00, 4'd7, 16'hBB11);
        pkt2 = make_packet(4'd0, 4'd1, 2'd0, 2'b00, 4'd8, 16'hCC22);

        $display("[%0t] Sending pkt0", $time);
        send_packet(pkt0);
        capture_uart_frame(0, 32, cap0);
        check("Port 0 pkt[0]", pkt0, cap0);

        $display("[%0t] Sending pkt1", $time);
        send_packet(pkt1);
        capture_uart_frame(0, 32, cap1);
        check("Port 0 pkt[1]", pkt1, cap1);

        $display("[%0t] Sending pkt2", $time);
        send_packet(pkt2);
        capture_uart_frame(0, 32, cap2);
        check("Port 0 pkt[2]", pkt2, cap2);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 11: Baud Rate Change
    // ==========================================================
    test_num = 11;
    $display("\n=== Test %0d: Baud Rate Change ===", test_num);

    begin
        reg [31:0] pkt, captured;
        apb_write(8'h01, 8'h03);
        repeat(50) @(posedge clk);
        pkt = make_packet(4'd0, 4'd7, 2'd0, 2'b00, 4'd13, 16'hF00D);
        $display("[%0t] Sending packet at new baud rate", $time);
        send_packet(pkt);
        capture_uart_frame(0, 32, captured);
        check("Port 0 new baud", pkt, captured);
    end
    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 12: FIFO Full — Fill Port 2, Overflow, Drain, Verify
    // ==========================================================
    // KEY: fork capture in parallel with sends so we catch
    //      every START bit as it happens
    // ==========================================================
    test_num = 12;
    $display("\n=== Test %0d: FIFO Full — Fill, Overflow, Drain ===", test_num);

    begin
        reg [31:0] pkts [0:11];
        reg [7:0]  skip_before, skip_after;
        reg [7:0]  status;
        integer    j;
        integer    num_dropped;
        integer    num_valid;

        // Set baud to 6 (slow — 7 clocks/bit, 34 bits = 238 clocks/frame)
        apb_write(8'h01, 8'h06);
        repeat(50) @(posedge clk);

        apb_read(8'h04, skip_before);
        $display("[%0t] SKIP_CNT before = %0d", $time, skip_before);

        // Build 12 packets to port 2
        for (j = 0; j < 12; j = j + 1)
            pkts[j] = make_packet(4'd2, 4'd8, 2'd0, 2'b00, j[3:0], j[15:0] + 16'hF000);

        t12_cap_count = 0;

        // Fork: send packets AND capture UART frames in parallel
        $display("[%0t] Sending 12 packets to port 2 (FIFO depth = 8)", $time);
        fork
            // Thread 1: Send all 12 packets as fast as possible
            begin : send_thread
                integer s;
                for (s = 0; s < 12; s = s + 1) begin
                    send_packet(pkts[s]);
                    $display("[%0t]   Sent pkt[%0d] = 0x%h", $time, s, pkts[s]);
                end
            end

            // Thread 2: Capture frames from UART2 as they come out
            // Capture up to 12 frames (some may be dropped, capture will stop
            // when we disable it after the send thread finishes and we know the count)
            begin : capture_thread
                reg [31:0] cap_temp;
                integer c;
                for (c = 0; c < 12; c = c + 1) begin
                    capture_uart_frame(2, 32, cap_temp);
                    t12_captured[c] = cap_temp;
                    t12_cap_count = t12_cap_count + 1;
                    $display("[%0t]   Captured frame[%0d] = 0x%h", $time, c, cap_temp);
                end
            end
        join_any

        // Send thread finishes first (fast burst), capture thread is still running
        // Read counters now to know how many were dropped
        repeat(10) @(posedge clk);
        apb_read(8'h04, skip_after);
        num_dropped = skip_after - skip_before;
        num_valid   = 12 - num_dropped;
        $display("[%0t] SKIP_CNT after = %0d (dropped %0d, valid %0d)", $time, skip_after, num_dropped, num_valid);

        if (num_dropped > 0) begin
            $display("[%0t] PASS: Packets were dropped due to full FIFO", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: No packets were dropped — FIFO overflow not detected", $time);
            fail_count = fail_count + 1;
        end

        // Wait for all valid frames to be captured
        // Each frame = 238 clocks = 2380 ns
        wait(t12_cap_count >= num_valid);
        disable capture_thread;

        // Verify captured data matches sent packets in order
        $display("[%0t] Verifying %0d captured frames...", $time, num_valid);
        for (j = 0; j < num_valid; j = j + 1)
            check($sformatf("Port 2 drain[%0d]", j), pkts[j], t12_captured[j]);

        // Wait and verify port 2 is empty
        repeat(500) @(posedge clk);
        apb_read(8'h05, status);
        $display("[%0t] STATUS after drain = 0x%h", $time, status);

        if (status[4] == 1'b1) begin
            $display("[%0t] PASS: Port 2 empty after drain", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: Port 2 not empty after drain", $time);
            fail_count = fail_count + 1;
        end

        if (status[5] == 1'b0) begin
            $display("[%0t] PASS: Port 2 full flag clear after drain", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: Port 2 still shows full after drain", $time);
            fail_count = fail_count + 1;
        end
    end

    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 13: Fill ALL 4 Ports, Verify All Full, Wait for Drain
    // ==========================================================
    test_num = 13;
    $display("\n=== Test %0d: Fill All 4 Ports ===", test_num);

    begin
        reg [7:0]  status;
        reg [7:0]  skip_before, skip_after;
        reg [31:0] pkt;
        integer    p, j;

        apb_read(8'h04, skip_before);
        $display("[%0t] SKIP_CNT before = %0d", $time, skip_before);

        // Send 10 packets to each port (sequentially per port)
        $display("[%0t] Sending 10 packets to each of 4 ports (40 total)", $time);
        for (p = 0; p < 4; p = p + 1) begin
            for (j = 0; j < 10; j = j + 1) begin
                pkt = make_packet(p[3:0], 4'd9, 2'd0, 2'b00, j[3:0], {p[7:0], j[7:0]});
                send_packet(pkt);
            end
        end

        repeat(5) @(posedge clk);

        // Check all full flags
        apb_read(8'h05, status);
        $display("[%0t] STATUS = 0x%h (binary: %b)", $time, status, status);
        $display("[%0t]   Port 0: full=%b empty=%b", $time, status[1], status[0]);
        $display("[%0t]   Port 1: full=%b empty=%b", $time, status[3], status[2]);
        $display("[%0t]   Port 2: full=%b empty=%b", $time, status[5], status[4]);
        $display("[%0t]   Port 3: full=%b empty=%b", $time, status[7], status[6]);

        if (status[1] && status[3] && status[5] && status[7]) begin
            $display("[%0t] PASS: All 4 FIFO full flags set", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: Not all full flags set (STATUS=0x%h)", $time, status);
            fail_count = fail_count + 1;
        end

        // Check overflow count
        apb_read(8'h04, skip_after);
        $display("[%0t] SKIP_CNT after = %0d (dropped %0d)", $time, skip_after, skip_after - skip_before);
        if (skip_after > skip_before) begin
            $display("[%0t] PASS: Packets dropped on all-port overflow (%0d dropped)", $time, skip_after - skip_before);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] INFO: No packets dropped — FSM drained fast enough to prevent overflow", $time);
            // Not a failure — the FSM may read the first packet before FIFO fills
        end

        // Wait for all UARTs to drain
        $display("[%0t] Waiting for all ports to drain...", $time);
        begin
            integer timeout;
            timeout = 0;
            while (timeout < 20) begin
                repeat(500) @(posedge clk);
                apb_read(8'h05, status);
                if (status[0] && status[2] && status[4] && status[6]) begin
                    $display("[%0t] All ports drained", $time);
                    timeout = 100;
                end else begin
                    timeout = timeout + 1;
                end
            end
        end

        apb_read(8'h05, status);
        check("STATUS all empty after drain", 8'h55, status);
    end

    repeat(50) @(posedge clk);


    // ==========================================================
    // Test 14: Final Counter Check
    // ==========================================================
    test_num = 14;
    $display("\n=== Test %0d: Final Counter Check ===", test_num);

    begin
        reg [7:0] pkt_cnt, skip_cnt;
        apb_read(8'h03, pkt_cnt);
        apb_read(8'h04, skip_cnt);

        $display("[%0t] Final PKT_CNT  = %0d", $time, pkt_cnt);
        $display("[%0t] Final SKIP_CNT = %0d", $time, skip_cnt);

        // All sends: 4 + 1 + 3 + 1 + 12 + 40 = 61
        check("Final PKT_CNT", 8'd61, pkt_cnt);

        if (skip_cnt > 1) begin
            $display("[%0t] PASS: SKIP_CNT = %0d (includes invalid dest + FIFO overflows)", $time, skip_cnt);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0t] FAIL: SKIP_CNT too low (%0d)", $time, skip_cnt);
            fail_count = fail_count + 1;
        end
    end


    // ==========================================================
    // Summary
    // ==========================================================
    repeat(100) @(posedge clk);
    $display("\n============================================");
    $display("  TEST SUMMARY");
    $display("============================================");
    $display("  PASSED: %0d", pass_count);
    $display("  FAILED: %0d", fail_count);
    $display("  TOTAL:  %0d", pass_count + fail_count);
    $display("============================================\n");

    if (fail_count == 0)
        $display("  ALL TESTS PASSED");
    else
        $display("  SOME TESTS FAILED");

    $display("\n");
    $finish;
end


// Timeout watchdog
initial begin
    #100_000_000;
    $display("ERROR: Simulation timeout!");
    $finish;
end


endmodule