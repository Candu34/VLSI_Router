`timescale 1ns/1ps

module UART_tb;

reg				clk;
reg				rst_n;
reg				req;
reg [31:0]		data;
reg [3:0]		addr;
wire			tx;
wire			ack;
wire [7:0]		data_out;
wire			data_ready;


// Clock generation — 100MHz
initial clk = 0;
always #5 clk = ~clk;


// DUT
UART u_dut (
	.clk_i			(clk),
	.rst_n_i		(rst_n),
	.req_i			(req),
	.data_i			(data),
	.addr_i			(addr),
	.tx_o			(tx),
	.ack_o			(ack),
	.data_o			(data_out),
	.data_ready_o	(data_ready)
);


// Task — write a register and wait for ack
task write_reg(input [3:0] a, input [31:0] d);
	begin
		@(posedge clk);
		addr <= a;
		data <= d;
		req  <= 1'b1;
		@(posedge clk);
		wait(ack);
		@(posedge clk);
		req <= 1'b0;
	end
endtask



// Task — capture one UART frame from tx_o and verify
task capture_and_check(input [63:0] expected, input integer num_bits, input lsb_first);
		integer i;
	reg [63:0] captured;
	reg [63:0] mask;
	begin
		captured = 64'b0;

		// Wait for START bit (falling edge on tx)
		@(negedge tx);
		$display("[%0t] START bit detected", $time);

		// Wait half baud to sample mid-bit
		repeat(u_dut.baud / 2) @(posedge clk);

		// Verify START = 0
		if (tx !== 1'b0)
			$display("[%0t] ERROR: START bit not 0, got %b", $time, tx);

		// Sample each data bit
		for (i = 0; i < num_bits; i = i + 1) begin
			repeat(u_dut.baud + 1) @(posedge clk);
			if (lsb_first)
				captured[i] = tx;
			else
				captured[num_bits - 1 - i] = tx;
		end

		// Check STOP bit
		repeat(u_dut.baud + 1) @(posedge clk);
		if (tx !== 1'b1)
			$display("[%0t] ERROR: STOP bit not 1, got %b", $time, tx);

		mask = (num_bits == 64) ? 64'hFFFF_FFFF_FFFF_FFFF : ((64'b1 << num_bits) - 1);

		if ((captured & mask) === (expected & mask))
			$display("[%0t] PASS: captured = 0x%h", $time, captured & mask);
		else
			$display("[%0t] FAIL: expected 0x%h, got 0x%h", $time, expected & mask, captured & mask);
	end
endtask



// Main test
initial begin
	$dumpfile("uart_tb.vcd");
	$dumpvars(0, UART_tb);

	rst_n = 0;
	req   = 0;
	addr  = 0;
	data  = 0;

	repeat(10) @(posedge clk);
	rst_n = 1;
	repeat(5) @(posedge clk);


	//==============================================
	// Test 1: Default config (32-bit, LSB first)
	//         baud = 6 (default)
	//==============================================
	$display("\n=== Test 1: 32-bit LSB first, data = 0xDEADBEEF ===");

	// Write data to addr 2
	write_reg(4'd2, 32'hDEAD_BEEF);

	// Capture and verify
	capture_and_check(64'h0000_0000_DEAD_BEEF, 32, 1);

	repeat(50) @(posedge clk);


	//==============================================
	// Test 2: 8-bit mode, LSB first
	//==============================================
	$display("\n=== Test 2: 8-bit LSB first, data = 0xA5 ===");

	// Configure: cfg = 3'b00_0 (8-bit, LSB first)
	write_reg(4'd0, 32'h0000_0000);

	repeat(10) @(posedge clk);

	// Send data
	write_reg(4'd2, 32'h0000_00A5);

	capture_and_check(64'hA5, 8, 1);

	repeat(50) @(posedge clk);


	//==============================================
	// Test 3: 8-bit mode, MSB first
	//==============================================
	$display("\n=== Test 3: 8-bit MSB first, data = 0xA5 ===");

	// Configure: cfg = 3'b00_1 (8-bit, MSB first)
	write_reg(4'd0, 32'h0000_0001);

	repeat(10) @(posedge clk);

	// Send data
	write_reg(4'd2, 32'h0000_00A5);

	capture_and_check(64'hA5, 8, 0);

	repeat(50) @(posedge clk);


	//==============================================
	// Test 4: 16-bit mode, LSB first
	//==============================================
	$display("\n=== Test 4: 16-bit LSB first, data = 0xCAFE ===");

	// Configure: cfg = 3'b01_0 (16-bit, LSB first)
	write_reg(4'd0, 32'h0000_0002);

	repeat(10) @(posedge clk);

	write_reg(4'd2, 32'h0000_CAFE);

	capture_and_check(64'hCAFE, 16, 1);

	repeat(50) @(posedge clk);


	//==============================================
	// Test 5: Change baud rate, 32-bit
	//==============================================
	$display("\n=== Test 5: 32-bit LSB, baud = 3, data = 0x12345678 ===");

	// Set baud to 3
	write_reg(4'd1, 32'h0000_0003);

	// Set 32-bit mode
	write_reg(4'd0, 32'h0000_0004);

	repeat(10) @(posedge clk);

	write_reg(4'd2, 32'h1234_5678);

	capture_and_check(64'h0000_0000_1234_5678, 32, 1);

	repeat(50) @(posedge clk);


	//==============================================
	// Test 6: Back-to-back transmissions
	//==============================================
	$display("\n=== Test 6: Back-to-back, 8-bit LSB ===");

	write_reg(4'd0, 32'h0000_0000);		// 8-bit LSB
	write_reg(4'd1, 32'h0000_0006);		// baud = 6

	repeat(10) @(posedge clk);

	write_reg(4'd2, 32'h0000_00FF);
	capture_and_check(64'hFF, 8, 1);

	repeat(20) @(posedge clk);

	write_reg(4'd2, 32'h0000_0055);
	capture_and_check(64'h55, 8, 1);

	repeat(50) @(posedge clk);


	$display("\n=== All tests complete ===");
	$finish;
end


// Timeout watchdog
initial begin
	#5_000_000;
	$display("ERROR: Simulation timeout!");
	$finish;
end


endmodule