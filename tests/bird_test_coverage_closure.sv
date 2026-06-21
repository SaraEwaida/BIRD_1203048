//==============================================================================
// File   : bird_test_coverage_closure.sv
// Purpose: Run the directed sequence that closes missing functional bins.
//==============================================================================

`ifndef BIRD_TEST_COVERAGE_CLOSURE_SV
`define BIRD_TEST_COVERAGE_CLOSURE_SV

`include "bird_base_test.sv"

class bird_test_coverage_closure extends bird_base_test;

  function new(virtual bird_if vif);
    super.new(vif, 12000);
  endfunction

  task body();
    bird_seq_coverage_closure cov_seq = new(seq2drv);
    cov_seq.run();
  endtask

endclass

`endif
