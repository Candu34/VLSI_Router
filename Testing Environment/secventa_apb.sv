`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __input_apb_sequence
`define __input_apb_sequence

class secventa_apb extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb)

  rand int numarul_de_tranzactii;

  constraint marimea_sirului_c {
    soft numarul_de_tranzactii inside {[10:15]};
  }

  function new(string name = "secventa_apb");
    super.new(name);
  endfunction

  function void post_randomize();
    $display("SECVENTA_APB: Marimea sirului de tranzactii = %0d", numarul_de_tranzactii);
  endfunction

  virtual task body();

    `uvm_info("SECVENTA_APB",
      $sformatf("A inceput secventa cu dimensiunea de %0d elemente", numarul_de_tranzactii),
      UVM_NONE)

    for (int i = 0; i < numarul_de_tranzactii; i++) begin

      req = tranzactie_apb::type_id::create($sformatf("req_%0d", i));

      start_item(req);

      assert(req.randomize() with {
        addr inside {[8'h00:8'h07]};   // includem si adrese invalide pentru test
        write inside {0,1};

        // daca e write, date random
        if (write == 1)
          wdata inside {[8'h00:8'hFF]};
      });

      `ifdef DEBUG
        `uvm_info("SECVENTA_APB",
          $sformatf("La timpul %0t s-a generat elementul %0d cu informatiile:", $time, i),
          UVM_LOW)
        req.afiseaza_informatia_tranzactiei();
      `endif

      finish_item(req);
    end

    `uvm_info("SECVENTA_APB",
      $sformatf("S-au generat toate cele %0d tranzactii", numarul_de_tranzactii),
      UVM_LOW)

  endtask

endclass

`endif