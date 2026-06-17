//==============================================================================
// File   : bird_test_remote_seqmismatch.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Drop test for a remote SEQ mismatch during accumulation. Opens a
//          remote packet with one seq, then sends a fragment with a different
//          seq; the open packet must be dropped and counted in drop_cnt.
//==============================================================================

`ifndef BIRD_TEST_REMOTE_SEQMISMATCH_SV
`define BIRD_TEST_REMOTE_SEQMISMATCH_SV

`include "bird_base_test.sv"

class bird_test_remote_seqmismatch extends bird_base_test;
  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  task body();
    bird_seq_remote_seqmismatch s;
    s = new(seq2drv);
    s.run();
  endtask
endclass

`endif
