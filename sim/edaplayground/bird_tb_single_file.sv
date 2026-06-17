//==============================================================================
// File   : bird_tb_single_file.sv   (EDA Playground convenience build)
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
//
// This is the ENTIRE testbench in ONE file, for pasting into the EDA Playground
// "Testbench" pane. It is just the tb/ files concatenated with the `include
// lines removed - the source of truth stays the separate files in tb/.
//
// HOW TO RUN ON EDA PLAYGROUND:
//   1. Design pane  : paste the BIRD DUT (module "bird").
//   2. Testbench pane: paste this whole file.
//   3. Tools & Simulators: choose "Synopsys VCS" (or "Mentor Questa").
//   4. Tick "Open EPWave after run" if you want waveforms.
//   5. (optional) Run-time args box:  +NTX=20
//   6. Click Run. The log prints the scoreboard PASS/FAIL report and the
//      functional coverage % from bird_coverage.report().
//
// Compile/elaboration order matters, so the blocks below are in dependency
// order: interface -> transaction -> sequence -> driver -> monitor ->
// coverage -> scoreboard -> env -> test -> top module.
//==============================================================================


//==============================================================================
// 1) INTERFACE
//==============================================================================
interface bird_if (input bit clk);

  logic        rst_n;

  // Input interface (Producer -> BIRD)
  logic        in_vld;
  logic        in_rdy;
  logic [7:0]  data_in;
  logic [31:0] cfg;

  // Local output interface (BIRD -> local consumer = TB)
  logic        local_vld;
  logic        local_rdy;
  logic [7:0]  data_local;

  // Remote output interface (BIRD -> remote consumer = TB)
  logic        remote_vld;
  logic        remote_rdy;
  logic [31:0] data_remote;

  // Status output
  logic [15:0] drop_cnt;

  clocking cb @(posedge clk);
    output in_vld, data_in, cfg;
    output local_rdy, remote_rdy;
    input  in_rdy;
    input  local_vld, data_local;
    input  remote_vld, data_remote;
    input  drop_cnt;
  endclocking

  modport TEST (clocking cb, output rst_n, input clk);

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


