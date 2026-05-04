`timescale 1ns / 1ps

module UART_tb();

    reg clk_i;
    reg rst_n_i;
    reg req_i;
    reg [31:0] data_i;
    reg [3:0] addr_i;

    wire tx_o;
    wire ack_o;

    UART uut (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .req_i(req_i),
        .data_i(data_i),
        .addr_i(addr_i),
        .tx_o(tx_o),
        .ack_o(ack_o)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 0;
        rst_n_i = 0;
        req_i = 0;
        data_i = 0;
        addr_i = 0;

        // Reset
        #20;
        rst_n_i = 1;
        #20;

        // addr 0 = cfg. Bits [2:1] = 00 (8-bit), Bit [0] = 0 (LSB first)
        addr_i = 4'd0;
        data_i = 32'b000; 
        req_i = 1;
        wait(ack_o);    
        #10 req_i = 0;
        #20;

        // addr 1 = baud. 4 clocks per bit
        addr_i = 4'd1;
        data_i = 32'd4;
        req_i = 1;
        wait(ack_o);
        #10 req_i = 0;
        #20;

        // Transmit data
        // addr 2 = tx_data trigger
        addr_i = 4'd2;
        data_i = 32'hA5; // Binary: 1010_0101
        req_i = 1;
        wait(ack_o);
        #10 req_i = 0;

        // 8 bits + Start + Stop = 10 bits total. 
        #500;

        // Set to 16-bit mode (cfg = 3'b010)
        addr_i = 4'd0;
        data_i = 32'b010; 
        req_i = 1;
        wait(ack_o);
        #10 req_i = 0;
        
        #20;
        
        // Transmit 0x1234
        addr_i = 4'd2;
        data_i = 32'h1234; // Binary: 0001_0010_0011_0100
        req_i = 1;
        wait(ack_o);
        #10 req_i = 0;

        #1000;
        $finish;
    end

endmodule