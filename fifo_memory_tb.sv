`timescale 1ns / 1ps

module fifo_memory_tb();


    parameter WIDTH = 8;
    parameter SIZE = 10;


    reg clk_i;
    reg rst_n_i;
    reg [WIDTH - 1:0] data_in;
    reg write_i;
    reg read_i;


    wire full_o;
    wire empty_o;
    wire [WIDTH - 1:0] data_out;

    fifo_memory #(
        .WIDTH(WIDTH),
        .SIZE(SIZE)
    ) uut (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .data_in(data_in),
        .write_i(write_i),
        .read_i(read_i),
        .full_o(full_o),
        .empty_o(empty_o),
        .data_out(data_out)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 0;
        rst_n_i = 0;
        data_in = 0;
        write_i = 0;
        read_i = 0;

        // Reset
        #20;
        rst_n_i = 1;
        #10;

        //Simple Write Read
        data_in = 8'hAA;
        write_i = 1;
        #10;
        write_i = 0;
        #10;
        
        read_i = 1;
        #10;
        read_i = 0;
        #20;

        //Fill the FIFO
        repeat (SIZE) begin
            data_in = data_in + 1;
            write_i = 1;
            #10;
        end
        write_i = 0;
        #30; 

        //Empty the FIFO
        repeat (SIZE) begin
            read_i = 1;
            #10;
        end
        read_i = 0;
        #30; 

        $finish;
    end

endmodule