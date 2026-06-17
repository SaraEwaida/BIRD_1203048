//==============================================================================
// File   : bird_test.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 1 (Integration)
// Purpose: Top-level test. Constructs the environment, chooses how many
//          transactions to generate, runs it, and reports completion.
//
// Style follows the class slides (Tumbush/Spear): a simple class-based test
// (no UVM) that owns the environment and calls build()/run(). The environment
// already runs the sequence, drains, and calls the scoreboard's end-of-test
// report in wrap_up().
//
// How to add more tests later (kept simple, slide-style):
//   - Create derived/variant tests by changing num_transactions, or by adding
//     a sequence that disables a constraint (constraint_mode(0)) to inject
//     illegal packets the DUT must drop. Each named test then maps to a row
//     in test_plan/test_plan.md.
//==============================================================================

class bird_test;

  virtual bird_if vif;
  bird_env        env;
  int             num_transactions;

  // Constructor : take the interface handle and the number of transactions.
  function new(virtual bird_if vif, int num_transactions = 10);
    this.vif              = vif;
    this.num_transactions = num_transactions;
  endfunction

  // run : build the environment and run it to completion.
  task run();
    $display("[bird_test] START - BIRD random traffic test (%0d transactions)",
             num_transactions);

    env = new(vif, num_transactions);
    env.build();   // create mailboxes + components and wire them
    env.run();     // waits for reset, runs sequence, drains, wrap_up() report

    $display("[bird_test] DONE - see end-of-test report above");
  endtask

endclass : bird_test
