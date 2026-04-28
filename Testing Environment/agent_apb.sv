`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_agent
`define __apb_agent

typedef class monitor_apb;

`include "tranzactie_apb.sv"
`include "coverage_apb.sv"
`include "driver_agent_apb.sv"
`include "monitor_apb.sv"

class agent_apb extends uvm_agent;

  `uvm_component_utils(agent_apb)

  driver_agent_apb                driver_agent_apb_inst0;
  monitor_apb                     monitor_apb_inst0;
  uvm_sequencer #(tranzactie_apb) sequencer_agent_apb_inst0;

  uvm_analysis_port #(tranzactie_apb) de_la_monitor_apb;

  function new(string name = "agent_apb", uvm_component parent = null);
    super.new(name, parent);
    de_la_monitor_apb = new("de_la_monitor_apb", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor_apb_inst0 = monitor_apb::type_id::create("monitor_apb_inst0", this);

    // get_is_active() citeste parametrul UVM_ACTIVE/UVM_PASSIVE setat din exterior
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer_agent_apb_inst0 =
        uvm_sequencer#(tranzactie_apb)::type_id::create("sequencer_agent_apb_inst0", this);
      driver_agent_apb_inst0 =
        driver_agent_apb::type_id::create("driver_agent_apb_inst0", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    monitor_apb_inst0.port_date_monitor_apb.connect(de_la_monitor_apb);

    if (get_is_active() == UVM_ACTIVE) begin
      driver_agent_apb_inst0.seq_item_port.connect(
        sequencer_agent_apb_inst0.seq_item_export);
    end
  endfunction

endclass

`endif