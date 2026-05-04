`ifndef __uart_intf
`define __uart_intf
interface uart_interface_dut;

  // Sistem
  logic        clk;
  logic        rst_n;

  // Semnale de la controller (input in UART)
  logic        req;
  logic [31:0] data;          // payload: cfg (addr=0), baud (addr=1) sau tx_data (addr=2)
  logic [3:0]  addr;          // 0=cfg, 1=baud, 2=tx_data

  // Semnale de la UART (output din UART)
  logic        tx;            // linie seriala TX
  logic        ack;           // UART a acceptat comanda

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ================================================================
  // CLOCKING BLOCKS
  // ================================================================

  clocking driver_cb @(posedge clk);
    default input #1step output #1;
    output req;
    output data;
    output addr;
    input  tx;
    input  ack;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step;
    input req;
    input data;
    input addr;
    input tx;
    input ack;
  endclocking

  // ================================================================
  // MODPORT-URI
  // ================================================================

  modport driver_mp  (clocking driver_cb,  input rst_n);
  modport monitor_mp (clocking monitor_cb, input rst_n);

  // ================================================================
  // ASERTII – Protocol UART intern (req/ack)
  // ================================================================

endinterface
`endif