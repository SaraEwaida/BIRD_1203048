class bird_monitor;

  // Class properties
  virtual bird_if                vif;            // pin-level interface handle
  mailbox #(bird_transaction)    mon2sb_in;      // reconstructed input packets
  mailbox #(bit [31:0])          mon2sb_cfg;     // raw cfg words (for the SB)
  mailbox #(bit [7:0])           mon2sb_local;   // observed local output bytes
  mailbox #(bit [31:0])          mon2sb_remote;  // observed remote output words

  // Constructor : store the interface handle and all scoreboard mailboxes.
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

  // run : wait for reset release, then start the three observers in parallel.
  // fork...join_none lets run() return immediately while the three
  // forever loops keep monitoring for the whole simulation.
  
  task run();
    // rst_n is asynchronous, so it is read directly, not through vif.cb.
    wait (vif.rst_n == 1'b1);

    $display("[bird_monitor] reset released, monitoring started");

    fork
      monitor_input();
      monitor_local_output();
      monitor_remote_output();
    join_none
  endtask

  // monitor_input : reconstruct each input packet from the byte stream.
  //
  //   On the first accepted byte of a packet, the raw cfg is sampled and
  //   decoded. PAYLOAD_LEN payload bytes are then collected, followed by the
  //   CRC high byte and CRC low byte (same order the driver sends them).
  //   Each accepted byte is one clock edge where in_vld && in_rdy are high.
  task monitor_input();
    bit [31:0]       raw_cfg;
    bit              traffic_type;
    bit [7:0]        payload_len;
    bit [4:0]        frag_num;
    bit [4:0]        seq_num;
    bit [7:0]        crc_hi, crc_lo;
    bird_transaction tr;

    forever begin
      // Wait for the next accepted input byte (start of a new packet).
      @(vif.cb);
      if (vif.cb.in_vld && vif.cb.in_rdy) begin

        // Sample the raw cfg on the first payload byte of the packet.
        raw_cfg      = vif.cb.cfg;
        traffic_type = raw_cfg[0];
        payload_len  = raw_cfg[15:8];
        frag_num     = raw_cfg[20:16];
        seq_num      = raw_cfg[28:24];

        // Build the reconstructed transaction from the decoded cfg fields.
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
          // Byte currently on the bus is the CRC high byte.
          crc_hi = vif.cb.data_in;
          // Next accepted byte is the CRC low byte.
          capture_next_byte(crc_lo);
        end
        else begin
          // First payload byte is the one already on the bus this cycle.
          tr.payload[0] = vif.cb.data_in;
          // Remaining payload bytes.
          for (int i = 1; i < payload_len; i++) begin
            capture_next_byte(tr.payload[i]);
          end
          // Then the two CRC bytes (high first, then low).
          capture_next_byte(crc_hi);
          capture_next_byte(crc_lo);
        end

        tr.crc16 = {crc_hi, crc_lo};

        // Forward the reconstructed packet and the raw cfg to the scoreboard.
        mon2sb_in.put(tr);
        mon2sb_cfg.put(raw_cfg);

        $display("[bird_monitor] input packet captured: len=%0d crc=0x%04h",
                 payload_len, tr.crc16);
      end
    end
  endtask


  // capture_next_byte : advance to the next clock edge where in_vld && in_rdy are both high and return the accepted data_in byte. This mirrors the driver, which holds a byte until it is accepted.

  task capture_next_byte(output bit [7:0] b);
    do begin
      @(vif.cb);
    end while (!(vif.cb.in_vld && vif.cb.in_rdy));
    b = vif.cb.data_in;
  endtask

  // monitor_local_output : sample one local output byte per accepted beat.
  //   A beat is accepted when local_vld && local_rdy are both high. local_rdy is driven by the driver and is only SAMPLED here.
  task monitor_local_output();
    bit [7:0] b;
    forever begin
      @(vif.cb);
      if (vif.cb.local_vld && vif.cb.local_rdy) begin
        b = vif.cb.data_local;       // SAMPLE only, never drive local_rdy
        mon2sb_local.put(b);
        $display("[bird_monitor] local out byte = 0x%02h", b);
      end
    end
  endtask

  // monitor_remote_output : sample one 32-bit remote output word per accepted
  //   beat (remote_vld && remote_rdy both high). remote_rdy is driven by the driver and is only SAMPLED here.
  task monitor_remote_output();
    bit [31:0] w;
    forever begin
      @(vif.cb);
      if (vif.cb.remote_vld && vif.cb.remote_rdy) begin
        w = vif.cb.data_remote;      // SAMPLE only, never drive remote_rdy
        mon2sb_remote.put(w);
        $display("[bird_monitor] remote out word = 0x%08h", w);
      end
    end
  endtask

endclass : bird_monitor