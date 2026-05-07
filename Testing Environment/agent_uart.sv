`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_agent
`define __uart_agent

`include "tranzactie_uart.sv"
`include "monitor_uart.sv"

class agent_uart extends uvm_agent;

    `uvm_component_utils(agent_uart)

    monitor_uart monitor_uart_inst0;

    uvm_analysis_port #(tranzactie_uart) de_la_monitor_uart;

    function new(string name = "agent_uart", uvm_component parent = null);
        super.new(name, parent);
        de_la_monitor_uart = new("de_la_monitor_uart", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor_uart_inst0 = monitor_uart::type_id::create("monitor_uart_inst0", this);

    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        monitor_uart_inst0.port_date_monitor_uart.connect(de_la_monitor_uart);

    endfunction

endclass

`endif