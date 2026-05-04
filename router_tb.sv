`timescale 1ns / 1ps

module router_tb();

    reg         clk_i;
    reg         rst_n_i;
    reg         psel_i;
    reg         penable_i;
    reg         pr_w_i;
    reg  [31:0] paddr_i;
    reg  [31:0] pwdata_i;

    wire [31:0] prdata_o;
    wire        p_ready_o;
    wire        p_error_o;
    wire [3:0]  uart_tx_o;

    router uut (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pr_w_i(pr_w_i),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .prdata_o(prdata_o),
        .p_ready_o(p_ready_o),
        .p_error_o(p_error_o),
        .uart_tx_o(uart_tx_o)
    );

    always #5 clk_i = ~clk_i;

    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk_i);
            psel_i    <= 1'b1;
            pr_w_i    <= 1'b1;
            paddr_i   <= addr;
            pwdata_i  <= data;
            @(posedge clk_i);
            penable_i <= 1'b1;
            wait(p_ready_o);
            @(posedge clk_i);
            psel_i    <= 1'b0;
            penable_i <= 1'b0;
            pr_w_i    <= 1'b0;
        end
    endtask

    task apb_read(input [31:0] addr);
        begin
            @(posedge clk_i);
            psel_i    <= 1'b1;
            pr_w_i    <= 1'b0;
            paddr_i   <= addr;
            @(posedge clk_i);
            penable_i <= 1'b1;
            wait(p_ready_o);
            @(posedge clk_i);
            psel_i    <= 1'b0;
            penable_i <= 1'b0;
        end
    endtask


    initial begin
        clk_i     = 0;
        rst_n_i   = 0;
        psel_i    = 0;
        penable_i = 0;
        pr_w_i    = 0;
        paddr_i   = 0;
        pwdata_i  = 0;

        #50;
        rst_n_i = 1;
        @(posedge clk_i);
        @(posedge clk_i);
        @(posedge clk_i);


        //1. Configure Baud Rate (Address 1)
        apb_write(32'h1, 32'd3);
        repeat (4) @(posedge clk_i);

        // 2. Send Packet to Port 0 
        // [31:28] Dest=0, [27:24] Src=1, [23:16] Prio=0, [15:0] Data=A5A5
        apb_write(32'h2, 32'h0100_A5A5);
        repeat (3 * 35) @(posedge clk_i);
       

        // 3. Send Packet to Port 3 
        // [31:28] Dest=3, [27:24] Src=2, [23:16] Prio=0, [15:0] Data=BEEF
        apb_write(32'h2, 32'h3200_BEEF);
        
        repeat (3 * 35) @(posedge clk_i);

        apb_write(32'd2, 32'b0011_0101_0101_0101_0101_0101_0101_0101);
        repeat (3 * 35) @(posedge clk_i);

        // 4. Send Invalid Packet (Address 2)
        // Dest = 4 (Invalid Port)
        apb_write(32'd2, 32'h4100_DEAD);
        repeat (3 * 35) @(posedge clk_i);

        //
        

        // 5. Read Back Counters
        apb_read(32'd3); // Total Packet Count (Should be 3)
        $display("Total Packet Count: %d", prdata_o);

        @(posedge clk_i);
        apb_read(32'd4); // Skipped/Error Count (Should be 1)
        $display("Skipped/Error Count: %d", prdata_o);
        @(posedge clk_i);
        @(posedge clk_i);
        $display("Simulation complete. Check waveforms.");
        $finish;
    end

endmodule