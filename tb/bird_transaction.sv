//==============================================================================
// File   : bird_transaction.sv
// Project: BIRD - Birzeit Integrated Router Design (ENCS5337)
// Purpose: Packet/fragment transaction shared by sequence, driver and monitors.
//==============================================================================

class bird_transaction;

  rand bit        traffic_type;
  rand bit [7:0]  payload_len;
  rand bit [4:0]  frag_num;
  rand bit [4:0]  seq_num;
  rand bit [7:0]  payload [];
  bit  [15:0]     crc16;

  // Allows directed tests to set reserved cfg bits without changing the
  // normal randomized fields. The driver must always call get_cfg().
  bit        use_cfg_override;
  bit [31:0] cfg_override;

  constraint c_seq_valid    { seq_num inside {[1:31]}; }
  constraint c_frag_valid   { frag_num inside {[1:31]}; }
  constraint c_len_valid    { payload_len inside {[1:255]}; }
  constraint c_local_frag   { (traffic_type == 0) -> (frag_num == 1); }
  constraint c_payload_size { payload.size() == payload_len; }

  function new();
    use_cfg_override = 0;
    cfg_override     = '0;
  endfunction

  function void post_randomize();
    crc16 = calc_crc16();
  endfunction

  function bit [31:0] get_cfg();
    bit [31:0] c;

    if (use_cfg_override)
      return cfg_override;

    c        = '0;
    c[0]     = traffic_type;
    c[15:8]  = payload_len;
    c[20:16] = frag_num;
    c[28:24] = seq_num;
    return c;
  endfunction

  function bit [15:0] calc_crc16();
    bit [15:0] crc = 16'hffff;

    foreach (payload[i]) begin
      crc ^= (payload[i] << 8);
      for (int b = 0; b < 8; b++)
        crc = crc[15] ? (crc << 1) ^ 16'h1021 : (crc << 1);
    end

    return crc;
  endfunction

  function bird_transaction copy();
    bird_transaction t = new();

    t.traffic_type    = traffic_type;
    t.payload_len     = payload_len;
    t.frag_num        = frag_num;
    t.seq_num         = seq_num;
    t.crc16           = crc16;
    t.use_cfg_override = use_cfg_override;
    t.cfg_override     = cfg_override;
    t.payload          = new[payload.size()];
    foreach (payload[i])
      t.payload[i] = payload[i];

    return t;
  endfunction

  function bit compare(bird_transaction t);
    if (t == null)                         return 0;
    if (traffic_type != t.traffic_type)    return 0;
    if (payload_len  != t.payload_len)     return 0;
    if (frag_num     != t.frag_num)        return 0;
    if (seq_num      != t.seq_num)         return 0;
    if (crc16        != t.crc16)           return 0;
    if (payload.size() != t.payload.size()) return 0;
    foreach (payload[i])
      if (payload[i] != t.payload[i])      return 0;
    return 1;
  endfunction

  function void display(string prefix = "");
    $display("%s BIRD_TX: type=%s seq=%0d frag=%0d len=%0d crc=0x%04h cfg=0x%08h",
             prefix, traffic_type ? "REMOTE" : "LOCAL", seq_num, frag_num,
             payload_len, crc16, get_cfg());
  endfunction

endclass : bird_transaction
