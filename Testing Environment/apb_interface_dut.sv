`ifndef __apb_intf
`define __apb_intf
interface apb_interface_dut;

  // Sistem
  logic        pclk;
  logic        rst_n;

  // APB – semnale de la master (input în DUT)
  logic        psel;
  logic        penable;
  logic        pwrite;          // 1 = write, 0 = read
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
    output pwrite;
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
    input pwrite;
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

  // penable trebuie ridicat exact un tact dupa psel
  property apb_setup_to_access;
    @(posedge pclk) disable iff (!rst_n)
    (psel && !penable) |=> penable;
  endproperty
  APB_SETUP_TO_ACCESS: assert property (apb_setup_to_access)
    else `uvm_error("APB_INTF", "penable nu a fost ridicat la un tact dupa psel")

  // psel trebuie sa ramana stabil (HIGH) cat timp penable este HIGH
  property apb_psel_stable_during_access;
    @(posedge pclk) disable iff (!rst_n)
    (psel && penable) |-> psel;
  endproperty
  APB_PSEL_STABLE: assert property (apb_psel_stable_during_access)
    else `uvm_error("APB_INTF", "psel a cazut in timpul fazei ACCESS")

  // paddr, pwdata, pwrite trebuie sa fie stabile in faza ACCESS
  property apb_signals_stable_in_access;
    @(posedge pclk) disable iff (!rst_n)
    (psel && penable) |->
      ($stable(paddr) && $stable(pwrite) && (pwrite ? $stable(pwdata) : 1'b1));
  endproperty
  APB_SIGNALS_STABLE: assert property (apb_signals_stable_in_access)
    else `uvm_error("APB_INTF", "paddr/pwdata/pwrite s-au schimbat in faza ACCESS")

  // p_error nu trebuie sa fie activ fara un transfer in curs
  property apb_error_only_during_transfer;
    @(posedge pclk) disable iff (!rst_n)
    p_error |-> (psel && penable);
  endproperty
  APB_ERROR_VALID: assert property (apb_error_only_during_transfer)
    else `uvm_error("APB_INTF", "p_error activ fara transfer APB in curs")

  // p_error trebuie ridicat la adrese invalide (> 6 = APB_MEMORY_SIZE)
  property apb_error_on_invalid_addr;
    @(posedge pclk) disable iff (!rst_n)
    (psel && !penable && (paddr >= 8'd6)) |=> p_error;
endproperty
  APB_ERROR_INVALID_ADDR: assert property (apb_error_on_invalid_addr)
    else `uvm_error("APB_INTF", "p_error nu a fost ridicat pentru adresa invalida")

      // Scriere in registri read-only (adrese 3, 4, 5, 6) trebuie sa genereze p_error
  property apb_error_on_ro_write;
    @(posedge pclk) disable iff (!rst_n)
    (psel && !penable && pwrite && (paddr >= 8'd3)) |=> p_error;
endproperty
  APB_ERROR_RO_WRITE: assert property (apb_error_on_ro_write)
    else `uvm_error("APB_INTF", "p_error nu a fost ridicat la scriere in registru read-only")

  // prdata nu trebuie sa se schimbe in timpul unui transfer de scriere
  property apb_prdata_stable_on_write;
    @(posedge pclk) disable iff (!rst_n)
    (psel && penable && pwrite) |-> $stable(prdata);
  endproperty
  APB_PRDATA_STABLE_WR: assert property (apb_prdata_stable_on_write)
    else `uvm_error("APB_INTF", "prdata s-a schimbat in timpul unui transfer de scriere")

  // Dupa reset, toate iesirile DUT trebuie sa fie 0
  property apb_outputs_cleared_after_reset;
    @(posedge pclk)
    (!rst_n) |=> (!prdata && !p_error && !p_ready);
  endproperty
  APB_RESET_CLEAR: assert property (apb_outputs_cleared_after_reset)
    else `uvm_error("APB_INTF", "Iesirile APB nu sunt 0 dupa reset")

  // semnalele nu trebuie sa fie X in timpul unui transfer activ
  property apb_no_x_on_paddr;
    @(posedge pclk) disable iff (!rst_n)
    (psel && penable) |-> !$isunknown(paddr);
  endproperty
  APB_NO_X_PADDR: assert property (apb_no_x_on_paddr)
    else `uvm_warning("APB_INTF", "paddr este X in timpul unui transfer activ")

  property apb_no_x_on_prdata;
    @(posedge pclk) disable iff (!rst_n)
    (psel && penable && !pwrite) |=> !$isunknown(prdata);
  endproperty
  APB_NO_X_PRDATA: assert property (apb_no_x_on_prdata)
    else `uvm_warning("APB_INTF", "prdata este X dupa un transfer de citire")

endinterface
`endif