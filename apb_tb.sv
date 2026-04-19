`timescale 1ns/1ps

module apb_tb;

reg clk;
reg rst_n;
reg pr_w, penable, psel;
wire [7:0] prdata;
wire perror, p_ready;
reg [7:0] pwdata;
reg [7:0] paddr;

initial begin
  clk = 0;
  forever #10 clk = ~clk; 
end

task reset;
  begin
    rst_n = 0;
    #40;
    rst_n = 1;
    #20;
  end
endtask

APB uut(
    .clk_i      (clk),
    .rst_n_i    (rst_n),    
    .pr_w_i     (pr_w),
    .penable_i  (penable),
    .pwdata_i   (pwdata),
    .paddr_i    (paddr),
    .psel_i     (psel),
    .prdata_o   (prdata),      
    .p_error_o  (perror),
    .p_ready_o  (p_ready)
);

task write_data;
  input [7:0] data;
  input [7:0] address;
  begin
    @(posedge clk);
    pr_w = 1; 
    pwdata = data;
    paddr = address;
    psel <= 1;
    penable <= 0;
    @(posedge clk);
    penable <= 1; 
    @(posedge clk);
    psel <= 0; 
    penable <= 0; 
    @(posedge clk); 
  end
endtask

task read_data;
  input [7:0] address;
  begin
    @(posedge clk);
    pr_w = 0; 
    paddr = address;
    psel <= 1;
    penable <= 0;
    @(posedge clk);
    penable <= 1; 
    @(posedge clk); 
    psel <= 0; 
    penable <= 0; 
    @(posedge clk);
  end
endtask

initial begin
  reset;

  write_data(8'hFF, 8'h00);
  read_data(8'h00);

  // write_data(8'hAA, 8'h01);
  // read_data(8'h01);

  // write_data(8'h55, 8'h02);
  // read_data(8'h02);

  // write_data(8'h00, 8'h03);
  // read_data(8'h03);

  write_data(8'hFF, 8'h04);
  read_data(8'h04);

  write_data(8'hFF, 8'h05);
  read_data(8'h04);

  write_data(8'hFF, 8'h04);
  read_data(8'h04);

    write_data(8'h00, 8'h06);
  read_data(8'h03);

  write_data(8'h55, 8'h02);
  read_data(8'h02);

  $finish;
end

endmodule