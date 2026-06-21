//==============================================================================
// File   : bird_seq_lib.sv
// Purpose: Directed legal, remote, drop and coverage-closure sequences.
//==============================================================================

`ifndef BIRD_SEQ_LIB_SV
`define BIRD_SEQ_LIB_SV

class bird_seq_legal_local;
  mailbox #(bird_transaction) seq2drv;
  int n;

  function new(mailbox #(bird_transaction) seq2drv, int n = 10);
    this.seq2drv = seq2drv;
    this.n       = n;
  endfunction

  task run();
    repeat (n) begin
      bird_transaction tr = new();
      assert(tr.randomize() with {
        traffic_type == 0;
        seq_num      == 1;
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_remote;
  mailbox #(bird_transaction) seq2drv;
  int seq;
  int num_frags;

  function new(mailbox #(bird_transaction) seq2drv,
               int seq = 1,
               int num_frags = 1);
    this.seq2drv   = seq2drv;
    this.seq       = seq;
    this.num_frags = num_frags;
  endfunction

  task run();
    for (int f = 1; f <= num_frags; f++) begin
      bird_transaction tr = new();
      assert(tr.randomize() with {
        traffic_type == 1;
        seq_num      == seq;
        frag_num     == f;
        payload_len  inside {[1:8]};
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_drop_seq0;
  mailbox #(bird_transaction) seq2drv;
  int n;

  function new(mailbox #(bird_transaction) seq2drv, int n = 3);
    this.seq2drv = seq2drv;
    this.n       = n;
  endfunction

  task run();
    repeat (n) begin
      bird_transaction tr = new();
      tr.c_seq_valid.constraint_mode(0);
      assert(tr.randomize() with {
        traffic_type == 1;
        seq_num      == 0;
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_drop_frag0;
  mailbox #(bird_transaction) seq2drv;
  int n;

  function new(mailbox #(bird_transaction) seq2drv, int n = 3);
    this.seq2drv = seq2drv;
    this.n       = n;
  endfunction

  task run();
    repeat (n) begin
      bird_transaction tr = new();
      tr.c_frag_valid.constraint_mode(0);
      assert(tr.randomize() with {
        traffic_type == 1;
        frag_num     == 0;
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_drop_len0;
  mailbox #(bird_transaction) seq2drv;
  int n;

  function new(mailbox #(bird_transaction) seq2drv, int n = 3);
    this.seq2drv = seq2drv;
    this.n       = n;
  endfunction

  task run();
    repeat (n) begin
      bird_transaction tr = new();
      tr.c_len_valid.constraint_mode(0);
      assert(tr.randomize() with {
        traffic_type == 1;
        seq_num      == 1;
        frag_num     == 1;
        payload_len  == 0;
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_drop_local_bad;
  mailbox #(bird_transaction) seq2drv;
  int n;

  function new(mailbox #(bird_transaction) seq2drv, int n = 3);
    this.seq2drv = seq2drv;
    this.n       = n;
  endfunction

  task run();
    repeat (n) begin
      bird_transaction tr = new();
      tr.c_local_frag.constraint_mode(0);
      assert(tr.randomize() with {
        traffic_type == 0;
        seq_num      == 1;
        frag_num     inside {[2:31]};
      });
      seq2drv.put(tr);
    end
  endtask
endclass

class bird_seq_remote_seqmismatch;
  mailbox #(bird_transaction) seq2drv;

  function new(mailbox #(bird_transaction) seq2drv);
    this.seq2drv = seq2drv;
  endfunction

  task run();
    bird_transaction tr;

    tr = new();
    assert(tr.randomize() with {
      traffic_type == 1;
      seq_num      == 5;
      frag_num     == 1;
      payload_len  inside {[1:4]};
    });
    seq2drv.put(tr);

    tr = new();
    assert(tr.randomize() with {
      traffic_type == 1;
      seq_num      == 7;
      frag_num     == 1;
      payload_len  inside {[1:4]};
    });
    seq2drv.put(tr);
  endtask
endclass

class bird_seq_coverage_closure;
  mailbox #(bird_transaction) seq2drv;

  function new(mailbox #(bird_transaction) seq2drv);
    this.seq2drv = seq2drv;
  endfunction

  task send_case(bit        tt,
                 bit [7:0]  plen,
                 bit [4:0]  frag,
                 bit [4:0]  seq,
                 bit [31:0] reserved_mask);
    bird_transaction tr = new();
    bit [31:0] normal_cfg;

    if (plen == 0)
      tr.c_len_valid.constraint_mode(0);
    if (frag == 0)
      tr.c_frag_valid.constraint_mode(0);
    if (seq == 0)
      tr.c_seq_valid.constraint_mode(0);
    if (!tt && frag != 1)
      tr.c_local_frag.constraint_mode(0);

    assert(tr.randomize() with {
      traffic_type == tt;
      payload_len  == plen;
      frag_num     == frag;
      seq_num      == seq;
    });

    if (reserved_mask != 0) begin
      normal_cfg          = tr.get_cfg();
      tr.cfg_override     = normal_cfg | reserved_mask;
      tr.use_cfg_override = 1;
    end

    tr.display("[coverage_closure]");
    seq2drv.put(tr);
  endtask

  task run();
    // Length boundaries and local-to-local transition.
    send_case(0, 255, 1, 1, 0);
    send_case(0,   2, 1, 1, 0);
    send_case(0,   1, 1, 1, 0);
    send_case(0,   0, 1, 1, 0);

    // Local invalid fragment boundaries.
    send_case(0, 16, 31, 1, 0);
    send_case(0, 16,  0, 1, 0);

    // Remote length/sequence maxima in an expected FRAG_NUM=0 drop.
    send_case(1, 255, 0, 31, 0);

    // Remote order coverage using SEQ_NUM=0 expected-drop packets.
    send_case(1, 4, 1, 0, 0); // first/new sequence
    send_case(1, 4, 2, 0, 0); // ascending
    send_case(1, 4, 3, 0, 0); // ascending
    send_case(1, 4, 2, 0, 0); // descending
    send_case(1, 4, 2, 0, 0); // duplicate

    // Several valid single-fragment remote packets make remote backpressure
    // deterministic across the driver's 12-cycle ready pattern.
    repeat (6)
      send_case(1, 4, 1, 1, 0);

    // Remote-to-local transition.
    send_case(0, 16, 1, 1, 0);

    // Toggle every bit in each reserved field in separate expected drops.
    send_case(0, 16, 1, 1, 32'h0000_00fe);
    send_case(0, 16, 1, 1, 32'h00e0_0000);
    send_case(0, 16, 1, 1, 32'he000_0000);
  endtask
endclass

`endif