//==============================================================================
// 2) TRANSACTION
//   cfg layout: [0]=traffic_type, [15:8]=PAYLOAD_LEN, [20:16]=FRAG_NUM,
//               [28:24]=SEQ_NUM, reserved bits must be 0.
//==============================================================================
class bird_transaction;

  rand bit        traffic_type;   // cfg[0]
  rand bit [7:0]  payload_len;    // cfg[15:8]
  rand bit [4:0]  frag_num;       // cfg[20:16]
  rand bit [4:0]  seq_num;        // cfg[28:24]

  rand bit [7:0]  payload [];
  bit  [15:0]     crc16;

  constraint c_seq_valid  { seq_num  inside {[1:31]}; }
  constraint c_frag_valid { frag_num inside {[1:31]}; }
  constraint c_len_valid  { payload_len inside {[1:255]}; }
  constraint c_local_frag { (traffic_type == 1'b0) -> (frag_num == 1); }
  constraint c_payload_size { payload.size() == payload_len; }

  function new();
  endfunction

  function void post_randomize();
    crc16 = calc_crc16();
  endfunction

  function bit [31:0] get_cfg();
    bit [31:0] c;
    c        = '0;
    c[0]     = traffic_type;
    c[15:8]  = payload_len;
    c[20:16] = frag_num;
    c[28:24] = seq_num;
    return c;
  endfunction

  // CRC-16-CCITT (poly 0x1021, init 0xFFFF) - CONFIRM vs DUT.
  function bit [15:0] calc_crc16();
    bit [15:0] crc;
    crc = 16'hFFFF;
    foreach (payload[i]) begin
      crc = crc ^ (payload[i] << 8);
      for (int b = 0; b < 8; b++) begin
        if (crc[15]) crc = (crc << 1) ^ 16'h1021;
        else         crc = (crc << 1);
      end
    end
    return crc;
  endfunction

  function bird_transaction copy();
    bird_transaction t = new();
    t.traffic_type = this.traffic_type;
    t.payload_len  = this.payload_len;
    t.frag_num     = this.frag_num;
    t.seq_num      = this.seq_num;
    t.crc16        = this.crc16;
    t.payload      = new[this.payload.size()];
    foreach (this.payload[i]) t.payload[i] = this.payload[i];
    return t;
  endfunction

  function bit compare(bird_transaction t);
    if (t == null)                          return 0;
    if (traffic_type != t.traffic_type)     return 0;
    if (payload_len  != t.payload_len)      return 0;
    if (frag_num     != t.frag_num)         return 0;
    if (seq_num      != t.seq_num)          return 0;
    if (crc16        != t.crc16)            return 0;
    if (payload.size() != t.payload.size()) return 0;
    foreach (payload[i])
      if (payload[i] != t.payload[i])       return 0;
    return 1;
  endfunction

  function void display(string prefix = "");
    $display("%s BIRD_TX: type=%s seq=%0d frag=%0d len=%0d crc=0x%04h cfg=0x%08h",
             prefix, (traffic_type ? "REMOTE" : "LOCAL"),
             seq_num, frag_num, payload_len, crc16, get_cfg());
    $write("%s   payload =", prefix);
    foreach (payload[i]) $write(" %02h", payload[i]);
    $display("");
  endfunction

endclass : bird_transaction


//==============================================================================
// 3) SEQUENCE
//==============================================================================
class bird_sequence;

  mailbox #(bird_transaction) seq2drv;
  int number_of_transactions;

  function new(mailbox #(bird_transaction) seq2drv,
               int number_of_transactions = 5);
    this.seq2drv                = seq2drv;
    this.number_of_transactions = number_of_transactions;
  endfunction

  function bird_transaction make_tr(bit ttype, bit [4:0] seq, bit [4:0] frag,
                                    int len, bit allow_illegal = 0);
    bird_transaction tr = new();
    if (allow_illegal) begin
      tr.c_seq_valid.constraint_mode(0);
      tr.c_frag_valid.constraint_mode(0);
      tr.c_len_valid.constraint_mode(0);
      tr.c_local_frag.constraint_mode(0);
    end
    if (!tr.randomize() with { traffic_type==ttype; seq_num==seq; frag_num==frag; payload_len==len; })
      $display("[bird_sequence] WARN randomize failed (t=%0d seq=%0d frag=%0d len=%0d)", ttype, seq, frag, len);
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


//==============================================================================
// 4) DRIVER
//==============================================================================
class bird_driver;

  virtual bird_if vif;
  mailbox #(bird_transaction) seq2drv;

  function new(virtual bird_if vif, mailbox #(bird_transaction) seq2drv);
    this.vif     = vif;
    this.seq2drv = seq2drv;
  endfunction

  task initialize_signals();
    vif.cb.in_vld     <= 1'b0;
    vif.cb.data_in    <= 8'h00;
    vif.cb.cfg        <= 32'h00000000;
    vif.cb.local_rdy  <= 1'b1;
    vif.cb.remote_rdy <= 1'b1;
    @(vif.cb);
  endtask

  task drive_byte(input bit [7:0] byte_value, input bit [31:0] cfg_word);
    vif.cb.in_vld  <= 1'b1;
    vif.cb.data_in <= byte_value;
    vif.cb.cfg     <= cfg_word;
    do begin
      @(vif.cb);
    end while (vif.cb.in_rdy !== 1'b1);
  endtask

  task drive_transaction(input bird_transaction tr);
    bit [31:0] cfg_word;
    cfg_word = tr.get_cfg();
    $display("[bird_driver] Driving transaction cfg=0x%08h", cfg_word);
    foreach (tr.payload[i]) drive_byte(tr.payload[i], cfg_word);
    drive_byte(tr.crc16[15:8], cfg_word);
    drive_byte(tr.crc16[7:0],  cfg_word);
    vif.cb.in_vld  <= 1'b0;
    vif.cb.data_in <= 8'h00;
    vif.cb.cfg     <= 32'h00000000;
    @(vif.cb);
  endtask

  task run();
    bird_transaction tr;
    initialize_signals();
    wait (vif.rst_n === 1'b1);
    @(vif.cb);
    forever begin
      seq2drv.get(tr);
      drive_transaction(tr);
    end
  endtask

endclass : bird_driver


//==============================================================================
// 5) MONITOR
//==============================================================================
class bird_monitor;

  virtual bird_if                vif;
  mailbox #(bird_transaction)    mon2sb_in;
  mailbox #(bit [31:0])          mon2sb_cfg;
  mailbox #(bit [7:0])           mon2sb_local;
  mailbox #(bit [31:0])          mon2sb_remote;

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
  endfunction

  task run();
    wait (vif.rst_n == 1'b1);
    $display("[bird_monitor] reset released, monitoring started");
    fork
      monitor_input();
      monitor_local_output();
      monitor_remote_output();
    join_none
  endtask

  task monitor_input();
    bit [31:0]       raw_cfg;
    bit              traffic_type;
    bit [7:0]        payload_len;
    bit [4:0]        frag_num;
    bit [4:0]        seq_num;
    bit [7:0]        crc_hi, crc_lo;
    bird_transaction tr;

    forever begin
      @(vif.cb);
      if (vif.in_vld && vif.cb.in_rdy) begin
        raw_cfg      = vif.cfg;
        traffic_type = raw_cfg[0];
        payload_len  = raw_cfg[15:8];
        frag_num     = raw_cfg[20:16];
        seq_num      = raw_cfg[28:24];

        tr              = new();
        tr.traffic_type = traffic_type;
        tr.payload_len  = payload_len;
        tr.frag_num     = frag_num;
        tr.seq_num      = seq_num;

        $display("[bird_monitor] input start: cfg=0x%08h type=%s len=%0d frag=%0d seq=%0d",
                 raw_cfg, (traffic_type ? "REMOTE" : "LOCAL"),
                 payload_len, frag_num, seq_num);

        tr.payload = new[payload_len];

        if (payload_len == 0) begin
          crc_hi = vif.data_in;
          capture_next_byte(crc_lo);
        end
        else begin
          tr.payload[0] = vif.data_in;
          for (int i = 1; i < payload_len; i++) capture_next_byte(tr.payload[i]);
          capture_next_byte(crc_hi);
          capture_next_byte(crc_lo);
        end

        tr.crc16 = {crc_hi, crc_lo};
        mon2sb_in.put(tr);
        mon2sb_cfg.put(raw_cfg);

        $display("[bird_monitor] input packet captured: len=%0d crc=0x%04h",
                 payload_len, tr.crc16);
      end
    end
  endtask

  task capture_next_byte(output bit [7:0] b);
    do begin
      @(vif.cb);
    end while (!(vif.in_vld && vif.cb.in_rdy));
    b = vif.data_in;
  endtask

  task monitor_local_output();
    bit [7:0] b;
    forever begin
      @(vif.cb);
      if (vif.cb.local_vld && vif.local_rdy) begin
        b = vif.cb.data_local;
        mon2sb_local.put(b);
        $display("[bird_monitor] local out byte = 0x%02h", b);
      end
    end
  endtask

  task monitor_remote_output();
    bit [31:0] w;
    forever begin
      @(vif.cb);
      if (vif.cb.remote_vld && vif.remote_rdy) begin
        w = vif.cb.data_remote;
        mon2sb_remote.put(w);
        $display("[bird_monitor] remote out word = 0x%08h", w);
      end
    end
  endtask

endclass : bird_monitor


//==============================================================================
// 6) FUNCTIONAL COVERAGE
//==============================================================================
class bird_coverage;

  mailbox #(bird_transaction) in_mb;
  mailbox #(bit [31:0])       cfg_mb;
  mailbox #(bird_transaction) out_mb;
  mailbox #(bit [31:0])       ocfg_mb;

  bit        s_traffic;
  bit [7:0]  s_len;
  bit [4:0]  s_frag;
  bit [4:0]  s_seq;
  bit        s_reserved;

  int unsigned sampled;

  covergroup cg;
    option.per_instance = 1;
    cp_traffic : coverpoint s_traffic { bins loc = {0}; bins rem = {1}; }
    cp_len : coverpoint s_len {
      bins zero={0}; bins one={1}; bins sml={[2:15]};
      bins mid={[16:127]}; bins lrg={[128:254]}; bins max={255};
    }
    cp_frag : coverpoint s_frag { bins zero={0}; bins one={1}; bins mid={[2:30]}; bins max={31}; }
    cp_seq  : coverpoint s_seq  { bins zero={0}; bins one={1}; bins mid={[2:30]}; bins max={31}; }
    cp_reserved : coverpoint s_reserved { bins clean={0}; bins violation={1}; }
    x_traffic_len  : cross cp_traffic, cp_len;
    x_traffic_frag : cross cp_traffic, cp_frag;
  endgroup

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

  task run();
    bird_transaction tr;
    bit [31:0]       raw_cfg;
    forever begin
      in_mb.get(tr);
      cfg_mb.get(raw_cfg);
      s_traffic  = tr.traffic_type;
      s_len      = tr.payload_len;
      s_frag     = tr.frag_num;
      s_seq      = tr.seq_num;
      s_reserved = (raw_cfg[7:1]   != 7'b0) ||
                   (raw_cfg[23:21] != 3'b0) ||
                   (raw_cfg[31:29] != 3'b0);
      cg.sample();
      sampled++;
      out_mb.put(tr);
      ocfg_mb.put(raw_cfg);
    end
  endtask

  function void report();
    $display("============================================================");
    $display("[bird_coverage] FUNCTIONAL COVERAGE REPORT");
    $display("  packets sampled       : %0d", sampled);
    $display("  functional coverage   : %0.2f %%", cg.get_coverage());
    $display("============================================================");
  endfunction

endclass : bird_coverage


//==============================================================================
// 7) SCOREBOARD
//==============================================================================
class bird_scoreboard;

  virtual bird_if             vif;
  mailbox #(bird_transaction) mon2sb_in;
  mailbox #(bit [31:0])       mon2sb_cfg;
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  bit [7:0]  exp_local_q  [$];
  bit [7:0]  obs_local_q  [$];
  bit [31:0] exp_remote_q [$];
  bit [31:0] obs_remote_q [$];

  bit       rem_active;
  bit [4:0] rem_seq;
  typedef struct { bit [4:0] frag_num; bit [7:0] bytes []; } frag_rec_t;
  frag_rec_t rem_frags [$];

  int unsigned in_count;
  int unsigned exp_drop_count;

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

  function bit is_drop_cfg(bit [31:0] raw_cfg);
    if (raw_cfg[7:1]   != 7'b0) return 1'b1;
    if (raw_cfg[23:21] != 3'b0) return 1'b1;
    if (raw_cfg[31:29] != 3'b0) return 1'b1;
    if (raw_cfg[28:24] == 5'd0) return 1'b1;
    if (raw_cfg[20:16] == 5'd0) return 1'b1;
    if (raw_cfg[15:8]  == 8'd0) return 1'b1;
    return 1'b0;
  endfunction

  task run();
    fork
      process_inputs();
      collect_local_outputs();
      collect_remote_outputs();
    join_none
  endtask

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

  task predict_local(bird_transaction tr);
    foreach (tr.payload[i]) exp_local_q.push_back(tr.payload[i]);
    exp_local_q.push_back(tr.crc16[15:8]);
    exp_local_q.push_back(tr.crc16[7:0]);
  endtask

  task predict_remote(bird_transaction tr, bit [4:0] seq_num, bit [4:0] frag_num);
    if (!rem_active) begin
      start_remote_accum(tr, seq_num);
    end
    else if (seq_num != rem_seq) begin
      exp_drop_count++;
      $display("[bird_scoreboard] DROP (remote seq mismatch arr=%0d open=%0d) -> exp_drop=%0d",
               seq_num, rem_seq, exp_drop_count);
      rem_active = 1'b0;
      rem_frags.delete();
      start_remote_accum(tr, seq_num);
    end
    else begin
      add_remote_fragment(tr, frag_num);
    end
    // Spec: reassemble & output as soon as fragments 1..N are all present.
    if (rem_active && remote_is_contiguous())
      finalize_remote();
  endtask

  task start_remote_accum(bird_transaction tr, bit [4:0] seq_num);
    rem_active = 1'b1;
    rem_seq    = seq_num;
    rem_frags.delete();
    add_remote_fragment(tr, tr.frag_num);
  endtask

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
        if ((i + j) < slen) word[7:0] = stream[i + j];
      end
      exp_remote_q.push_back(word);
    end
    $display("[bird_scoreboard] REMOTE finalize seq=%0d frags=%0d len=%0d crc=0x%04h",
             rem_seq, rem_frags.size(), total, new_crc);
    rem_active = 1'b0;
    rem_frags.delete();
  endtask

  function bit [15:0] calc_crc16(bit [7:0] data []);
    bit [15:0] crc = 16'hFFFF;
    foreach (data[i]) begin
      crc = crc ^ (data[i] << 8);
      for (int b = 0; b < 8; b++)
        crc = crc[15] ? (crc << 1) ^ 16'h1021 : (crc << 1);
    end
    return crc;
  endfunction

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

  task wrap_up();
    bit [15:0]   actual_drop;
    int unsigned local_pass = 0, local_fail = 0;
    int unsigned remote_pass = 0, remote_fail = 0;
    int          n;
    bit          verdict_ok;

    if (rem_active) begin
      if (remote_is_contiguous()) finalize_remote();
      else begin
        exp_drop_count++;
        $display("[bird_scoreboard] DROP (remote missing fragment seq=%0d) -> exp_drop=%0d",
                 rem_seq, exp_drop_count);
        rem_active = 1'b0;
        rem_frags.delete();
      end
    end

    n = (exp_local_q.size() > obs_local_q.size()) ? exp_local_q.size() : obs_local_q.size();
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

    n = (exp_remote_q.size() > obs_remote_q.size()) ? exp_remote_q.size() : obs_remote_q.size();
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


//==============================================================================
// 8) ENVIRONMENT (coverage interposed on monitor -> scoreboard input path)
//==============================================================================
class bird_env;

  virtual bird_if vif;
  int             number_of_transactions;
  int             drain_cycles;

  bird_sequence   seq;
  bird_driver     drv;
  bird_monitor    mon;
  bird_coverage   cov;
  bird_scoreboard sb;

  mailbox #(bird_transaction) seq2drv;
  mailbox #(bird_transaction) mon2cov_in;
  mailbox #(bit [31:0])       mon2cov_cfg;
  mailbox #(bird_transaction) cov2sb_in;
  mailbox #(bit [31:0])       cov2sb_cfg;
  mailbox #(bit [7:0])        mon2sb_local;
  mailbox #(bit [31:0])       mon2sb_remote;

  bit built;

  function new(virtual bird_if vif, int number_of_transactions = 5);
    this.vif                     = vif;
    this.number_of_transactions  = number_of_transactions;
    this.drain_cycles            = number_of_transactions * 300;
    this.built                   = 1'b0;
  endfunction

  function void build();
    seq2drv       = new();
    mon2cov_in    = new();
    mon2cov_cfg   = new();
    cov2sb_in     = new();
    cov2sb_cfg    = new();
    mon2sb_local  = new();
    mon2sb_remote = new();

    seq = new(seq2drv, number_of_transactions);
    drv = new(vif, seq2drv);
    mon = new(vif, mon2cov_in, mon2cov_cfg, mon2sb_local, mon2sb_remote);
    cov = new(mon2cov_in, mon2cov_cfg, cov2sb_in, cov2sb_cfg);
    sb  = new(vif, cov2sb_in, cov2sb_cfg, mon2sb_local, mon2sb_remote);

    built = 1'b1;
    $display("[bird_env] build complete: %0d transactions, drain=%0d cycles",
             number_of_transactions, drain_cycles);
  endfunction

  task run();
    if (!built) build();
    wait (vif.rst_n == 1'b1);
    @(vif.cb);
    fork
      drv.run();
      mon.run();
      cov.run();
      sb.run();
    join_none
    seq.run();
    repeat (drain_cycles) @(vif.cb);
    wrap_up();
  endtask

  task wrap_up();
    sb.wrap_up();
    cov.report();
    $display("[bird_env] environment run complete");
  endtask

endclass : bird_env


//==============================================================================
// 9) TEST
//==============================================================================
class bird_test;

  virtual bird_if vif;
  bird_env        env;
  int             num_transactions;

  function new(virtual bird_if vif, int num_transactions = 10);
    this.vif              = vif;
    this.num_transactions = num_transactions;
  endfunction

  task run();
    $display("[bird_test] START - BIRD random traffic test (%0d transactions)",
             num_transactions);
    env = new(vif, num_transactions);
    env.build();
    env.run();
    $display("[bird_test] DONE - see end-of-test report above");
  endtask

endclass : bird_test


//==============================================================================
// 10) TOP MODULE
//==============================================================================
module bird_top;

  bit clk;
  initial clk = 1'b0;
  always #5 clk = ~clk;

  bird_if vif (clk);

  // DUT (module "bird" lives in the Design pane on EDA Playground)
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

  bird_test test;
  int       ntx;

  initial begin
    if (!$value$plusargs("NTX=%d", ntx)) ntx = 10;
    test = new(vif, ntx);
    test.run();
    $finish;
  end

  initial begin
    #5_000_000;
    $display("[bird_top] TIMEOUT - forcing $finish");
    $finish;
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, bird_top);
  end

endmodule : bird_top
