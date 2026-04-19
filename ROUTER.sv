    // Module: ROUTER
    // Author: Candu Ion
    // Description: 
    //




    // Packet Structure: 32 bits total
    // ============================================
    // [31:28] - Destination address (4 bits → 16 possible, only 0-3 valid) // If the destination is grater than 3, the packet is dropped and an error is logged
    // [27:24] - Source address      (4 bits → who sent this packet)
    // [23:22] - Packet priority     (2 bits → 0=low, 1=normal, 2=high, 3=urgent)
    // [21:20] - Packet type         (2 bits → 00=data, 01=control, 10=status, 11=error)
    // [19:16] - Sequence number     (4 bits → 0-15, tracks packet order)
    // [15:0]  - Payload             (16 bits → actual data)
    // ============================================


    module router (
        // APB Interface
        input                       clk_i       ,
        input                       rst_n_i     ,

        input                       pr_w_i      ,
        input                       penable_i   ,
        input  [7:0]                pwdata_i    ,
        input  [7:0]                paddr_i     ,
        input                       psel_i      ,
        output reg [7:0]            prdata_o    ,
        output reg                  p_error_o   ,
        output reg                  p_ready_o   ,

        // UART Interface
        output       [4-1:0]        uart_tx_o   , 

        // Router Interface
        input  logic [31:0]         data_in     ,   
        input  logic                req_i       ,       // data_in is valid and can be processed
        output logic                ack_o               // router has accepted the packet 

    );

    // LOCAL PARAMETERS ==========================================================

    localparam APB_MEMORY_SIZE  = 6; // 6 bytes of memory for APB registers
    localparam NUM_FIFOS        = 4; // Number of fifo memories (ports * packets priority levels)
    localparam FIFO_SIZE        = 8; // Size of each FIFO in terms of number of packets
    localparam FIFO_WIDTH       = 32; // Width of each FIFO entry 


    //Packet types

    localparam logic [1:0] PKT_DATA    = 2'b00;
    localparam logic [1:0] PKT_CTRL    = 2'b01;
    localparam logic [1:0] PKT_STATUS  = 2'b10;
    localparam logic [1:0] PKT_ERROR   = 2'b11;




    // LOCAL PARAMETERS END ==========================================================


    // Structure Definitions ==========================================================

    typedef struct packed {
        logic [3:0] dest_addr;
        logic [3:0] src_addr;
        logic [1:0] prio;         
        logic [1:0] pkt_type;
        logic [3:0] seq_num;
        logic [15:0] payload;
    } packet_t;


    //Structure Definitions End ==========================================================

    // Internal Registers and Wires ==========================================================


    reg [7:0] memory [0:5]; 


    // Momory Map
    // 0x00 - CNTR Register 0x07 - Enable / Reset Router
    //                      0x06 - Interrupt Enable Register                     


    //0x01 - UART Clock Divider Register 
    //0x02 - 
    //0x03 - Packet Counter Register (Read Only)
    //0x04 - Packet Skipped Counter Register (Read Only)
    //0x05 - Status Register  (Read Only)       x00 - x01 - first fiffo (full, empty, has data) 
    //                                          x02 - x03 - second fifo  
    //                                          x04 - x05 - third fifo 
    //                                          x06 - x07 - fourth fifo  (Read Only)

    //0x06 - Packet Skipped Counter Register (Read Only)

    logic [NUM_FIFOS - 1:0]  fifo_wr_en;
    logic [NUM_FIFOS - 1:0]  fifo_full;
    logic [NUM_FIFOS - 1:0]  fifo_empty;
    logic [NUM_FIFOS - 1:0]  fifo_rd_en;
    logic [31:0] fifo_rd_data [NUM_FIFOS];
    logic [31:0] fifo_wr_data [NUM_FIFOS];
    reg [31:0] fifo_q [NUM_FIFOS];

    // UART Control Signals
    wire  [NUM_FIFOS - 1:0]  uart_ack;

    // TX Controller FSM signals
    localparam TX_IDLE      = 3'd0;
    localparam TX_CFG_BAUD  = 3'd1;
    localparam TX_CFG_WAIT  = 3'd2;
    localparam TX_SEND      = 3'd3;
    localparam TX_WAIT_DONE = 3'd4;

    reg [2:0]   tx_state    [NUM_FIFOS];
    reg [31:0]  uart_data   [NUM_FIFOS];
    reg [3:0]   uart_addr   [NUM_FIFOS];
    reg         uart_req    [NUM_FIFOS];
    reg         cfg_done    [NUM_FIFOS];


    reg baud_changed;

    packet_t pkt;





    // Internal Registers and Wires End ==========================================================

    // APB PROTOCOL IMPLEMENTATION START =========================================================
    //  - APB Write
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            memory[0] <= 8'h00;
            memory[1] <= 8'h00;
            memory[2] <= 8'h00;
            baud_changed <= 1'b0;
        end else begin
            baud_changed <= 1'b0;                      
            if (psel_i && penable_i && pr_w_i) begin
                if (paddr_i < 3) begin
                    memory[paddr_i] <= pwdata_i;
                    if (paddr_i == 1)
                        baud_changed <= 1'b1;          
                end
            end
        end
    end

    //  - APB Read
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            prdata_o <= 8'h00;
        else if (psel_i && penable_i && !pr_w_i) begin
            if (paddr_i < APB_MEMORY_SIZE)
                prdata_o <= memory[paddr_i];
            else
                prdata_o <= 8'h00;
        end
    end

    //  - APB Error
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            p_error_o <= 1'b0;
        else if (psel_i && !penable_i && (paddr_i >= APB_MEMORY_SIZE) && (pr_w_i && (paddr_i >= 3))) // Set error for invalid address or write to read-only register
            p_error_o <= 1'b1;
        else
            p_error_o <= 1'b0;
    end

    //  - APB Ready
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            p_ready_o <= 1'b0;
        else if (psel_i && !penable_i)
            p_ready_o <= 1'b1;
        else
            p_ready_o <= 1'b0;
    end

    // APB PROTOCOL IMPLEMENTATION END =========================================================


    // Packet Parser START=========================================================


    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            fifo_wr_en  <= '0;
            fifo_wr_data <= '{default: '0};
        end else begin
            fifo_wr_en <= '0;                          

            if (req_i && !ack_o) begin                  
                pkt = data_in;                         // no "packet_t pkt;" here

                if (pkt.dest_addr < 4) begin
                    if (!fifo_full[pkt.dest_addr]) begin
                        fifo_wr_en[pkt.dest_addr]   <= 1'b1;
                        fifo_wr_data[pkt.dest_addr] <= data_in;
                    end
                end
            end
        end
    end

    // Packet skipped counter
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            memory[4] <= 8'h00; 
        end else if (req_i && !ack_o) begin              
            pkt = data_in;                              // no declaration, just assign
            if (pkt.dest_addr >= 4) begin
                memory[4] <= memory[4] + 1;
            end else if (fifo_full[pkt.dest_addr]) begin
                memory[4] <= memory[4] + 1;
            end
        end
    end


    // Packet counter
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            memory[3] <= 8'h00; 
        end else if (ack_o) begin
            memory[3] <= memory[3] + 1; // Increment packet counter on successful acknowledgment
        end
    end




    // ack_o 
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            ack_o <= 1'b0;
        end else if (req_i && !ack_o) begin
            ack_o <= 1'b1; 
        end else begin
            ack_o <= 1'b0; 
        end
    end

    genvar i;
    generate
        for (i = 0; i < NUM_FIFOS; i++) begin : gen_tx_ctrl

            always @(posedge clk_i or negedge rst_n_i) begin
                if (!rst_n_i) begin
                    tx_state[i]     <= TX_IDLE;
                    uart_data[i]    <= 32'b0;
                    uart_addr[i]    <= 4'd0;
                    uart_req[i]     <= 1'b0;
                    cfg_done[i]     <= 1'b0;
                    fifo_rd_en[i]   <= 1'b0;
                end else begin
                    uart_req[i]     <= 1'b0;
                    fifo_rd_en[i]   <= 1'b0;

                    if (baud_changed)                  
                        cfg_done[i] <= 1'b0;

                    case (tx_state[i])

                        TX_IDLE: begin
                            if (!cfg_done[i]) begin
                                uart_data[i]    <= {29'b0, memory[1][2:0]};
                                uart_addr[i]    <= 4'd1;
                                uart_req[i]     <= 1'b1;
                                tx_state[i]     <= TX_CFG_BAUD;
                            end else if (!fifo_empty[i]) begin
                                fifo_rd_en[i]   <= 1'b1;
                                tx_state[i]     <= TX_SEND;
                            end
                        end

                        TX_CFG_BAUD: begin
                            if (uart_ack[i]) begin
                                cfg_done[i]     <= 1'b1;
                                tx_state[i]     <= TX_IDLE;
                            end else begin
                                uart_req[i]     <= 1'b1;
                            end
                        end

                        TX_SEND: begin
                            uart_data[i]    <= fifo_rd_data[i];
                            uart_addr[i]    <= 4'd2;
                            uart_req[i]     <= 1'b1;
                            tx_state[i]     <= TX_WAIT_DONE;
                        end

                        TX_WAIT_DONE: begin
                            if (uart_ack[i]) begin
                                tx_state[i]     <= TX_IDLE;
                            end else begin
                                uart_req[i]     <= 1'b1;
                            end
                        end

                        default: tx_state[i] <= TX_IDLE;

                    endcase
                end
            end

        end
    endgenerate


    // FIFO STATUS Register
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            memory[5] <= 8'h00;
        else
            memory[5] <= {fifo_full[3], fifo_empty[3],
                        fifo_full[2], fifo_empty[2],
                        fifo_full[1], fifo_empty[1],
                        fifo_full[0], fifo_empty[0]};
    end

    //Packet parser END =========================================================


    // FIFO MEMORY INSTANCES =========================================================

    fifo_memory #(
        .SIZE  (FIFO_SIZE),
        .WIDTH (FIFO_WIDTH)
    ) u_fifo_0 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .write_i    (fifo_wr_en[0]      ),
        .data_in    (fifo_wr_data[0]    ),
        .read_i     (fifo_rd_en[0]      ),
        .data_out   (fifo_rd_data[0]    ),
        .full_o     (fifo_full[0]       ),
        .empty_o    (fifo_empty[0]      )
    );

    fifo_memory #(
        .SIZE  (FIFO_SIZE),
        .WIDTH (FIFO_WIDTH)
    ) u_fifo_1 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .write_i    (fifo_wr_en[1]      ),
        .data_in    (fifo_wr_data[1]    ),
        .read_i     (fifo_rd_en[1]      ),
        .data_out   (fifo_rd_data[1]    ),
        .full_o     (fifo_full[1]       ),
        .empty_o    (fifo_empty[1]      )
    );

    fifo_memory #(
        .SIZE  (FIFO_SIZE),
        .WIDTH (FIFO_WIDTH)
    ) u_fifo_2 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .write_i    (fifo_wr_en[2]      ),
        .data_in    (fifo_wr_data[2]    ),
        .read_i     (fifo_rd_en[2]      ),
        .data_out   (fifo_rd_data[2]    ),
        .full_o     (fifo_full[2]       ),
        .empty_o    (fifo_empty[2]      )
    );

    fifo_memory #(
        .SIZE  (FIFO_SIZE),
        .WIDTH (FIFO_WIDTH)
    ) u_fifo_3 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .write_i    (fifo_wr_en[3]      ),
        .data_in    (fifo_wr_data[3]    ),
        .read_i     (fifo_rd_en[3]      ),
        .data_out   (fifo_rd_data[3]    ),
        .full_o     (fifo_full[3]       ),
        .empty_o    (fifo_empty[3]      )
    );


    // UART INSTANCES =========================================================

    UART u_uart_0 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .req_i      (uart_req[0]        ),      
        .data_i     (uart_data[0]       ),      
        .addr_i     (uart_addr[0]       ),      
        .tx_o       (uart_tx_o[0]       ),
        .ack_o      (uart_ack[0]        )
    );


    UART u_uart_1 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .req_i      (uart_req[1]        ),      
        .data_i     (uart_data[1]       ),      
        .addr_i     (uart_addr[1]       ),      
        .tx_o       (uart_tx_o[1]       ),
        .ack_o      (uart_ack[1]        )
    );

    UART u_uart_2 (
        .clk_i      (clk_i              ),
        .rst_n_i    (rst_n_i            ),
        .req_i      (uart_req[2]        ),      
        .data_i     (uart_data[2]       ),      
        .addr_i     (uart_addr[2]       ),     
        .tx_o       (uart_tx_o[2]       ),
        .ack_o      (uart_ack[2]        )
    );

    UART u_uart_3 (
        .clk_i      (clk_i                ),
        .rst_n_i    (rst_n_i              ),
        .req_i      (uart_req[3]          ),      
        .data_i     (uart_data[3]         ),
        .addr_i     (uart_addr[3]         ),
        .tx_o       (uart_tx_o[3]         ),
        .ack_o      (uart_ack[3]          )
    );





    endmodule