`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_transaction
`define __apb_transaction

class tranzactie_apb extends uvm_sequence_item;

  `uvm_object_utils(tranzactie_apb)

  // campuri de intrare catre DUT
  rand bit       write;   // 1 = write, 0 = read
  rand bit [7:0] addr;
  rand bit [7:0] wdata;

  // campuri observate dupa transfer
  bit [7:0] rdata;
  bit       error;
  bit       ready;

  function new(string name = "tranzactie_apb");
    super.new(name);
    write = 0;
    addr  = 8'h00;
    wdata = 8'h00;
    rdata = 8'h00;
    error = 1'b0;
    ready = 1'b0;
  endfunction

  function void afiseaza_informatia_tranzactiei();
    $display("APB transaction -> write=%0b, addr=0x%0h, wdata=0x%0h, rdata=0x%0h, ready=%0b, error=%0b",
             write, addr, wdata, rdata, ready, error);
  endfunction

  function tranzactie_apb copy();
    copy = new();
    copy.write = this.write;
    copy.addr  = this.addr;
    copy.wdata = this.wdata;
    copy.rdata = this.rdata;
    copy.error = this.error;
    copy.ready = this.ready;
    return copy;
  endfunction

endclass

`endif