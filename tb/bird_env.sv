class bird_env;

  // Properties
  virtual bird_if vif;
  int             number_of_transactions;
  int             drain_cycles;            // idle cycles after stimulus drains

  // Component handles
  bird_sequence   seq;
  bird_driver     drv;
  bird_monitor    mon;
  bird_scoreboard sb;

  // Mailboxes
  mailbox #(bird_transaction) seq2drv;
  mailbox #(bird_transaction) mon2sb_in;
  mailbox #(bit [31:0])       mon2sb_cfg;
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  bit built; // Set once build() has run.

  // Constructor
  function new(virtual bird_if vif, int number_of_transactions = 5);
    this.vif                     = vif;
    this.number_of_transactions  = number_of_transactions;
    this.drain_cycles = number_of_transactions * 300;
    this.built                   = 1'b0;
  endfunction

  // build : create mailboxes and all components, then wire them up.
  function void build();
    seq2drv       = new();
    mon2sb_in     = new();
    mon2sb_cfg    = new();
    mon2sb_local  = new();
    mon2sb_remote = new();

    seq = new(seq2drv, number_of_transactions);
    drv = new(vif, seq2drv);
    mon = new(vif, mon2sb_in, mon2sb_cfg, mon2sb_local, mon2sb_remote);
    sb  = new(vif, mon2sb_in, mon2sb_cfg, mon2sb_local, mon2sb_remote);

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

    // Driver/monitor/scoreboard each contain forever loops, so launch them in
    // the background with join_none and never wait on them.
    fork
      drv.run();
      mon.run();
      sb.run();
    join_none

    // Generate stimulus; this returns once all transactions are queued.
    seq.run();

    // Let in-flight packets and outputs settle before checking.
    repeat (drain_cycles) @(vif.cb);

    wrap_up();
  endtask

  // wrap_up : finalize scoreboard checks and report completion.
  task wrap_up();
    sb.wrap_up();
    $display("[bird_env] environment run complete");
  endtask

endclass : bird_env
