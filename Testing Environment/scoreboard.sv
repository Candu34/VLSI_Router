`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __scoreboard
`define __scoreboard

`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_uart)

class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)

  uvm_analysis_imp_apb  #(tranzactie_apb,  scoreboard) port_pentru_datele_de_la_apb;
  uvm_analysis_imp_uart #(tranzactie_uart, scoreboard) port_pentru_datele_de_la_uart;

  tranzactie_apb tranzactie_venita_de_la_apb;

  bit [31:0] model_mem [0:5];   // 32-bit — se potriveste cu DUT

  int numar_total_tranzactii;
  int numar_tranzactii_corecte;
  int numar_tranzactii_cu_eroare_detectata;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    numar_total_tranzactii             = 0;
    numar_tranzactii_corecte           = 0;
    numar_tranzactii_cu_eroare_detectata = 0;
  endfunction

  // ← O SINGURA build_phase — cele doua au fost unite
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    port_pentru_datele_de_la_apb  = new("port_pentru_datele_de_la_apb",  this);
    port_pentru_datele_de_la_uart = new("port_pentru_datele_de_la_uart", this);

    tranzactie_venita_de_la_apb = tranzactie_apb::type_id::create("tranzactie_venita_de_la_apb");

    foreach (model_mem[i]) model_mem[i] = 32'h0;

  endfunction

  function void write_apb(input tranzactie_apb tranzactie_noua_apb);
    bit          expected_error;
    bit [31:0]   expected_rdata;   // ← 32-bit, nu 8-bit

    `uvm_info("SCOREBOARD",
      "S-a primit de la agentul APB o tranzactie cu informatia:",
      UVM_LOW)
    tranzactie_noua_apb.afiseaza_informatia_tranzactiei();

    tranzactie_venita_de_la_apb = tranzactie_noua_apb.copy();
    numar_total_tranzactii++;
    expected_error = 1'b0;
    expected_rdata = 32'h0;

    if (tranzactie_noua_apb.addr >= 8'h06)
      expected_error = 1'b1;
    else if ((tranzactie_noua_apb.write == 1'b1) && (tranzactie_noua_apb.addr >= 8'h03))
      expected_error = 1'b1;
    else
      expected_error = 1'b0;

    if (tranzactie_noua_apb.error !== expected_error) begin
      `uvm_error("SCOREBOARD_APB_ERROR",
        $sformatf("Mismatch p_error. addr=0x%0h write=%0b expected=%0b observed=%0b",
                  tranzactie_noua_apb.addr, tranzactie_noua_apb.write,
                  expected_error, tranzactie_noua_apb.error))
      numar_tranzactii_cu_eroare_detectata++;
    end else begin
      `uvm_info("SCOREBOARD_APB_ERROR",
        $sformatf("p_error corect pentru addr=0x%0h write=%0b -> %0b",
                  tranzactie_noua_apb.addr, tranzactie_noua_apb.write,
                  tranzactie_noua_apb.error), UVM_LOW)
    end

    if (tranzactie_noua_apb.ready !== 1'b1)
      `uvm_info("SCOREBOARD_APB_READY",
        $sformatf("Observatie: ready=%0b pentru addr=0x%0h",
                  tranzactie_noua_apb.ready, tranzactie_noua_apb.addr), UVM_MEDIUM)

    if ((tranzactie_noua_apb.write == 1'b1) &&
        (tranzactie_noua_apb.addr inside {8'h00, 8'h01, 8'h02}) &&
        (tranzactie_noua_apb.error == 1'b0)) begin
      model_mem[tranzactie_noua_apb.addr] = tranzactie_noua_apb.wdata;
      `uvm_info("SCOREBOARD_APB_MODEL",
        $sformatf("Model actualizat: model_mem[0x%0h] = 0x%0h",
                  tranzactie_noua_apb.addr, tranzactie_noua_apb.wdata), UVM_LOW)
    end

    if ((tranzactie_noua_apb.write == 1'b0) &&
        (tranzactie_noua_apb.addr <= 8'h05) &&
        (tranzactie_noua_apb.error == 1'b0)) begin
      expected_rdata = model_mem[tranzactie_noua_apb.addr];
      if (tranzactie_noua_apb.rdata !== expected_rdata) begin
        `uvm_error("SCOREBOARD_APB_RDATA",
          $sformatf("Mismatch read. addr=0x%0h expected=0x%0h observed=0x%0h",
                    tranzactie_noua_apb.addr, expected_rdata, tranzactie_noua_apb.rdata))
        numar_tranzactii_cu_eroare_detectata++;
      end else
        `uvm_info("SCOREBOARD_APB_RDATA",
          $sformatf("Read corect. addr=0x%0h rdata=0x%0h",
                    tranzactie_noua_apb.addr, tranzactie_noua_apb.rdata), UVM_LOW)
    end

    if ((tranzactie_noua_apb.error === expected_error) &&
        !((tranzactie_noua_apb.write == 1'b0) &&
          (tranzactie_noua_apb.addr <= 8'h05) &&
          (tranzactie_noua_apb.error == 1'b0) &&
          (tranzactie_noua_apb.rdata !== model_mem[tranzactie_noua_apb.addr])))
      numar_tranzactii_corecte++;

  endfunction : write_apb

  function void write_uart(input tranzactie_uart tranzactie_noua_uart);

    `uvm_info("SCOREBOARD",
      $sformatf("Tranzactie UART primita: port=%0d date=0x%0h",
                tranzactie_noua_uart.port_sursa,
                tranzactie_noua_uart.date_receptionate), UVM_LOW)

    if (model_mem[2] != 0) begin
      if (tranzactie_noua_uart.date_receptionate !== model_mem[2]) begin
        `uvm_error("SCOREBOARD_UART",
          $sformatf("Mismatch UART: port=%0d asteptat=0x%0h primit=0x%0h",
                    tranzactie_noua_uart.port_sursa,
                    model_mem[2],
                    tranzactie_noua_uart.date_receptionate))
        numar_tranzactii_cu_eroare_detectata++;
      end else begin
        `uvm_info("SCOREBOARD_UART",
          $sformatf("UART corect: port=%0d date=0x%0h",
                    tranzactie_noua_uart.port_sursa,
                    tranzactie_noua_uart.date_receptionate), UVM_LOW)
        numar_tranzactii_corecte++;
      end
    end

  endfunction : write_uart

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCOREBOARD_REPORT",
      $sformatf("Rezumat: total=%0d corecte=%0d erori=%0d",
                numar_total_tranzactii,
                numar_tranzactii_corecte,
                numar_tranzactii_cu_eroare_detectata), UVM_NONE)
  endfunction

endclass

`endif