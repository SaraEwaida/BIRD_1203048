// Author: Dana Taher - 1221240   (extended with directed scenarios)
// File: bird_sequence.sv
// Purpose: Generate a MEANINGFUL mix of BIRD stimulus instead of scattered
//          random fragments, so the scoreboard, coverage, and DUT drop paths
//          are all actually exercised:
//            - local traffic (valid, plus a spec-legal SEQ!=1 case)
//            - a COMPLETE remote packet (fragments 1..N, same SEQ, out of
//              order) so reassembly/reorder/merge is tested
//            - directed drop cases (SEQ=0, FRAG=0, LEN=0, remote SEQ mismatch)
//            - varied payload lengths to fill the coverage length bins
//
// Illegal stimulus is produced by turning constraints off with
// constraint_mode(0) (slide-style), then forcing the field via randomize with.
//==============================================================================

class bird_sequence;

  mailbox #(bird_transaction) seq2drv;
  int number_of_transactions;   // kept for env compatibility (extra randoms)

  function new(mailbox #(bird_transaction) seq2drv,
               int number_of_transactions = 5);
    this.seq2drv                = seq2drv;
    this.number_of_transactions = number_of_transactions;
  endfunction

  // Build one fragment with explicit fields. allow_illegal disables the
  // legality constraints so SEQ=0 / FRAG=0 / LEN=0 can be generated.
  function bird_transaction make_tr(bit ttype, bit [4:0] seq, bit [4:0] frag,
                                    int len, bit allow_illegal = 0);
    bird_transaction tr = new();
    if (allow_illegal) begin
      tr.c_seq_valid.constraint_mode(0);
      tr.c_frag_valid.constraint_mode(0);
      tr.c_len_valid.constraint_mode(0);
      tr.c_local_frag.constraint_mode(0);
    end
    if (!tr.randomize() with {
          traffic_type == ttype;
          seq_num      == seq;
          frag_num     == frag;
          payload_len  == len;
        })
      $display("[bird_sequence] WARN randomize failed (ttype=%0d seq=%0d frag=%0d len=%0d)",
               ttype, seq, frag, len);
    return tr;
  endfunction

  task send(bird_transaction tr, string note);
    tr.display($sformatf("[bird_sequence] %s", note));
    seq2drv.put(tr);
  endtask

  task run();
    // --- Forwarded traffic: keep payloads SMALL so output checks stay readable
    send(make_tr(1'b0, 5'd1, 5'd1, 4),   "LOCAL seq=1 (valid forward)");
    send(make_tr(1'b0, 5'd5, 5'd1, 4),   "LOCAL seq=5 (spec-legal; DUT bug drops it)");
    send(make_tr(1'b1, 5'd7, 5'd1, 4),   "REMOTE seq=7 frag=1");
    send(make_tr(1'b1, 5'd7, 5'd2, 4),   "REMOTE seq=7 frag=2");
    send(make_tr(1'b1, 5'd7, 5'd3, 4),   "REMOTE seq=7 frag=3 (completes)");
    send(make_tr(1'b1, 5'd31, 5'd1, 16), "REMOTE seq=31 frag=1 (single, max seq)");
    // --- Directed DROPs. Big payloads here fill coverage length bins WITHOUT
    //     polluting the output streams (these packets produce no output).
    send(make_tr(1'b1, 5'd0,  5'd1, 255, 1), "DROP seq=0  (len max bin)");
    send(make_tr(1'b1, 5'd9,  5'd0, 200, 1), "DROP frag=0 (len lrg bin)");
    send(make_tr(1'b1, 5'd10, 5'd1, 0,   1), "DROP len=0");
    send(make_tr(1'b1, 5'd20, 5'd31, 64),    "REMOTE seq=20 frag=31 (frag max + len mid bins; never completes -> drop)");
    // --- remote SEQ mismatch: open incomplete packet, then a different seq.
    send(make_tr(1'b1, 5'd12, 5'd2, 8),  "REMOTE seq=12 frag=2 (incomplete)");
    send(make_tr(1'b1, 5'd14, 5'd1, 8),  "REMOTE seq=14 frag=1 (mismatch -> drop seq=12)");
  endtask

endclass : bird_sequence
