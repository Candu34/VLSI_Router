module APB(
    input               clk_i,
    input               rst_n_i,

    input               pr_w_i,
    input               penable_i,
    input  [7:0]        pwdata_i,
    input  [7:0]        paddr_i,
    input               psel_i,
    output reg [7:0]    prdata_o,
    output reg          p_error_o,
    output reg          p_ready_o
);


reg [7:0] memory [0:4];

// Write
always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        memory[0] <= 8'h00;
        memory[1] <= 8'h00;
        memory[2] <= 8'h00;
        memory[3] <= 8'h00;
        memory[4] <= 8'h00;
    end else if (psel_i && penable_i && pr_w_i) begin
        if (paddr_i < 5) begin
            memory[paddr_i] <= pwdata_i;
        end
    end
end

// Read
always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
        prdata_o <= 8'h00;
    else if (psel_i && penable_i && !pr_w_i) begin
        if (paddr_i < 5)
            prdata_o <= memory[paddr_i];
        else
            prdata_o <= 8'h00;
    end
end

// error
always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
        p_error_o <= 1'b0;
    else if (psel_i && !penable_i)
        p_error_o <= (paddr_i >= 5);
end

// Ready signal
always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
        p_ready_o <= 1'b0;
    else if (psel_i && !penable_i)
        p_ready_o <= 1'b1;
    else
        p_ready_o <= 1'b0;
end

endmodule
