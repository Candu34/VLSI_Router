`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_monitor
`define __uart_monitor

class monitor_uart extends uvm_monitor;

    `uvm_component_utils(monitor_uart)

    uvm_analysis_port #(tranzactie_uart) port_date_monitor_uart;

    virtual uart_interface_dut interfata_monitor_uart;

    tranzactie_uart starea_preluata_uart;
    tranzactie_uart aux_tr_uart;

    int unsigned port_index;

    // ← inlocuieste cfg.* cu aceste variabile locale
    // valorile de reset din DUT
    int unsigned baud_div  = 6;     // memory[1] default = 8'h06
    int unsigned numar_biti = 32;   // cfg default = 2'b10 → 32 biti
    bit          bit_dir   = 1'b0;  // LSB first implicit

    function new(string name = "monitor_uart", uvm_component parent = null);
        super.new(name, parent);
        port_index = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        port_date_monitor_uart = new("port_date_monitor_uart", this);

        starea_preluata_uart = tranzactie_uart::type_id::create("starea_preluata_uart");
        aux_tr_uart          = tranzactie_uart::type_id::create("aux_tr_uart");

        // preluam port_index din config_db — setat de env
        void'(uvm_config_db #(int)::get(this, "", "port_index", port_index));

        if (!uvm_config_db #(virtual uart_interface_dut)::get(
                this, "", "uart_interface_dut", interfata_monitor_uart)) begin
            `uvm_fatal("MONITOR_UART", "Nu s-a putut accesa interfata monitorului UART")
        end

    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin

            // Pasul 1: asteapta START bit (tx cade din 1 in 0)
            @(interfata_monitor_uart.monitor_cb);

            if (interfata_monitor_uart.rst_n &&
                !interfata_monitor_uart.monitor_cb.tx) begin

                // Pasul 2: pozitionare la mijlocul primului bit de date
                repeat(baud_div / 2) @(interfata_monitor_uart.monitor_cb);

                // Pasul 3: colectam toti bitii de date
                starea_preluata_uart.date_receptionate = 32'h0;
                starea_preluata_uart.numar_biti        = numar_biti;
                starea_preluata_uart.port_sursa        = port_index[1:0];

                for (int i = 0; i < numar_biti; i++) begin

                    repeat(baud_div) @(interfata_monitor_uart.monitor_cb);

                    if (bit_dir == 1'b0)
                        starea_preluata_uart.date_receptionate[i] =
                            interfata_monitor_uart.monitor_cb.tx;
                    else
                        starea_preluata_uart.date_receptionate[numar_biti-1-i] =
                            interfata_monitor_uart.monitor_cb.tx;
                end

                // Pasul 4: verificam STOP bit
                repeat(baud_div) @(interfata_monitor_uart.monitor_cb);

                if (!interfata_monitor_uart.monitor_cb.tx)
                    `uvm_error("MONITOR_UART", "Stop bit invalid — tx nu este 1")

                // Pasul 5: trimitem tranzactia
                aux_tr_uart = starea_preluata_uart.copy();
                port_date_monitor_uart.write(aux_tr_uart);

                `uvm_info("MONITOR_UART",
                    $sformatf("Tranzactie UART capturata: port=%0d date=0x%0h biti=%0d",
                              aux_tr_uart.port_sursa,
                              aux_tr_uart.date_receptionate,
                              aux_tr_uart.numar_biti),
                    UVM_MEDIUM)

                aux_tr_uart.afiseaza_informatia_tranzactiei();

                // Pasul 6: asteapta IDLE
                wait(interfata_monitor_uart.monitor_cb.tx);

            end
        end
    endtask

endclass

`endif