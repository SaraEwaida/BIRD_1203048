//==============================================================================
// File   : bird_seq_lib.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 4: Maysam Abu Eid - 1220675
// Purpose: Directed sequence library for the BIRD tests. Generates legal,
//          drop, and remote stimulus and puts each transaction into the
//          seq2drv mailbox for the driver. Built against the existing
//          bird_transaction API (fields + named constraints); drives no
//          signals and modifies no teammate files.
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
    bird_transaction tr;
    for (int i = 0; i < n; i++) begin
      tr = new();
      if (tr.randomize() with { traffic_type == 1'b0; seq_num == 5'd1; }) begin
        tr.display("[seq_legal_local]");
        seq2drv.put(tr);
      end
      else $display("[seq_legal_local] randomize failed");
    end
  endtask
endclass

class bird_seq_remote;
  mailbox #(bird_transaction) seq2drv;
  int seq;
  int num_frags;
  function new(mailbox #(bird_transaction) seq2drv, int seq = 1, int num_frags = 1);
    this.seq2drv   = seq2drv;
    this.seq       = seq;
    this.num_frags = num_frags;
  endfunction
  task run();
    bird_transaction tr;
    for (int f = 1; f <= num_frags; f++) begin
      tr = new();
      if (tr.randomize() with { traffic_type == 1'b1;
                                seq_num  == seq;
                                frag_num == f;
                                payload_len inside {[1:8]}; }) begin
        tr.display("[seq_remote]");
        seq2drv.put(tr);
      end
      else $display("[seq_remote] randomize failed");
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
    bird_transaction tr;
    for (int i = 0; i < n; i++) begin
      tr = new();
      tr.c_seq_valid.constraint_mode(0);
      if (tr.randomize() with { traffic_type == 1'b1; seq_num == 5'd0; }) begin
        tr.display("[seq_drop_seq0]");
        seq2drv.put(tr);
      end
      else $display("[seq_drop_seq0] randomize failed");
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
    bird_transaction tr;
    for (int i = 0; i < n; i++) begin
      tr = new();
      tr.c_frag_valid.constraint_mode(0);
      if (tr.randomize() with { traffic_type == 1'b1; frag_num == 5'd0; }) begin
        tr.display("[seq_drop_frag0]");
        seq2drv.put(tr);
      end
      else $display("[seq_drop_frag0] randomize failed");
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
    bird_transaction tr;
    for (int i = 0; i < n; i++) begin
      tr = new();
      tr.c_len_valid.constraint_mode(0);
      if (tr.randomize() with { traffic_type == 1'b1; seq_num == 5'd1; frag_num == 5'd1; payload_len == 8'd0; }) begin
        tr.display("[seq_drop_len0]");
        seq2drv.put(tr);
      end
      else $display("[seq_drop_len0] randomize failed");
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
    bird_transaction tr;
    for (int i = 0; i < n; i++) begin
      tr = new();
      tr.c_local_frag.constraint_mode(0);
      if (tr.randomize() with { traffic_type == 1'b0; seq_num == 5'd1; frag_num inside {[2:31]}; }) begin
        tr.display("[seq_drop_local_bad]");
        seq2drv.put(tr);
      end
      else $display("[seq_drop_local_bad] randomize failed");
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
    if (tr.randomize() with { traffic_type == 1'b1; seq_num == 5'd5; frag_num == 5'd1; payload_len inside {[1:4]}; }) begin
      tr.display("[seq_remote_seqmismatch]");
      seq2drv.put(tr);
    end
    tr = new();
    if (tr.randomize() with { traffic_type == 1'b1; seq_num == 5'd7; frag_num == 5'd1; payload_len inside {[1:4]}; }) begin
      tr.display("[seq_remote_seqmismatch]");
      seq2drv.put(tr);
    end
  endtask
endclass

`endif
