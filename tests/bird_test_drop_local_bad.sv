//==============================================================================
// File   : bird_test_drop_local_bad.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Drop test for malformed local packets (frag != 1). The DUT
//          requires local packets to have seq=1 and frag=1; otherwise the
//          packet must be silently dropped and counted in drop_cnt.
//==============================================================================

`ifndef BIRD_TEST_DROP_LOCAL_BAD_SV
`define BIRD_TEST_DROP_LOCAL_BAD_SV

`include "bird_base_test.sv"

class bird_test_drop_local_bad extends bird_base_test;
  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  task body();
    bird_seq_drop_local_bad s;
    s = new(seq2drv, 4);
    s.run();
  endtask
endclass

`endif
