//==============================================================================
// File   : bird_env.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Purpose: Environment. Builds and wires the sequence, driver, monitor,
//          functional coverage, and scoreboard; runs stimulus; drains; reports.
//
// INTEGRATION NOTE: functional coverage (bird_coverage) is interposed on the
// monitor -> scoreboard INPUT path. The bird_monitor and bird_scoreboard
// source files are UNCHANGED; only the mailbox handles wired here differ.
// Coverage samples each observed input packet and then forwards it unchanged,
// so the scoreboard sees exactly the same stream and order as before.
// The teammate's drain_cycles setting (number_of_transactions * 300) is kept.
//==============================================================================

`include "bird_coverage.sv"

class bird_env;

  // Properties
  virtual bird_if vif;
  int             number_of_transactions;
  int             drain_cycles;            // idle cycles after stimulus drains

  // Component handles
  bird_sequence   seq;
  bird_driver     drv;
  bird_monitor    mon;
  bird_coverage   cov;
  bird_scoreboard sb;

  // Mailboxes
  mailbox #(bird_transaction) seq2drv;
  // monitor -> coverage  (input packet + raw cfg)
  mailbox #(bird_transaction) mon2cov_in;
  mailbox #(bit [31:0])       mon2cov_cfg;
  // coverage -> scoreboard (same stream, forwarded unchanged)
  mailbox #(bird_transaction) cov2sb_in;
  mailbox #(bit [31:0])       cov2sb_cfg;
  // monitor -> scoreboard (output streams, unchanged)
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  bit built; // Set once build() has run.

  // Constructor
  function new(virtual bird_if vif, int number_of_transactions = 5);
    this.vif                     = vif;
    this.number_of_transactions  = number_of_transactions;
    this.drain_cycles            = number_of_transactions * 300;
    this.built                   = 1'b0;
  endfunction

  // build : create mailboxes and all components, then wire them up.
  function void build();
    seq2drv       = new();
    mon2cov_in    = new();
    mon2cov_cfg   = new();
    cov2sb_in     = new();
    cov2sb_cfg    = new();
    mon2sb_local  = new();
    mon2sb_remote = new();

    seq = new(seq2drv, number_of_transactions);
    drv = new(vif, seq2drv);
    // Monitor writes the observed input stream into the coverage mailboxes.
    mon = new(vif, mon2cov_in, mon2cov_cfg, mon2sb_local, mon2sb_remote);
    // Coverage samples each input, then forwards it to the scoreboard mailboxes.
    cov = new(mon2cov_in, mon2cov_cfg, cov2sb_in, cov2sb_cfg);
    // Scoreboard reads the forwarded input stream + the (unchanged) outputs.
    sb  = new(vif, cov2sb_in, cov2sb_cfg, mon2sb_local, mon2sb_remote);

    built = 1'b1;
    $display("[bird_env] build complete: %0d transactions, drain=%0d cycles",
             number_of_transactions, drain_cycles);
  endfunction

  // run : start background components, run the sequence, drain, then wrap up.
  task run();
    if (!built) build();

    // Wait for reset deassertion before any activity.
    wait (vif.rst_n == 1'b1);
    @(vif.cb);

    // Driver/monitor/coverage/scoreboard each contain forever loops, so launch
    // them in the background with join_none and never wait on them.
    fork
      drv.run();
      mon.run();
      cov.run();
      sb.run();
    join_none

    // Generate stimulus; this returns once all transactions are queued.
    seq.run();

    // Let in-flight packets and outputs settle before checking.
    repeat (drain_cycles) @(vif.cb);

    wrap_up();
  endtask

  // wrap_up : finalize scoreboard checks, print functional coverage, finish.
  task wrap_up();
    sb.wrap_up();
    cov.report();
    $display("[bird_env] environment run complete");
  endtask

endclass : bird_env
