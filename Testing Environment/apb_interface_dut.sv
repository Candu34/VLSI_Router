`ifndef __apb_intf
`define __apb_intf
interface apb_interface_dut;

  // Sistem
  logic        pclk;
  logic        rst_n;

  // APB – semnale de la master (input în DUT)
  logic        psel;
  logic        penable;
  logic        pr_w;          // 1 = write, 0 = read
  logic [7:0]  paddr;
  logic [7:0]  pwdata;

  // APB – semnale de la slave/DUT (output din DUT)
  logic [7:0]  prdata;
  logic        p_error;
  logic        p_ready;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ================================================================
  // CLOCKING BLOCKS
  // ================================================================

  clocking driver_cb @(posedge pclk);
    default input #1step output #1;
    output psel;
    output penable;
    output pr_w;
    output paddr;
    output pwdata;
    input  prdata;
    input  p_error;
    input  p_ready;
  endclocking

  clocking monitor_cb @(posedge pclk);
    default input #1step;
    input psel;
    input penable;
    input pr_w;
    input paddr;
    input pwdata;
    input prdata;
    input p_error;
    input p_ready;
  endclocking

  // ================================================================
  // MODPORT-URI
  // ================================================================

  modport driver_mp  (clocking driver_cb,  input rst_n);
  modport monitor_mp (clocking monitor_cb, input rst_n);

  // ================================================================
  // ASERTII – Protocol APB
  // ================================================================


endinterface
`endif