//==============================================================================
// File   : bird_tests_top.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Standalone top for running the directed tests with coverage. Picks
//          the active test from +TEST=<tag>, wires the DUT to the interface,
//          drives clock and reset, and runs the selected test. Does not modify
//          any teammate file; reuses the existing tb classes and DUT.
//==============================================================================

`include "bird_if.sv"
`include "bird_transaction.sv"
`include "bird_driver.sv"
`include "bird_monitor.sv"
`include "bird_scoreboard.sv"
`include "bird_coverage.sv"
`include "bird_test_legal.sv"
`include "bird_test_remote.sv"
`include "bird_test_drop_seq0.sv"
`include "bird_test_drop_frag0.sv"
`include "bird_test_drop_len0.sv"
`include "bird_test_drop_local_bad.sv"
`include "bird_test_remote_seqmismatch.sv"

module bird_tests_top;

  bit clk;
  initial clk = 1'b0;
  always #5 clk = ~clk;

  bird_if vif (clk);

  bird DUT (
    .clk         (clk),
    .rst_n       (vif.rst_n),
    .in_vld      (vif.in_vld),
    .in_rdy      (vif.in_rdy),
    .data_in     (vif.data_in),
    .cfg         (vif.cfg),
    .local_vld   (vif.local_vld),
    .local_rdy   (vif.local_rdy),
    .data_local  (vif.data_local),
    .remote_vld  (vif.remote_vld),
    .remote_rdy  (vif.remote_rdy),
    .data_remote (vif.data_remote),
    .drop_cnt    (vif.drop_cnt)
  );

  initial begin
    vif.rst_n = 1'b0;
    repeat (3) @(posedge clk);
    vif.rst_n = 1'b1;
  end

  initial begin
    string tname;
    bird_base_test test;
    if (!$value$plusargs("TEST=%s", tname)) tname = "legal";
    case (tname)
      "legal":              begin bird_test_legal              x; x = new(vif); test = x; end
      "remote":             begin bird_test_remote             x; x = new(vif); test = x; end
      "drop_seq0":          begin bird_test_drop_seq0          x; x = new(vif); test = x; end
      "drop_frag0":         begin bird_test_drop_frag0         x; x = new(vif); test = x; end
      "drop_len0":          begin bird_test_drop_len0          x; x = new(vif); test = x; end
      "drop_local_bad":     begin bird_test_drop_local_bad     x; x = new(vif); test = x; end
      "remote_seqmismatch": begin bird_test_remote_seqmismatch x; x = new(vif); test = x; end
      default:              begin bird_test_legal              x; x = new(vif); test = x; end
    endcase
    $display("[bird_tests_top] running TEST=%s", tname);
    test.run();
    $finish;
  end

  initial begin
    #5_000_000;
    $display("[bird_tests_top] TIMEOUT");
    $finish;
  end

  initial begin
    $dumpfile("bird_tests.vcd");
    $dumpvars(0, bird_tests_top);
  end

endmodule : bird_tests_top
