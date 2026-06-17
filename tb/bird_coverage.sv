//==============================================================================
// File   : bird_coverage.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 3 (Functional Coverage)
// Purpose: Functional coverage for the BIRD input stream. Samples each packet
//          observed by the monitor (traffic type, payload length, fragment
//          number, sequence number, reserved-bit violations) and the useful
//          crosses, then forwards the packet unchanged to the scoreboard.
//
// Style follows the class slides (Tumbush/Spear): a plain class holding one
// covergroup, sampled from a run() task fed by mailboxes. No UVM.
//
// Coverage model (BIRD spec, Section 5/6):
//   - traffic_type : local vs remote
//   - payload_len  : boundary + range bins (incl. illegal 0 and max 255)
//   - frag_num     : illegal 0, single (1), middle, max (31)
//   - seq_num      : illegal 0, first (1), middle, max (31)
//   - reserved     : whether any reserved cfg bit was set (must be 0 = legal)
//   - crosses      : traffic_type x payload_len, traffic_type x frag_num
//
// NOTE: the illegal bins (len=0, frag=0, seq=0, reserved=violation) stay empty
// until directed "drop" sequences exercise them (that is Student 2's task).
// Empty bins here are expected holes, not bugs.
//==============================================================================

`ifndef BIRD_COVERAGE_SV
`define BIRD_COVERAGE_SV

class bird_coverage;

  // Mailboxes: in/cfg come FROM the monitor; out/ocfg go TO the scoreboard.
  mailbox #(bird_transaction) in_mb;
  mailbox #(bit [31:0])       cfg_mb;
  mailbox #(bird_transaction) out_mb;
  mailbox #(bit [31:0])       ocfg_mb;

  // Sampled values (set just before cg.sample()).
  bit        s_traffic;
  bit [7:0]  s_len;
  bit [4:0]  s_frag;
  bit [4:0]  s_seq;
  bit        s_reserved;

  int unsigned sampled;

  //--------------------------------------------------------------------------
  // Covergroup
  //--------------------------------------------------------------------------
  covergroup cg;
    option.per_instance = 1;

    cp_traffic : coverpoint s_traffic {
      bins loc = {0};   // local  (note: 'local' is a reserved SV keyword)
      bins rem = {1};   // remote
    }

    cp_len : coverpoint s_len {
      bins zero  = {0};            // illegal payload length
      bins one   = {1};
      bins sml   = {[2:15]};      // 'small' is a reserved SV keyword
      bins mid   = {[16:127]};
      bins lrg   = {[128:254]};   // 'large' is a reserved SV keyword
      bins max   = {255};
    }

    cp_frag : coverpoint s_frag {
      bins zero = {0};             // illegal fragment number
      bins one  = {1};
      bins mid  = {[2:30]};
      bins max  = {31};
    }

    cp_seq : coverpoint s_seq {
      bins zero = {0};             // illegal sequence number
      bins one  = {1};
      bins mid  = {[2:30]};
      bins max  = {31};
    }

    cp_reserved : coverpoint s_reserved {
      bins clean     = {0};
      bins violation = {1};
    }

    x_traffic_len  : cross cp_traffic, cp_len;
    x_traffic_frag : cross cp_traffic, cp_frag;
  endgroup

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(mailbox #(bird_transaction) in_mb,
               mailbox #(bit [31:0])       cfg_mb,
               mailbox #(bird_transaction) out_mb,
               mailbox #(bit [31:0])       ocfg_mb);
    this.in_mb   = in_mb;
    this.cfg_mb  = cfg_mb;
    this.out_mb  = out_mb;
    this.ocfg_mb = ocfg_mb;
    this.sampled = 0;
    cg = new();
  endfunction

  //--------------------------------------------------------------------------
  // run : sample each observed input, then forward it to the scoreboard.
  //--------------------------------------------------------------------------
  task run();
    bird_transaction tr;
    bit [31:0]       raw_cfg;

    forever begin
      in_mb.get(tr);
      cfg_mb.get(raw_cfg);

      // Latch the fields, then sample.
      s_traffic  = tr.traffic_type;
      s_len      = tr.payload_len;
      s_frag     = tr.frag_num;
      s_seq      = tr.seq_num;
      s_reserved = (raw_cfg[7:1]   != 7'b0) ||
                   (raw_cfg[23:21] != 3'b0) ||
                   (raw_cfg[31:29] != 3'b0);
      cg.sample();
      sampled++;

      // Forward UNCHANGED so the scoreboard sees the same stream/order.
      out_mb.put(tr);
      ocfg_mb.put(raw_cfg);
    end
  endtask

  //--------------------------------------------------------------------------
  // report : print the achieved functional coverage.
  //--------------------------------------------------------------------------
  function void report();
    $display("============================================================");
    $display("[bird_coverage] FUNCTIONAL COVERAGE REPORT");
    $display("  packets sampled       : %0d", sampled);
    $display("  functional coverage   : %0.2f %%", cg.get_coverage());
    $display("============================================================");
  endfunction

endclass : bird_coverage

`endif // BIRD_COVERAGE_SV
