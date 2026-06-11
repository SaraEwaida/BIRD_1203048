//==============================================================================
// File   : bird_transaction.sv
// Project: BIRD - Birzeit Integrated Router Design  (ENCS5337)
// Author : Student 1 (Interface & Data)
// Purpose: Transaction (packet/fragment) class passed between the driver,
//          monitor, scoreboard and coverage. Holds the cfg fields, the
//          payload bytes and the CRC16.
//
// Style follows the class slides (Tumbush/Spear, Chapter 6): rand fields,
// named constraint blocks (so invalid stimulus can be produced by turning a
// constraint off with constraint_mode(0)), new(), display(), copy().
//
// cfg word layout (BIRD spec, Section 5):
//   [0]      TRAFFIC_TYPE  (0 = local, 1 = remote)
//   [7:1]    Reserved      (must be 0)
//   [15:8]   PAYLOAD_LEN   (1..255)
//   [20:16]  FRAG_NUM      (1..31)
//   [23:21]  Reserved      (must be 0)
//   [28:24]  SEQ_NUM       (1..31, 0 invalid)
//   [31:29]  Reserved      (must be 0)
//==============================================================================

class bird_transaction;

  //--------------------------------------------------------------------------
  // cfg fields (randomized)
  //--------------------------------------------------------------------------
  rand bit        traffic_type;   // cfg[0]    : 0 = local, 1 = remote
  rand bit [7:0]  payload_len;    // cfg[15:8] : 1..255 bytes
  rand bit [4:0]  frag_num;       // cfg[20:16]: 1..31
  rand bit [4:0]  seq_num;        // cfg[28:24]: 1..31

  //--------------------------------------------------------------------------
  // Packet data
  //--------------------------------------------------------------------------
  rand bit [7:0]  payload [];     // payload bytes, size == payload_len
  bit  [15:0]     crc16;          // CRC16 over the payload (computed, not rand)

  //--------------------------------------------------------------------------
  // Named constraint blocks
  //   All are ON by default => randomize() produces a LEGAL packet.
  //   To create an illegal packet that BIRD must drop, turn a block off, e.g.
  //       tr.c_seq_valid.constraint_mode(0);
  //       assert(tr.randomize() with { seq_num == 0; });   // forces a drop
  //--------------------------------------------------------------------------
  constraint c_seq_valid  { seq_num  inside {[1:31]}; }        // 0 is invalid
  constraint c_frag_valid { frag_num inside {[1:31]}; }        // 0 is invalid
  constraint c_len_valid  { payload_len inside {[1:255]}; }    // 1..255

  // Local traffic is a single fragment, so FRAG_NUM must be 1 (spec Section 6).
  constraint c_local_frag { (traffic_type == 1'b0) -> (frag_num == 1); }

  // Payload array size always tracks PAYLOAD_LEN.
  constraint c_payload_size { payload.size() == payload_len; }

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new();
    // nothing required; payload is sized by the size constraint after randomize
  endfunction

  //--------------------------------------------------------------------------
  // post_randomize : compute the CRC after fields/payload are chosen
  //--------------------------------------------------------------------------
  function void post_randomize();
    crc16 = calc_crc16();
  endfunction

  //--------------------------------------------------------------------------
  // get_cfg : pack the fields into the 32-bit cfg word.
  //           Reserved bits are left at 0 (legal). To test a reserved-bit
  //           drop, set bits in the returned word from the test/driver.
  //--------------------------------------------------------------------------
  function bit [31:0] get_cfg();
    bit [31:0] c;
    c            = '0;
    c[0]         = traffic_type;
    c[15:8]      = payload_len;
    c[20:16]     = frag_num;
    c[28:24]     = seq_num;
    return c;
  endfunction

  //--------------------------------------------------------------------------
  // calc_crc16 : CRC-16-CCITT (poly 0x1021, init 0xFFFF) over the payload.
  //
  //   NOTE: The exact CRC the DUT uses is defined by the design on
  //   edaplayground. Before relying on this for checking, the team must
  //   confirm the polynomial / init / bit order against the DUT and adjust
  //   the three marked values if they differ.
  //--------------------------------------------------------------------------
  function bit [15:0] calc_crc16();
    bit [15:0] crc;
    crc = 16'hFFFF;                       // init value  <-- confirm vs DUT
    foreach (payload[i]) begin
      crc = crc ^ (payload[i] << 8);
      for (int b = 0; b < 8; b++) begin
        if (crc[15])
          crc = (crc << 1) ^ 16'h1021;    // polynomial  <-- confirm vs DUT
        else
          crc = (crc << 1);
      end
    end
    return crc;
  endfunction

  //--------------------------------------------------------------------------
  // copy : return a deep copy of this transaction (payload is its own array)
  //--------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------
  // compare : 1 if all fields and the payload match, else 0 (used by scoreboard)
  //--------------------------------------------------------------------------
  function bit compare(bird_transaction t);
    if (t == null)                       return 0;
    if (traffic_type != t.traffic_type)  return 0;
    if (payload_len  != t.payload_len)   return 0;
    if (frag_num     != t.frag_num)      return 0;
    if (seq_num      != t.seq_num)       return 0;
    if (crc16        != t.crc16)         return 0;
    if (payload.size() != t.payload.size()) return 0;
    foreach (payload[i])
      if (payload[i] != t.payload[i])    return 0;
    return 1;
  endfunction

  //--------------------------------------------------------------------------
  // display : print the transaction (slide-style print_all)
  //--------------------------------------------------------------------------
  function void display(string prefix = "");
    $display("%s BIRD_TX: type=%s seq=%0d frag=%0d len=%0d crc=0x%04h cfg=0x%08h",
             prefix,
             (traffic_type ? "REMOTE" : "LOCAL"),
             seq_num, frag_num, payload_len, crc16, get_cfg());
    $write("%s   payload =", prefix);
    foreach (payload[i]) $write(" %02h", payload[i]);
    $display("");
  endfunction

endclass : bird_transaction
