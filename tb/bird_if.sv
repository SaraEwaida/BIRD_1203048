//==============================================================================
// File   : bird_if.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 1 (Interface & Data)
// Purpose: Pin-level interface between the testbench and the BIRD DUT.
//          Contains all DUT signals, a single testbench clocking block, and
//          two modports (TEST for the testbench, DUT for the design).
//
// Signal names follow the BIRD functional specification, Section 4.
// Style follows the class slides (Tumbush/Spear, Chapter 4): one clocking
// block for the testbench domain, modport TEST(clocking cb, ...), modport DUT.
//==============================================================================

interface bird_if (input bit clk);

  //--------------------------------------------------------------------------
  // Global signals
  //--------------------------------------------------------------------------
  logic        rst_n;        // active-low reset (driven asynchronously by TB)

  //--------------------------------------------------------------------------
  // Input interface  (Producer -> BIRD)
  //--------------------------------------------------------------------------
  logic        in_vld;       // input data valid          (TB drives)
  logic        in_rdy;       // BIRD ready to accept input (TB samples)
  logic [7:0]  data_in;      // payload / CRC data stream  (TB drives)
  logic [31:0] cfg;          // sideband configuration word(TB drives)

  //--------------------------------------------------------------------------
  // Local output interface  (BIRD -> local consumer = TB)
  //--------------------------------------------------------------------------
  logic        local_vld;    // local output valid         (TB samples)
  logic        local_rdy;    // local consumer ready       (TB drives)
  logic [7:0]  data_local;   // local payload data         (TB samples)

  //--------------------------------------------------------------------------
  // Remote output interface  (BIRD -> remote consumer = TB)
  //--------------------------------------------------------------------------
  logic        remote_vld;   // remote output valid        (TB samples)
  logic        remote_rdy;   // remote consumer ready      (TB drives)
  logic [31:0] data_remote;  // remote packet data stream  (TB samples)

  //--------------------------------------------------------------------------
  // Status output
  //--------------------------------------------------------------------------
  logic [15:0] drop_cnt;     // number of dropped packets  (TB samples)

  //--------------------------------------------------------------------------
  // Testbench clocking block
  //   - Drive DUT inputs just after the active edge.
  //   - Sample DUT outputs just before the active edge.
  //   - "output" here = signals the TESTBENCH drives.
  //     "input"  here = signals the TESTBENCH samples.
  //--------------------------------------------------------------------------
  clocking cb @(posedge clk);
    // Signals the testbench DRIVES (these are inputs to the DUT)
    output in_vld, data_in, cfg;
    output local_rdy, remote_rdy;
    // Signals the testbench SAMPLES (these are outputs of the DUT)
    input  in_rdy;
    input  local_vld, data_local;
    input  remote_vld, data_remote;
    input  drop_cnt;
  endclocking

  //--------------------------------------------------------------------------
  // Modports
  //--------------------------------------------------------------------------
  // Testbench side: uses the clocking block for synchronous signals and
  // drives rst_n directly (asynchronous reset).
  modport TEST (clocking cb, output rst_n, input clk);

  // DUT side: ordinary directions, no clocking block.
  modport DUT (
    input  clk, rst_n,
    input  in_vld, data_in, cfg,
    input  local_rdy, remote_rdy,
    output in_rdy,
    output local_vld, data_local,
    output remote_vld, data_remote,
    output drop_cnt
  );

endinterface : bird_if
