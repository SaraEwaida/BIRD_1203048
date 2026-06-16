class bird_scoreboard;

  
  // Properties
  
  virtual bird_if             vif;
  mailbox #(bird_transaction) mon2sb_in;
  mailbox #(bit [31:0])       mon2sb_cfg;
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  // Expected vs observed (filled during the run, compared in wrap_up).
  bit [7:0]  exp_local_q  [$];
  bit [7:0]  obs_local_q  [$];
  bit [31:0] exp_remote_q [$];
  bit [31:0] obs_remote_q [$];

  // Remote reassembly state (only one remote packet at a time, spec 7.1).
  bit       rem_active;
  bit [4:0] rem_seq;
  typedef struct { bit [4:0] frag_num; bit [7:0] bytes []; } frag_rec_t;
  frag_rec_t rem_frags [$];

  // Stats
  int unsigned in_count;
  int unsigned exp_drop_count;

  // Constructor
  function new(virtual bird_if             vif,
               mailbox #(bird_transaction) mon2sb_in,
               mailbox #(bit [31:0])       mon2sb_cfg,
               mailbox #(bit [7:0])        mon2sb_local,
               mailbox #(bit [31:0])       mon2sb_remote);
    this.vif           = vif;
    this.mon2sb_in     = mon2sb_in;
    this.mon2sb_cfg    = mon2sb_cfg;
    this.mon2sb_local  = mon2sb_local;
    this.mon2sb_remote = mon2sb_remote;
    rem_active     = 1'b0;
    in_count       = 0;
    exp_drop_count = 0;
  endfunction

  
  // is_drop_cfg : cfg-only drop checks. Uses RAW cfg so reserved bits show.
  function bit is_drop_cfg(bit [31:0] raw_cfg);
    if (raw_cfg[7:1]   != 7'b0) return 1'b1;     // reserved
    if (raw_cfg[23:21] != 3'b0) return 1'b1;     // reserved
    if (raw_cfg[31:29] != 3'b0) return 1'b1;     // reserved
    if (raw_cfg[28:24] == 5'd0) return 1'b1;     // seq_num == 0
    if (raw_cfg[20:16] == 5'd0) return 1'b1;     // frag_num == 0
    if (raw_cfg[15:8]  == 8'd0) return 1'b1;     // payload_len == 0
    return 1'b0;
  endfunction

  
  // run : start the producer/collectors in parallel.
  task run();
    fork
      process_inputs();
      collect_local_outputs();
      collect_remote_outputs();
    join_none
  endtask

  
  // process_inputs : predict expected output / drops from each input.
  task process_inputs();
    bird_transaction tr;
    bit [31:0]       raw_cfg;
    bit [4:0]        frag_num, seq_num;

    forever begin
      mon2sb_in.get(tr);
      mon2sb_cfg.get(raw_cfg);
      in_count++;

      frag_num = raw_cfg[20:16];
      seq_num  = raw_cfg[28:24];

      if (is_drop_cfg(raw_cfg)) begin
        exp_drop_count++;
        $display("[bird_scoreboard] DROP (cfg) cfg=0x%08h -> exp_drop=%0d",
                 raw_cfg, exp_drop_count);
        continue;
      end

      if (raw_cfg[0] == 1'b0) begin
        // Local must be a single fragment (frag_num == 1, spec 6).
        if (frag_num != 5'd1) begin
          exp_drop_count++;
          $display("[bird_scoreboard] DROP (local frag!=1) cfg=0x%08h -> exp_drop=%0d",
                   raw_cfg, exp_drop_count);
          continue;
        end
        predict_local(tr);
      end
      else begin
        predict_remote(tr, seq_num, frag_num);
      end
    end
  endtask

  // predict_local : payload bytes + CRC high + CRC low, forwarded unchanged.
  task predict_local(bird_transaction tr);
    foreach (tr.payload[i]) exp_local_q.push_back(tr.payload[i]);
    exp_local_q.push_back(tr.crc16[15:8]);
    exp_local_q.push_back(tr.crc16[7:0]);
  endtask

  task predict_remote(bird_transaction tr, bit [4:0] seq_num, bit [4:0] frag_num);
    if (!rem_active) begin
      start_remote_accum(tr, seq_num);
      return;
    end
    // Mismatched seq while a packet is open -> drop it, discard its buffer, then start fresh with the arriving fragment (spec 8.1).
    if (seq_num != rem_seq) begin
      exp_drop_count++;
      $display("[bird_scoreboard] DROP (remote seq mismatch arr=%0d open=%0d) -> exp_drop=%0d",
               seq_num, rem_seq, exp_drop_count);
      rem_active = 1'b0;
      rem_frags.delete();
      start_remote_accum(tr, seq_num);
      return;
    end
    add_remote_fragment(tr, frag_num);
  endtask

  task start_remote_accum(bird_transaction tr, bit [4:0] seq_num);
    rem_active = 1'b1;
    rem_seq    = seq_num;
    rem_frags.delete();
    add_remote_fragment(tr, tr.frag_num);
  endtask

  // Store a fragment by FRAG_NUM; a repeat of the same frag replaces it.
  task add_remote_fragment(bird_transaction tr, bit [4:0] frag_num);
    frag_rec_t rec;
    int        idx = -1;
    rec.frag_num = frag_num;
    rec.bytes    = new[tr.payload.size()];
    foreach (tr.payload[i]) rec.bytes[i] = tr.payload[i];
    foreach (rem_frags[k]) if (rem_frags[k].frag_num == frag_num) idx = k;
    if (idx >= 0) rem_frags[idx] = rec;
    else          rem_frags.push_back(rec);
  endtask

  // 1 if buffered frag numbers form a complete contiguous set 1..N.
  function bit remote_is_contiguous();
    int n = rem_frags.size();
    bit seen [int];
    if (n == 0) return 1'b0;
    foreach (rem_frags[k]) seen[rem_frags[k].frag_num] = 1'b1;
    for (int f = 1; f <= n; f++) if (!seen.exists(f)) return 1'b0;
    return 1'b1;
  endfunction


  task finalize_remote();
    bit [7:0]  merged [];
    bit [7:0]  stream [];
    bit [15:0] new_crc;
    int        total = 0, widx = 0, slen, sidx = 0;

    // sort fragments by frag_num
    for (int a = 0; a < rem_frags.size(); a++)
      for (int b = a+1; b < rem_frags.size(); b++)
        if (rem_frags[b].frag_num < rem_frags[a].frag_num) begin
          frag_rec_t tmp = rem_frags[a];
          rem_frags[a]   = rem_frags[b];
          rem_frags[b]   = tmp;
        end

    foreach (rem_frags[k]) total += rem_frags[k].bytes.size();
    merged = new[total];
    foreach (rem_frags[k])
      foreach (rem_frags[k].bytes[j]) merged[widx++] = rem_frags[k].bytes[j];

    new_crc = calc_crc16(merged);

    slen   = total + 2;
    stream = new[slen];
    foreach (merged[i]) stream[sidx++] = merged[i];
    stream[sidx++] = new_crc[15:8];
    stream[sidx++] = new_crc[7:0];

    for (int i = 0; i < slen; i += 4) begin
      bit [31:0] word = 32'h0;
      for (int j = 0; j < 4; j++) begin
        word = word << 8;
        if ((i + j) < slen) word[7:0] = stream[i + j];   // else zero-pad
      end
      exp_remote_q.push_back(word);
    end

    $display("[bird_scoreboard] REMOTE finalize seq=%0d frags=%0d len=%0d crc=0x%04h",
             rem_seq, rem_frags.size(), total, new_crc);

    rem_active = 1'b0;
    rem_frags.delete();
  endtask

  // CRC-16-CCITT (poly 0x1021, init 0xFFFF). Mirrors bird_transaction.
  // NOTE: poly/init/bit-order must be confirmed against the DUT.
  function bit [15:0] calc_crc16(bit [7:0] data []);
    bit [15:0] crc = 16'hFFFF;
    foreach (data[i]) begin
      crc = crc ^ (data[i] << 8);
      for (int b = 0; b < 8; b++)
        crc = crc[15] ? (crc << 1) ^ 16'h1021 : (crc << 1);
    end
    return crc;
  endfunction

  // Collectors: store observed beats only; no comparison here.
  task collect_local_outputs();
    bit [7:0] b;
    forever begin
      mon2sb_local.get(b);
      obs_local_q.push_back(b);
    end
  endtask

  task collect_remote_outputs();
    bit [31:0] w;
    forever begin
      mon2sb_remote.get(w);
      obs_remote_q.push_back(w);
    end
  endtask

  // wrap_up : resolve trailing remote packet, compare queues, print report.
  task wrap_up();
    bit [15:0]   actual_drop;
    int unsigned local_pass = 0, local_fail = 0;
    int unsigned remote_pass = 0, remote_fail = 0;
    int          n;
    bit          verdict_ok;

    // Resolve any remote packet still buffered.
    if (rem_active) begin
      if (remote_is_contiguous()) begin
        finalize_remote();
      end
      else begin
        exp_drop_count++;
        $display("[bird_scoreboard] DROP (remote missing fragment seq=%0d) -> exp_drop=%0d",
                 rem_seq, exp_drop_count);
        rem_active = 1'b0;
        rem_frags.delete();
      end
    end

    // Compare local position by position.
    n = (exp_local_q.size() > obs_local_q.size()) ? exp_local_q.size()
                                                  : obs_local_q.size();
    for (int i = 0; i < n; i++) begin
      if (i >= exp_local_q.size()) begin
        local_fail++;
        $display("[bird_scoreboard] LOCAL FAIL[%0d]: extra obs=0x%02h", i, obs_local_q[i]);
      end
      else if (i >= obs_local_q.size()) begin
        local_fail++;
        $display("[bird_scoreboard] LOCAL FAIL[%0d]: missing exp=0x%02h", i, exp_local_q[i]);
      end
      else if (exp_local_q[i] === obs_local_q[i]) local_pass++;
      else begin
        local_fail++;
        $display("[bird_scoreboard] LOCAL FAIL[%0d]: exp=0x%02h obs=0x%02h",
                 i, exp_local_q[i], obs_local_q[i]);
      end
    end

    // Compare remote position by position.
    n = (exp_remote_q.size() > obs_remote_q.size()) ? exp_remote_q.size()
                                                    : obs_remote_q.size();
    for (int i = 0; i < n; i++) begin
      if (i >= exp_remote_q.size()) begin
        remote_fail++;
        $display("[bird_scoreboard] REMOTE FAIL[%0d]: extra obs=0x%08h", i, obs_remote_q[i]);
      end
      else if (i >= obs_remote_q.size()) begin
        remote_fail++;
        $display("[bird_scoreboard] REMOTE FAIL[%0d]: missing exp=0x%08h", i, exp_remote_q[i]);
      end
      else if (exp_remote_q[i] === obs_remote_q[i]) remote_pass++;
      else begin
        remote_fail++;
        $display("[bird_scoreboard] REMOTE FAIL[%0d]: exp=0x%08h obs=0x%08h",
                 i, exp_remote_q[i], obs_remote_q[i]);
      end
    end

    @(vif.cb);
    actual_drop = vif.cb.drop_cnt;

    verdict_ok = (local_fail == 0) && (remote_fail == 0) &&
                 (exp_drop_count[15:0] === actual_drop);

    $display("============================================================");
    $display("[bird_scoreboard] END-OF-TEST REPORT");
    $display("------------------------------------------------------------");
    $display("  input packets/fragments observed : %0d", in_count);
    $display("  local  PASS / FAIL               : %0d / %0d", local_pass, local_fail);
    $display("  remote PASS / FAIL               : %0d / %0d", remote_pass, remote_fail);
    $display("  expected drop count              : %0d", exp_drop_count);
    $display("  actual drop_cnt (DUT)            : %0d", actual_drop);
    $display("------------------------------------------------------------");
    $display("  FINAL RESULT : %s", verdict_ok ? "PASS" : "FAIL");
    $display("============================================================");
  endtask

endclass : bird_scoreboard