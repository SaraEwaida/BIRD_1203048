//==============================================================================
// File   : bird_base_test.sv
// Purpose: Common component construction and execution for directed tests.
//==============================================================================

`ifndef BIRD_BASE_TEST_SV
`define BIRD_BASE_TEST_SV

`include "bird_seq_lib.sv"

class bird_base_test;

  virtual bird_if vif;
  int             drain_cycles;

  mailbox #(bird_transaction) seq2drv;
  mailbox #(bird_transaction) mon2cov_in;
  mailbox #(bit [31:0])       mon2cov_cfg;
  mailbox #(bird_transaction) cov2sb_in;
  mailbox #(bit [31:0])       cov2sb_cfg;
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  bird_driver     drv;
  bird_monitor    mon;
  bird_coverage   cov;
  bird_scoreboard sb;

  function new(virtual bird_if vif, int drain_cycles = 8000);
    this.vif          = vif;
    this.drain_cycles = drain_cycles;
  endfunction

  function void build();
    seq2drv       = new();
    mon2cov_in    = new();
    mon2cov_cfg   = new();
    cov2sb_in     = new();
    cov2sb_cfg    = new();
    mon2sb_local  = new();
    mon2sb_remote = new();

    drv = new(vif, seq2drv, 1);
    mon = new(vif, mon2cov_in, mon2cov_cfg, mon2sb_local, mon2sb_remote);
    cov = new(mon2cov_in, mon2cov_cfg, cov2sb_in, cov2sb_cfg, vif);
    sb  = new(vif, cov2sb_in, cov2sb_cfg, mon2sb_local, mon2sb_remote);
  endfunction

  task launch_components();
    fork
      drv.run();
      mon.run();
      cov.run();
      sb.run();
    join_none
  endtask

  virtual task body();
  endtask

  task finish();
    repeat (drain_cycles) @(vif.cb);
    sb.wrap_up();
    cov.report();
  endtask

  task run();
    build();
    wait (vif.rst_n == 1'b1);
    @(vif.cb);
    launch_components();
    body();
    finish();
    $display("[bird_base_test] test complete");
  endtask

endclass : bird_base_test

`endif
