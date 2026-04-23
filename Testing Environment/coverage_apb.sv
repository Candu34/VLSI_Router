`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_coverage_collector
`define __apb_coverage_collector

class coverage_apb extends uvm_component;

  `uvm_component_utils(coverage_apb)

  monitor_apb p_monitor;

  covergroup stari_apb_cg;
    option.per_instance = 1;

    // Adrese APB relevante pentru router
    cp_addr : coverpoint p_monitor.starea_preluata_a_apb.addr {
      bins ctrl_reg         = {8'h00};
      bins baud_reg         = {8'h01};
      bins cfg_reg          = {8'h02};
      bins pkt_counter_reg  = {8'h03};
      bins pkt_skipped_reg  = {8'h04};
      bins status_reg       = {8'h05};
      bins invalid_addr     = {[8'h06:8'hFF]};
    }

    // Read / Write
    cp_write : coverpoint p_monitor.starea_preluata_a_apb.write {
      bins read_op  = {0};
      bins write_op = {1};
    }

    // Error observat pe interfata
    cp_error : coverpoint p_monitor.starea_preluata_a_apb.error {
      bins no_error = {0};
      bins err      = {1};
    }

    // Ready observat
    cp_ready : coverpoint p_monitor.starea_preluata_a_apb.ready {
      bins not_ready = {0};
      bins ready_ok  = {1};
    }

    // Cross util: pe ce adrese apar erori
    cross_addr_error : cross cp_addr, cp_error;

    // Cross util: read/write pe fiecare tip de adresa
    cross_addr_write : cross cp_addr, cp_write;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    $cast(p_monitor, parent);
    stari_apb_cg = new();
  endfunction

endclass

`endif