`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_monitor
`define __apb_monitor

class monitor_apb extends uvm_monitor;

  `uvm_component_utils(monitor_apb)

  coverage_apb colector_coverage_apb;

  uvm_analysis_port #(tranzactie_apb) port_date_monitor_apb;

  virtual apb_interface_dut interfata_monitor_apb;

  tranzactie_apb starea_preluata_a_apb;
  tranzactie_apb aux_tr_apb;

  function new(string name = "monitor_apb", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    port_date_monitor_apb = new("port_date_monitor_apb", this);

    // creat in build_phase, nu in constructor
    colector_coverage_apb = coverage_apb::type_id::create("colector_coverage_apb", this);

    starea_preluata_a_apb = tranzactie_apb::type_id::create("starea_preluata_a_apb");
    aux_tr_apb            = tranzactie_apb::type_id::create("aux_tr_apb");

    if (!uvm_config_db#(virtual apb_interface_dut)::get(
          this, "", "apb_interface_dut", interfata_monitor_apb)) begin
      `uvm_fatal("MONITOR_APB", "Nu s-a putut accesa interfata monitorului APB")
    end
  endfunction

  // connect_phase nu mai e necesara — coverage nu mai depinde de monitor

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
      // asteapta front pozitiv de ceas
      @(interfata_monitor_apb.monitor_cb);

      // asteapta conditie valida de transfer APB
      if (interfata_monitor_apb.rst_n                   &&
          interfata_monitor_apb.monitor_cb.psel         &&
          interfata_monitor_apb.monitor_cb.penable) begin

        // preluare semnale din clocking block (evitam race condition)
        starea_preluata_a_apb.write = interfata_monitor_apb.monitor_cb.pwrite;
        starea_preluata_a_apb.addr  = interfata_monitor_apb.monitor_cb.paddr;
        starea_preluata_a_apb.wdata = interfata_monitor_apb.monitor_cb.pwdata;
        starea_preluata_a_apb.rdata = interfata_monitor_apb.monitor_cb.prdata;
        starea_preluata_a_apb.ready = interfata_monitor_apb.monitor_cb.p_ready;
        starea_preluata_a_apb.error = interfata_monitor_apb.monitor_cb.p_error;

        aux_tr_apb = starea_preluata_a_apb.copy();

        port_date_monitor_apb.write(aux_tr_apb);

        `uvm_info("MONITOR_APB",
          $sformatf("Tranzactie APB capturata: write=%0b addr=0x%0h wdata=0x%0h rdata=0x%0h ready=%0b error=%0b",
                    aux_tr_apb.write, aux_tr_apb.addr, aux_tr_apb.wdata,
                    aux_tr_apb.rdata, aux_tr_apb.ready, aux_tr_apb.error),
          UVM_MEDIUM)

        aux_tr_apb.afiseaza_informatia_tranzactiei();

        // sample cu tranzactia completa
        colector_coverage_apb.sample_coverage(aux_tr_apb);

        // asteapta sfarsitul fazei ACCESS inainte de urmatoarea captura
        @(interfata_monitor_apb.monitor_cb);
        wait(!(interfata_monitor_apb.monitor_cb.psel &&
               interfata_monitor_apb.monitor_cb.penable));
      end
    end
  endtask

endclass

`endif