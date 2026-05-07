`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __verification_environment
`define __verification_environment

typedef class scoreboard;

`include "agent_apb.sv"     
`include "agent_uart.sv"        
`include "scoreboard.sv"

class mediu_verificare extends uvm_env;

    `uvm_component_utils(mediu_verificare)

    virtual apb_interface_dut interfata_monitor_apb;

    agent_apb  agent_apb_din_mediu;
    scoreboard IO_scorboard;

    agent_uart agent_uart_0;
    agent_uart agent_uart_1;
    agent_uart agent_uart_2;
    agent_uart agent_uart_3;


    function new(string name = "mediu_verificare", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent_apb_din_mediu = agent_apb::type_id::create("agent_apb_din_mediu", this);
        IO_scorboard        = scoreboard::type_id::create("IO_scorboard", this);

        agent_uart_0 = agent_uart::type_id::create("agent_uart_0", this);
        agent_uart_1 = agent_uart::type_id::create("agent_uart_1", this);
        agent_uart_2 = agent_uart::type_id::create("agent_uart_2", this);
        agent_uart_3 = agent_uart::type_id::create("agent_uart_3", this);

        uvm_config_db #(int)::set(this, "agent_uart_0.*", "port_index", 0);
        uvm_config_db #(int)::set(this, "agent_uart_1.*", "port_index", 1);
        uvm_config_db #(int)::set(this, "agent_uart_2.*", "port_index", 2);
        uvm_config_db #(int)::set(this, "agent_uart_3.*", "port_index", 3);

    endfunction

    function void connect_phase(uvm_phase phase);
        `uvm_info("MEDIU_DE_VERIFICARE",
            "A inceput faza de realizare a conexiunilor",
            UVM_NONE)
        assert(uvm_resource_db #(virtual apb_interface_dut)::read_by_name(
            get_full_name(), "apb_interface_dut", interfata_monitor_apb))
        else
            `uvm_error("MEDIU_DE_VERIFICARE",
                "Nu s-a putut prelua din baza de date UVM apb_interface_dut")


        agent_apb_din_mediu.de_la_monitor_apb.connect(
            IO_scorboard.port_pentru_datele_de_la_apb);
        agent_uart_0.de_la_monitor_uart.connect(
            IO_scorboard.port_pentru_datele_de_la_uart);
        agent_uart_1.de_la_monitor_uart.connect(
            IO_scorboard.port_pentru_datele_de_la_uart);
        agent_uart_2.de_la_monitor_uart.connect(
            IO_scorboard.port_pentru_datele_de_la_uart);
        agent_uart_3.de_la_monitor_uart.connect(
            IO_scorboard.port_pentru_datele_de_la_uart);

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