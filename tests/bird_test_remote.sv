//==============================================================================
// File   : bird_test_remote.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Remote reassembly test. Sends a multi-fragment remote packet
//          (same seq, frags 1..N) that the DUT must reorder, merge, and
//          re-CRC on the remote output.
//==============================================================================

`ifndef BIRD_TEST_REMOTE_SV
`define BIRD_TEST_REMOTE_SV

`include "bird_base_test.sv"

class bird_test_remote extends bird_base_test;
  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  task body();
    bird_seq_remote s;
    s = new(seq2drv, 3, 3);
    s.run();
  endtask
endclass

`endif
