`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_coverage_collector
`define __apb_coverage_collector

class coverage_apb extends uvm_component;

  `uvm_component_utils(coverage_apb)

  // tranzactia curenta, populata inainte de sample()
  tranzactie_apb tranzactie_curenta;

  covergroup stari_apb_cg;
    option.per_instance = 1;

    cp_addr : coverpoint tranzactie_curenta.addr {
      bins ctrl_reg        = {8'h00};
      bins baud_reg        = {8'h01};
      bins cfg_reg         = {8'h02};
      bins pkt_counter_reg = {8'h03};
      bins pkt_skipped_reg = {8'h04};
      bins status_reg      = {8'h05};
      bins invalid_addr    = {[8'h06:8'hFF]};
    }

    cp_write : coverpoint tranzactie_curenta.write {
      bins read_op  = {0};
      bins write_op = {1};
    }

    cp_error : coverpoint tranzactie_curenta.error {
      bins no_error = {0};
      bins err      = {1};
    }

    cp_ready : coverpoint tranzactie_curenta.ready {
      bins not_ready = {0};
      bins ready_ok  = {1};
    }

    cross_addr_error : cross cp_addr, cp_error;
    cross_addr_write : cross cp_addr, cp_write;
  endgroup

  function new(string name = "coverage_apb", uvm_component parent = null);
    super.new(name, parent);
    tranzactie_curenta = new("tranzactie_curenta_cov");
    stari_apb_cg = new();
  endfunction

  // apelata din monitor cu tranzactia completa
  function void sample_coverage(tranzactie_apb tr);
    tranzactie_curenta = tr;
    stari_apb_cg.sample();
  endfunction

endclass

`endif