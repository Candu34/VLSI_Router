`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __verification_environment
`define __verification_environment

typedef class scoreboard;

`include "agent_apb.sv"
`include "scoreboard.sv"

class mediu_verificare extends uvm_env;

  `uvm_component_utils(mediu_verificare)

  // interfata APB
  virtual apb_interface_dut interfata_monitor_apb;

  // componente
  agent_apb  agent_apb_din_mediu;
  scoreboard IO_scorboard;

  function new(string name = "mediu_verificare", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent_apb_din_mediu = agent_apb::type_id::create("agent_apb_din_mediu", this);
    IO_scorboard        = scoreboard::type_id::create("IO_scorboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    `uvm_info("MEDIU_DE_VERIFICARE",
      "A inceput faza de realizare a conexiunilor",
      UVM_NONE)

    assert(uvm_resource_db#(virtual apb_interface_dut)::read_by_name(
      get_full_name(), "apb_interface_dut", interfata_monitor_apb))
    else
      `uvm_error("MEDIU_DE_VERIFICARE",
        "Nu s-a putut prelua din baza de date UVM apb_interface_dut");

    // conectare agent -> scoreboard
    agent_apb_din_mediu.de_la_monitor_apb.connect(IO_scorboard.port_pentru_datele_de_la_apb);

    `uvm_info("MEDIU_DE_VERIFICARE",
      "Faza de realizare a conexiunilor s-a terminat",
      UVM_HIGH)
  endfunction : connect_phase

  task run_phase(uvm_phase phase);
    `uvm_info("MEDIU_DE_VERIFICARE",
      "Faza de rulare a activitatii mediului de verificare (RUN PHASE) a inceput.",
      UVM_NONE)
  endtask

endclass

`endif