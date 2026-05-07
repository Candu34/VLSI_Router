`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_driver
`define __apb_driver

class driver_agent_apb extends uvm_driver #(tranzactie_apb);

  `uvm_component_utils(driver_agent_apb)

  virtual apb_interface_dut interfata_driverului_pentru_apb;

  function new(string name = "driver_agent_apb", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", interfata_driverului_pentru_apb)) begin
      `uvm_fatal("DRIVER_AGENT_APB", "Nu s-a putut accesa interfata_apb")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    initializare_semnale();

    forever begin
      `uvm_info("DRIVER_AGENT_APB", "Se asteapta o tranzactie de la sequencer", UVM_LOW)
      seq_item_port.get_next_item(req);
      `uvm_info("DRIVER_AGENT_APB", "S-a primit o tranzactie de la sequencer", UVM_LOW)

      trimiterea_tranzactiei(req);

      `uvm_info("DRIVER_AGENT_APB", "Tranzactia a fost transmisa pe interfata", UVM_LOW)
      seq_item_port.item_done();
    end
  endtask

  task initializare_semnale();
    interfata_driverului_pentru_apb.driver_cb.psel    <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.penable <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.pwrite    <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.paddr   <= 8'h00;
    interfata_driverului_pentru_apb.driver_cb.pwdata  <= 8'h00;
  endtask

  task trimiterea_tranzactiei(tranzactie_apb informatia_de_transmis);
    $timeformat(-9, 2, " ns", 20);

    // setup phase
    @(interfata_driverului_pentru_apb.driver_cb);
    interfata_driverului_pentru_apb.driver_cb.psel    <= 1'b1;
    interfata_driverului_pentru_apb.driver_cb.penable <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.pwrite    <= informatia_de_transmis.write;
    interfata_driverului_pentru_apb.driver_cb.paddr   <= informatia_de_transmis.addr;
    interfata_driverului_pentru_apb.driver_cb.pwdata  <= informatia_de_transmis.wdata;

    // access phase
    @(interfata_driverului_pentru_apb.driver_cb);
    interfata_driverului_pentru_apb.driver_cb.penable <= 1'b1;

    // asteapta ready
    do begin
      @(interfata_driverului_pentru_apb.driver_cb);
    end while (interfata_driverului_pentru_apb.driver_cb.p_ready !== 1'b1);

    informatia_de_transmis.ready = interfata_driverului_pentru_apb.driver_cb.p_ready;
    informatia_de_transmis.error = interfata_driverului_pentru_apb.driver_cb.p_error;

    if (!informatia_de_transmis.write) begin
      informatia_de_transmis.rdata = interfata_driverului_pentru_apb.driver_cb.prdata;
    end

    `uvm_info("DRIVER_AGENT_APB",
      $sformatf("APB transfer finalizat: write=%0b addr=0x%0h wdata=0x%0h rdata=0x%0h ready=%0b error=%0b",
                informatia_de_transmis.write,
                informatia_de_transmis.addr,
                informatia_de_transmis.wdata,
                informatia_de_transmis.rdata,
                informatia_de_transmis.ready,
                informatia_de_transmis.error),
      UVM_MEDIUM)

    // revenire in idle
    @(interfata_driverului_pentru_apb.driver_cb);
    interfata_driverului_pentru_apb.driver_cb.psel    <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.penable <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.pwrite    <= 1'b0;
    interfata_driverului_pentru_apb.driver_cb.paddr   <= 8'h00;
    interfata_driverului_pentru_apb.driver_cb.pwdata  <= 8'h00;

`ifdef DEBUG
    $display("DRIVER_AGENT_APB, dupa transmisie; [T=%0t]", $realtime);
`endif
  endtask

endclass

`endif