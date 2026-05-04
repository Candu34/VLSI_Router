`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_transaction
`define __uart_transaction

class tranzactie_uart extends uvm_sequence_item;

  `uvm_object_utils(tranzactie_uart)

  // campuri conduse catre UART
  rand bit [3:0]  addr;
  rand bit [31:0] data;

  // camp observat dupa handshake
  bit ack_observed;

  function new(string name = "tranzactie_uart");
    super.new(name);
    addr         = 4'h0;
    data         = 32'h0000_0000;
    ack_observed = 1'b0;
  endfunction

  function void afiseaza_informatia_tranzactiei();
    $display("UART transaction -> addr=0x%0h, data=0x%0h, ack_observed=%0b",
             addr, data, ack_observed);
  endfunction

  function tranzactie_uart copy();
    copy = new();
    copy.addr         = this.addr;
    copy.data         = this.data;
    copy.ack_observed = this.ack_observed;
    return copy;
  endfunction

endclass

`endif