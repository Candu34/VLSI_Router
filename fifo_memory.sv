module fifo_memory #(
parameter WIDTH = 32,
parameter SIZE = 10
) (
input 					clk_i,
input 					rst_n_i,
input [WIDTH - 1:0]		data_in,
input 					write_i,
input 					read_i,
output reg				full_o,
output reg				empty_o,
output [WIDTH - 1:0]	data_out
);

reg [WIDTH - 1:0] memory [SIZE - 1:0];
wire set_full, set_empty;


reg [$clog2(SIZE):0] wp = 'b0;
reg [$clog2(SIZE):0] rp = 'b0;

wire [$clog2(SIZE):0] wp_next; 
wire [$clog2(SIZE):0] rp_next;


//empty_o
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) empty_o <= 1'b1; else
		if (set_empty) empty_o <= 1'b1; else
			if(write_i) empty_o <= 1'b0;
			
			
// full_o
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) full_o <= 1'b0; else
		if (read_i) full_o <= 1'b0; else
			if (set_full) full_o <= 1'b1; 
			
		

//data_in	
always @(posedge clk_i)
	if (write_i && ~full_o) memory[wp] <= data_in; 
	
	
// rp | read pointer
always @(posedge clk_i or negedge rst_n_i)
	if(~rst_n_i) rp <= 'b0; else
		if (read_i && ~empty_o) begin 
			if (rp == SIZE - 1) rp <= 'b0; else
				rp <= rp + 1;
		end


//wp | write pointer
always @(posedge clk_i or negedge rst_n_i)
	if(~rst_n_i) wp <= 'b0; else
		if (write_i && ~full_o)
			wp <= wp_next;

//data_out
assign data_out = memory[rp];

//wp_next
assign wp_next = (wp == SIZE - 1) ? 0 : wp + 1;

//wp_next
assign rp_next = (rp == SIZE - 1) ? 0 : rp + 1;

//set_empty
assign set_empty = (rp_next == wp) && read_i;
//set_full
assign set_full 	= (wp_next == rp) && write_i;

endmodule






