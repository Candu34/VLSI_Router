//IDLE START D7 D6 D5 D4 D3 D2 D1 D0 STOP IDLE



module UART (
input 				clk_i		, 
input 				rst_n_i		,
input 				req_i		,
input [32-1:0]		data_i		,
input [4-1:0]		addr_i		,
output reg			tx_o		,
output reg			ack_o			
);

localparam IDLE 	 		= 1;
localparam START	 		= 0;
localparam STOP		 		= 1;

reg [7-1:0] NUMBER_OF_BITS;            

wire shift_register_wire;
wire shift_enable;




//config register
reg [3-1:0]		cfg;				//#0 addr 

// |  number_of_bits  	| dir |
// |   2  1   			|  0  |
//
//=======================================================================
//
//		dir 
//		0 => LSB first
//		1 => MSB first
//
//		default 0
//		
//=======================================================================
//
//
//=======================================================================
//
//		data_len
//		0 | 0  => 8  bits data
//		0 | 1  => 16 data bits
//		1 | 0  => 32 data bits
//		1 | 1  => 64 data bits	
//
//		default => 1 | 0  (32 bits)
//
//=======================================================================




reg [8-1:0]			baud;		    //#1 store the number of clocks per bit
 
reg [64-1:0]		tx_data;		//#2 addr
	

//Counters
reg [7-1:0] 	cnt;                            
reg [14-1:0] 	div_cnt;



//reg [4-1:0]		
reg [64-1:0]		shift_register;
wire shift_out;
wire transmiting_flag;


//Write cfg register
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) begin 	
		cfg <= 3'b10_0; 
		NUMBER_OF_BITS <= 32;
	end else 
		if (req_i && cnt == 0 && div_cnt == 0 && addr_i == 0) begin
			cfg <= data_i[2:0];
			case (data_i[2:1])                              
				2'b00 : NUMBER_OF_BITS <= 8;					
				2'b01 : NUMBER_OF_BITS <= 16;				
				2'b10 : NUMBER_OF_BITS <= 32;				
				2'b11 : NUMBER_OF_BITS <= 64;
			endcase
		end
			
			
//Write baud register
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) baud <= 8'b0000_0110; else // default 6 clocks per bit
		if (req_i && cnt == 0 && div_cnt == 0 && addr_i == 1)
			baud <= data_i[8-1:0]; else
				baud <= baud;



always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) cnt <= 'b0; else
		if (div_cnt == 0 && cnt != 0) cnt <= cnt - 1; else
			if (ack_o && addr_i == 2) begin
				case (cfg[3-1:1])
					2'b00 : cnt <= 'd10;				// 1 start + 8 data + 1 stop
					2'b01 : cnt <= 'd18;				// 1 start + 16 data + 1 stop
					2'b10 : cnt <= 'd34;				// 1 start + 32 data + 1 stop
					2'b11 : cnt <= 'd66;					
				endcase
			end
		
		
		
//Clocks per bit counter		
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) div_cnt <= 'b0; else
		if (div_cnt != 0) div_cnt <= div_cnt - 1; else
			if ((ack_o && addr_i == 2) || cnt != 0 ) begin
				div_cnt <= baud;
			end else div_cnt <= 'd0;
			
			
 
//Ackonledge 
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) ack_o <= 'b0; else
		if (req_i && cnt == 0 && div_cnt == 0 && !ack_o) ack_o <= 'b1; else
			ack_o <= 'b0;
		

//shift register
always @(posedge clk_i or negedge rst_n_i)
	if (~rst_n_i) shift_register <= 'b0000_0000; else
		if (ack_o && addr_i == 2) shift_register <= data_i; else
			if (shift_enable) begin														
				if (cfg[0]) shift_register <= shift_register << 1; else     
					shift_register <= shift_register >> 1; 
			end                
			
			
//TX		
always @(posedge clk_i or negedge rst_n_i)
	if (!rst_n_i) tx_o <= IDLE; else
		if (cnt != 0) begin
			if (cnt == NUMBER_OF_BITS + 2) tx_o <= START; else
				if (cnt > 1 && cnt <= NUMBER_OF_BITS + 1) tx_o <= shift_register_wire; else
					tx_o <= STOP;
		end else tx_o <= IDLE; 
		
		
assign shift_enable = (div_cnt == 0) &&
                      (cnt > 1) &&
                      (cnt <= NUMBER_OF_BITS + 1); // 


assign shift_register_wire = cfg[0] ? shift_register[NUMBER_OF_BITS - 1] : shift_register[0]; // LSB first or MSB first
					  
					  
endmodule