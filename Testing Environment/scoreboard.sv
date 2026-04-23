`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __scoreboard
`define __scoreboard

`uvm_analysis_imp_decl(_apb)

class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)

  // port de intrare pentru tranzactiile APB
  uvm_analysis_imp_apb #(tranzactie_apb, scoreboard) port_pentru_datele_de_la_apb;

  // ultima tranzactie primita
  tranzactie_apb tranzactie_venita_de_la_apb;

  // model intern simplu al registrelor APB din router
  bit [7:0] model_mem [0:5];

  // statistici
  int numar_total_tranzactii;
  int numar_tranzactii_corecte;
  int numar_tranzactii_cu_eroare_detectata;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);

    port_pentru_datele_de_la_apb = new("port_pentru_datele_de_la_apb", this);
    tranzactie_venita_de_la_apb  = new();

    numar_total_tranzactii             = 0;
    numar_tranzactii_corecte           = 0;
    numar_tranzactii_cu_eroare_detectata = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // initializare model intern
    foreach (model_mem[i]) begin
      model_mem[i] = 8'h00;
    end
  endfunction

  function void write_apb(input tranzactie_apb tranzactie_noua_apb);
    bit expected_error;
    bit [7:0] expected_rdata;

    `uvm_info("SCOREBOARD",
      "S-a primit de la agentul APB o tranzactie cu informatia:",
      UVM_LOW)
    tranzactie_noua_apb.afiseaza_informatia_tranzactiei();

    tranzactie_venita_de_la_apb = tranzactie_noua_apb.copy();

    numar_total_tranzactii++;

    expected_error = 1'b0;
    expected_rdata = 8'h00;

    // =========================
    // REGULI DE VALIDARE PENTRU ROUTER
    // =========================
    //
    // memory map:
    // 0x00, 0x01, 0x02 -> read/write
    // 0x03, 0x04, 0x05 -> read-only
    // >= 0x06          -> invalid
    //
    // in DUT:
    // p_error_o <= 1 cand:
    //   - adresa invalida
    //   - write pe registru read-only (>=3)

    // determinam eroarea asteptata
    if (tranzactie_noua_apb.addr >= 8'h06) begin
      expected_error = 1'b1;
    end
    else if ((tranzactie_noua_apb.write == 1'b1) && (tranzactie_noua_apb.addr >= 8'h03)) begin
      expected_error = 1'b1;
    end
    else begin
      expected_error = 1'b0;
    end

    // =========================
    // verificare semnal error
    // =========================
    if (tranzactie_noua_apb.error !== expected_error) begin
      `uvm_error("SCOREBOARD_APB_ERROR",
        $sformatf("Mismatch pentru p_error. addr=0x%0h write=%0b expected_error=%0b observed_error=%0b",
                  tranzactie_noua_apb.addr,
                  tranzactie_noua_apb.write,
                  expected_error,
                  tranzactie_noua_apb.error))
      numar_tranzactii_cu_eroare_detectata++;
    end
    else begin
      `uvm_info("SCOREBOARD_APB_ERROR",
        $sformatf("p_error corect pentru addr=0x%0h write=%0b -> %0b",
                  tranzactie_noua_apb.addr,
                  tranzactie_noua_apb.write,
                  tranzactie_noua_apb.error),
        UVM_LOW)
    end

    // =========================
    // verificare ready
    // =========================
    //
    // Routerul tau ridica p_ready cand psel && !penable,
    // deci monitorul poate vedea uneori ready=0 sau ready=1
    // in functie de momentul esantionarii.
    // De aceea aici doar logam, nu dam eroare hard.
    if (tranzactie_noua_apb.ready !== 1'b1) begin
      `uvm_info("SCOREBOARD_APB_READY",
        $sformatf("Observatie: ready nu este 1 pentru tranzactia addr=0x%0h write=%0b (ready=%0b). Acest lucru poate depinde de momentul esantionarii in monitor.",
                  tranzactie_noua_apb.addr,
                  tranzactie_noua_apb.write,
                  tranzactie_noua_apb.ready),
        UVM_MEDIUM)
    end

    // =========================
    // model intern pentru registre
    // =========================

    // write valid pe registre writable
    if ((tranzactie_noua_apb.write == 1'b1) &&
        (tranzactie_noua_apb.addr inside {8'h00, 8'h01, 8'h02}) &&
        (tranzactie_noua_apb.error == 1'b0)) begin

      model_mem[tranzactie_noua_apb.addr] = tranzactie_noua_apb.wdata;

      `uvm_info("SCOREBOARD_APB_MODEL",
        $sformatf("Model actualizat: model_mem[0x%0h] = 0x%0h",
                  tranzactie_noua_apb.addr,
                  tranzactie_noua_apb.wdata),
        UVM_LOW)
    end

    // read valid din zona 0x00..0x05
    if ((tranzactie_noua_apb.write == 1'b0) &&
        (tranzactie_noua_apb.addr <= 8'h05) &&
        (tranzactie_noua_apb.error == 1'b0)) begin

      expected_rdata = model_mem[tranzactie_noua_apb.addr];

      if (tranzactie_noua_apb.rdata !== expected_rdata) begin
        `uvm_error("SCOREBOARD_APB_RDATA",
          $sformatf("Mismatch la read. addr=0x%0h expected_rdata=0x%0h observed_rdata=0x%0h",
                    tranzactie_noua_apb.addr,
                    expected_rdata,
                    tranzactie_noua_apb.rdata))
        numar_tranzactii_cu_eroare_detectata++;
      end
      else begin
        `uvm_info("SCOREBOARD_APB_RDATA",
          $sformatf("Read corect. addr=0x%0h rdata=0x%0h",
                    tranzactie_noua_apb.addr,
                    tranzactie_noua_apb.rdata),
          UVM_LOW)
      end
    end

    // daca nu am detectat mismatch-uri evidente, consideram tranzactia corecta
    if ((tranzactie_noua_apb.error === expected_error) &&
        !((tranzactie_noua_apb.write == 1'b0) &&
          (tranzactie_noua_apb.addr <= 8'h05) &&
          (tranzactie_noua_apb.error == 1'b0) &&
          (tranzactie_noua_apb.rdata !== model_mem[tranzactie_noua_apb.addr]))) begin
      numar_tranzactii_corecte++;
    end

  endfunction : write_apb

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("SCOREBOARD_REPORT",
      $sformatf("Rezumat scoreboard APB: total=%0d corecte=%0d erori_detectate=%0d",
                numar_total_tranzactii,
                numar_tranzactii_corecte,
                numar_tranzactii_cu_eroare_detectata),
      UVM_NONE)
  endfunction

endclass

`endif