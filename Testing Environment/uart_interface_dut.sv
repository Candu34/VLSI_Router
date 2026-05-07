`ifndef __uart_intf
`define __uart_intf

`include "uvm_macros.svh"
import uvm_pkg::*;

interface uart_interface_dut (
    input logic clk,
    input logic rst_n
);

    // Semnale de la UART (output din UART)
    logic tx;

    // ================================================================
    // CLOCKING BLOCK
    // ================================================================
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input tx;
    endclocking

    // ================================================================
    // MODPORT
    // ================================================================
    modport monitor_mp (clocking monitor_cb, input rst_n);

    // ================================================================
    // ASSERTII — Protocol UART pe linia TX
    // ================================================================

    // Regula 1: linia TX trebuie sa fie IDLE (1) la reset
    // Cand rst_n devine 1, in urmatorul ciclu tx trebuie sa fie 1
    property uart_tx_idle_after_reset;
        @(posedge clk)
        $rose(rst_n) |=> tx;
    endproperty
    UART_TX_IDLE_AFTER_RESET: assert property (uart_tx_idle_after_reset)
        else `uvm_error("UART_INTF", "TX nu este IDLE dupa reset")

    // Regula 2: linia TX nu are voie sa fie X sau Z niciodata
    property uart_tx_no_unknown;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tx);
    endproperty
    UART_TX_NO_UNKNOWN: assert property (uart_tx_no_unknown)
        else `uvm_error("UART_INTF", "TX are valoare necunoscuta X/Z")

    // Regula 3: start bit — cand tx cade din 1 in 0 
    // urmatorul bit dupa start nu poate fi imediat 1 (stop)
    // adica trebuie cel putin un bit de date intre start si stop
    property uart_tx_min_frame;
        @(posedge clk) disable iff (!rst_n)
        $fell(tx) |-> ##[2:$] $rose(tx);  // dupa start, stop vine dupa minim 2 cicluri
    endproperty
    UART_TX_MIN_FRAME: assert property (uart_tx_min_frame)
        else `uvm_error("UART_INTF", "Frame UART prea scurt — lipsesc biti de date")

    // Regula 4: dupa stop bit (tx=1), linia ramane idle
    // sau incepe un nou start bit — nu poate merge direct in alta stare
    property uart_tx_after_stop;
        @(posedge clk) disable iff (!rst_n)
        $rose(tx) |-> (tx || $fell(tx));  // dupa stop: ramane 1 sau incepe alt start
    endproperty
    UART_TX_AFTER_STOP: assert property (uart_tx_after_stop)
        else `uvm_error("UART_INTF", "Comportament invalid dupa stop bit")

endinterface

`endif