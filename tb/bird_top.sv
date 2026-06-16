//==============================================================================
// File   : bird_top.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 1 (Interface & Data)
// Purpose: Top-level testbench module. Generates the clock and reset,
//          instantiates the interface and the DUT, connects them, and
//          starts the test.
//
// Style follows the class slides (Tumbush/Spear, Chapter 4): a top module
// that wraps the DUT, drives the clock, and wires the interface to the DUT.
//==============================================================================

`include "bird_if.sv"
`include "bird_transaction.sv"
`include "bird_sequence.sv"
`include "bird_driver.sv"
`include "bird_monitor.sv"
`include "bird_scoreboard.sv"
`include "bird_env.sv"

module bird_top;

  //--------------------------------------------------------------------------
  // Clock generation : 10 ns period (100 MHz)
  //--------------------------------------------------------------------------
  bit clk;
  initial clk = 1'b0;
  always #5 clk = ~clk;

  //--------------------------------------------------------------------------
  // Interface instance
  //--------------------------------------------------------------------------
  bird_if vif (clk);

  //--------------------------------------------------------------------------
  // DUT instantiation
  //
  //   IMPORTANT: confirm the DUT module name ("bird") and the port names
  //   below against the design on edaplayground (link in the project spec).
  //   The signal names used here come from the BIRD spec, Section 4, so they
  //   should match; adjust only if the DUT uses different identifiers.
  //--------------------------------------------------------------------------
  bird DUT (
    .clk         (clk),
    .rst_n       (vif.rst_n),
    // input interface
    .in_vld      (vif.in_vld),
    .in_rdy      (vif.in_rdy),
    .data_in     (vif.data_in),
    .cfg         (vif.cfg),
    // local output interface
    .local_vld   (vif.local_vld),
    .local_rdy   (vif.local_rdy),
    .data_local  (vif.data_local),
    // remote output interface
    .remote_vld  (vif.remote_vld),
    .remote_rdy  (vif.remote_rdy),
    .data_remote (vif.data_remote),
    // status
    .drop_cnt    (vif.drop_cnt)
  );

  //--------------------------------------------------------------------------
  // Reset generation : assert rst_n low, then release after a few clocks
  //--------------------------------------------------------------------------
  initial begin
    vif.rst_n = 1'b0;
    repeat (3) @(posedge clk);
    vif.rst_n = 1'b1;
  end

  //--------------------------------------------------------------------------
  // Test start
  //   Once the environment/test classes exist, construct and run the test
  //   here, passing the interface handle. For now this is a placeholder that
  //   the team will fill in. Example (final form):
  //
  //     bird_test t;
  //     initial begin
  //       t = new(vif);
  //       t.run();
  //       $finish;
  //     end
  //--------------------------------------------------------------------------
 bird_env env;

initial begin
  env = new(vif, 10);
  env.build();
  env.run();
  $finish;
end

  //--------------------------------------------------------------------------
  // Optional waveform dump (handy on the EDA server)
  //--------------------------------------------------------------------------
  initial begin
    $dumpfile("bird.vcd");
    $dumpvars(0, bird_top);
  end

endmodule : bird_top
