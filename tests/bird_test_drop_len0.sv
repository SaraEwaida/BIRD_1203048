//==============================================================================
// File   : bird_test_drop_len0.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Drop test for PAYLOAD_LEN = 0. Drives illegal packets with len=0
//          that the DUT must silently drop and count in drop_cnt.
//==============================================================================

`ifndef BIRD_TEST_DROP_LEN0_SV
`define BIRD_TEST_DROP_LEN0_SV

`include "bird_base_test.sv"

class bird_test_drop_len0 extends bird_base_test;
  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  task body();
    bird_seq_drop_len0 s;
    s = new(seq2drv, 4);
    s.run();
  endtask
endclass

`endif
