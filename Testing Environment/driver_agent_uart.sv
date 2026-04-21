`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_driver
`define __uart_driver

class driver_agent_uart extends uvm_driver #(tranzactie_uart);

  `uvm_component_utils(driver_agent_uart)

  virtual uart_interface_dut interfata_driverului_pentru_uart;

  function new(string name = "driver_agent_uart", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual uart_interface_dut)::get(this, "", "uart_interface_dut", interfata_driverului_pentru_uart)) begin
      `uvm_fatal("DRIVER_AGENT_UART", "Nu s-a putut accesa interfata_uart")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    initializare_semnale();

    forever begin
      `uvm_info("DRIVER_AGENT_UART", "Se asteapta o tranzactie de la sequencer", UVM_LOW)
      seq_item_port.get_next_item(req);
      `uvm_info("DRIVER_AGENT_UART", "S-a primit o tranzactie de la sequencer", UVM_LOW)

      trimiterea_tranzactiei(req);

      `uvm_info("DRIVER_AGENT_UART", "Tranzactia a fost transmisa pe interfata UART", UVM_LOW)
      seq_item_port.item_done();
    end
  endtask

  task initializare_semnale();
    interfata_driverului_pentru_uart.driver_cb.req  <= 1'b0;
    interfata_driverului_pentru_uart.driver_cb.addr <= 4'h0;
    interfata_driverului_pentru_uart.driver_cb.data <= 32'h0000_0000;
  endtask

  task trimiterea_tranzactiei(tranzactie_uart informatia_de_transmis);
    $timeformat(-9, 2, " ns", 20);

    @(interfata_driverului_pentru_uart.driver_cb);
    interfata_driverului_pentru_uart.driver_cb.req  <= 1'b1;
    interfata_driverului_pentru_uart.driver_cb.addr <= informatia_de_transmis.addr;
    interfata_driverului_pentru_uart.driver_cb.data <= informatia_de_transmis.data;

    do begin
      @(interfata_driverului_pentru_uart.driver_cb);
    end while (interfata_driverului_pentru_uart.driver_cb.ack !== 1'b1);

    informatia_de_transmis.ack_observed = 1'b1;

    `uvm_info("DRIVER_AGENT_UART",
      $sformatf("UART transfer finalizat: addr=0x%0h data=0x%0h ack=%0b",
                informatia_de_transmis.addr,
                informatia_de_transmis.data,
                informatia_de_transmis.ack_observed),
      UVM_MEDIUM)

    @(interfata_driverului_pentru_uart.driver_cb);
    interfata_driverului_pentru_uart.driver_cb.req  <= 1'b0;
    interfata_driverului_pentru_uart.driver_cb.addr <= 4'h0;
    interfata_driverului_pentru_uart.driver_cb.data <= 32'h0000_0000;

`ifdef DEBUG
    $display("DRIVER_AGENT_UART, dupa transmisie; [T=%0t]", $realtime);
`endif
  endtask

endclass

`endif