//==============================================================================
// File   : bird.f
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Purpose: Compile file list for Synopsys VCS.
//
// Run from the sim/ directory. The DUT is passed separately (Makefile DUT=
// variable or on the vcs command line), because the BIRD design file is not
// part of this repository.
//==============================================================================

// Search path so `include statements in bird_top.sv resolve to ../tb
+incdir+../tb

// Testbench top. bird_top.sv `includes every other tb class
// (interface, transaction, sequence, driver, monitor, scoreboard,
//  coverage, env, test), so only the top file is listed here.
../tb/bird_top.sv
