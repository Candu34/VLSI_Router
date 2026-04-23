`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_monitor
`define __apb_monitor

class monitor_apb extends uvm_monitor;

  `uvm_component_utils(monitor_apb)

  // colector de coverage
  coverage_apb colector_coverage_apb;

  // port de analiza catre agent / scoreboard
  uvm_analysis_port #(tranzactie_apb) port_date_monitor_apb;

  // interfata monitorizata
  virtual apb_interface_dut interfata_monitor_apb;

  // tranzactii interne
  tranzactie_apb starea_preluata_a_apb;
  tranzactie_apb aux_tr_apb;

  function new(string name = "monitor_apb", uvm_component parent = null);
    super.new(name, parent);

    port_date_monitor_apb   = new("port_date_monitor_apb", this);
    colector_coverage_apb   = coverage_apb::type_id::create("colector_coverage_apb", this);

    starea_preluata_a_apb   = tranzactie_apb::type_id::create("starea_preluata_a_apb");
    aux_tr_apb              = tranzactie_apb::type_id::create("aux_tr_apb");
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", interfata_monitor_apb)) begin
      `uvm_fatal("MONITOR_APB", "Nu s-a putut accesa interfata monitorului APB")
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // legatura catre coverage
    colector_coverage_apb.p_monitor = this;
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
      // asteapta o tranzactie valida APB
      @(posedge interfata_monitor_apb.pclk);
      wait(interfata_monitor_apb.rst_n &&
           interfata_monitor_apb.psel &&
           interfata_monitor_apb.penable);

      // preluare semnale APB
      starea_preluata_a_apb.write = interfata_monitor_apb.pr_w;
      starea_preluata_a_apb.addr  = interfata_monitor_apb.paddr;
      starea_preluata_a_apb.wdata = interfata_monitor_apb.pwdata;
      starea_preluata_a_apb.rdata = interfata_monitor_apb.prdata;
      starea_preluata_a_apb.ready = interfata_monitor_apb.p_ready;
      starea_preluata_a_apb.error = interfata_monitor_apb.p_error;

      // copiem tranzactia ca sa nu trimitem acelasi handle
      aux_tr_apb = starea_preluata_a_apb.copy();

      // trimitem spre exterior
      port_date_monitor_apb.write(aux_tr_apb);

      `uvm_info("MONITOR_APB",
        $sformatf("S-a receptionat tranzactia APB: write=%0b addr=0x%0h wdata=0x%0h rdata=0x%0h ready=%0b error=%0b",
                  aux_tr_apb.write,
                  aux_tr_apb.addr,
                  aux_tr_apb.wdata,
                  aux_tr_apb.rdata,
                  aux_tr_apb.ready,
                  aux_tr_apb.error),
        UVM_MEDIUM)

      aux_tr_apb.afiseaza_informatia_tranzactiei();

      // sample coverage
      colector_coverage_apb.stari_apb_cg.sample();

      // evita dublarea aceleiasi tranzactii pe doua tacte consecutive
      @(posedge interfata_monitor_apb.pclk);
      wait(!(interfata_monitor_apb.psel && interfata_monitor_apb.penable));
    end
  endtask

endclass

`endif