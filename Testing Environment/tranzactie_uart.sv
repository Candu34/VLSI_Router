`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_transaction
`define __uart_transaction

class tranzactie_uart extends uvm_sequence_item;

    `uvm_object_utils_begin(tranzactie_uart)
        `uvm_field_int(date_receptionate, UVM_ALL_ON)
        `uvm_field_int(numar_biti,        UVM_ALL_ON)
        `uvm_field_int(port_sursa,        UVM_ALL_ON)
    `uvm_object_utils_end

    // campul principal — bitii deserializati de pe tx_o
    bit [31:0] date_receptionate;

    // cati biti au fost capturati (depinde de cfg data_len)
    bit [6:0]  numar_biti;

    // de pe care port UART a venit (0,1,2,3)
    bit [1:0]  port_sursa;

    function new(string name = "tranzactie_uart");
        super.new(name);
        date_receptionate = 32'h0;
        numar_biti        = 7'd32;
        port_sursa        = 2'd0;
    endfunction

    function void afiseaza_informatia_tranzactiei();
        $display("UART transaction -> port=%0d, date=0x%0h, biti=%0d",
                 port_sursa, date_receptionate, numar_biti);
    endfunction

    function tranzactie_uart copy();
        copy = new();
        copy.date_receptionate = this.date_receptionate;
        copy.numar_biti        = this.numar_biti;
        copy.port_sursa        = this.port_sursa;
        return copy;
    endfunction

endclass

`endif