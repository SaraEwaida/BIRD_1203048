//==============================================================================
// File   : bird_test_legal.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Legal local traffic test. Drives valid local packets (seq=1,
//          frag=1) that the DUT must forward on the local output.
//==============================================================================

`ifndef BIRD_TEST_LEGAL_SV
`define BIRD_TEST_LEGAL_SV

`include "bird_base_test.sv"

class bird_test_legal extends bird_base_test;
  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  task body();
    bird_seq_legal_local s;
    s = new(seq2drv, 12);
    s.run();
  endtask
endclass

`endif
