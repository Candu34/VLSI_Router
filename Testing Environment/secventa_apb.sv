`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __uart_sequences
`define __uart_sequences


// Secventa 1: Configureaza baud rate apoi trimite un pachet
class secventa_uart_config_si_send extends uvm_sequence #(tranzactie_apb);

    `uvm_object_utils(secventa_uart_config_si_send)

    rand bit [7:0]  baud_div;       // cate ceasuri per bit
    rand bit [31:0] pachet_de_trimis;
    rand bit [1:0]  dest_port;      // catre ce port (0-3)

    constraint c_baud_valid {
        baud_div > 8'h00;
        baud_div inside {[8'h01 : 8'hFF]};
    }

    constraint c_dest_valid {
        dest_port inside {[2'b00 : 2'b11]};
    }

    // pachetul trebuie sa aiba destinatia corecta in [31:28]
    constraint c_pachet_dest {
        pachet_de_trimis[31:28] == dest_port;
    }

    function new(string name = "secventa_uart_config_si_send");
        super.new(name);
    endfunction

    virtual task body();

        `uvm_info("SECVENTA_UART",
            $sformatf("Incepe: config baud=0x%0h apoi trimite pachet=0x%0h catre port=%0d",
                      baud_div, pachet_de_trimis, dest_port),
            UVM_NONE)


// Scrie baud rate in registrul 0x01
        req = tranzactie_apb::type_id::create("req_baud");
        start_item(req);
        assert(req.randomize() with {
            write == 1'b1;
            addr  == 8'h01;
            wdata == baud_div;
        });
        finish_item(req);

        `uvm_info("SECVENTA_UART",
            $sformatf("Baud configurat: 0x%0h", baud_div),
            UVM_LOW)


        // Scrie pachetul in registrul 0x02 (TX register)
        req = tranzactie_apb::type_id::create("req_tx");
        start_item(req);
        assert(req.randomize() with {
            write == 1'b1;
            addr  == 8'h02;
            wdata == pachet_de_trimis[7:0]; 
        });
        finish_item(req);

        `uvm_info("SECVENTA_UART",
            $sformatf("Pachet trimis: 0x%0h catre port %0d",
                      pachet_de_trimis, dest_port),
            UVM_LOW)

    endtask

endclass



// Secventa 2: Trimite pe toate cele 4 porturi
class secventa_uart_toate_porturile extends uvm_sequence #(tranzactie_apb);

    `uvm_object_utils(secventa_uart_toate_porturile)

    function new(string name = "secventa_uart_toate_porturile");
        super.new(name);
    endfunction

    virtual task body();
        secventa_uart_config_si_send seq_port;

        `uvm_info("SECVENTA_UART_ALL",
            "Incepe testul pe toate cele 4 porturi UART",
            UVM_NONE)

        for (int port = 0; port < 4; port++) begin

            seq_port = secventa_uart_config_si_send::type_id::create(
                           $sformatf("seq_port_%0d", port));

            assert(seq_port.randomize() with {
                dest_port == port;      
                baud_div  == 8'h06;     
            });

            seq_port.start(m_sequencer);

            `uvm_info("SECVENTA_UART_ALL",
                $sformatf("Port %0d testat cu pachetul 0x%0h",
                          port, seq_port.pachet_de_trimis),
                UVM_LOW)
        end

    endtask

endclass


// Testeaza mai multe baud rate-uri pe acelasi port
class secventa_uart_multi_baud extends uvm_sequence #(tranzactie_apb);

    `uvm_object_utils(secventa_uart_multi_baud)

    function new(string name = "secventa_uart_multi_baud");
        super.new(name);
    endfunction

    virtual task body();
        secventa_uart_config_si_send seq_baud;

        // valorile de baud rate de testat
        bit [7:0] baud_values [] = '{8'h01, 8'h06, 8'h0A, 8'h1F};

        `uvm_info("SECVENTA_UART_BAUD",
            "Incepe testul cu mai multe baud rate-uri",
            UVM_NONE)

        foreach (baud_values[i]) begin

            seq_baud = secventa_uart_config_si_send::type_id::create(
                           $sformatf("seq_baud_0x%0h", baud_values[i]));

            assert(seq_baud.randomize() with {
                baud_div  == baud_values[i];
                dest_port == 2'd0;
            });

            seq_baud.start(m_sequencer);

            `uvm_info("SECVENTA_UART_BAUD",
                $sformatf("Testat baud=0x%0h pachet=0x%0h",
                          baud_values[i], seq_baud.pachet_de_trimis),
                UVM_LOW)
        end

    endtask

endclass



// Secventa 4: Trimite pachet cu destinatie invalida (>3)
class secventa_uart_dest_invalida extends uvm_sequence #(tranzactie_apb);

    `uvm_object_utils(secventa_uart_dest_invalida)

    function new(string name = "secventa_uart_dest_invalida");
        super.new(name);
    endfunction

    virtual task body();

        `uvm_info("SECVENTA_UART_INVALID",
            "Testeaza pachet cu destinatie invalida",
            UVM_NONE)

        // Trimite pachet cu dest=5 (invalid, > 3)
        req = tranzactie_apb::type_id::create("req_invalid");
        start_item(req);
        assert(req.randomize() with {
            write == 1'b1;
            addr  == 8'h02;
            wdata[7:4] == 4'd5;   
        });
        finish_item(req);

        // Citeste registrul de pachete sarite (memory[4])
        req = tranzactie_apb::type_id::create("req_read_skip");
        start_item(req);
        assert(req.randomize() with {
            write == 1'b0;
            addr  == 8'h04;   // packet skipped counter
        });
        finish_item(req);

        `uvm_info("SECVENTA_UART_INVALID",
            "Pachet invalid trimis — verificati contorul de pachete sarite",
            UVM_LOW)

    endtask

endclass

`endif