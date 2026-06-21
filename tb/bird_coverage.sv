//==============================================================================
// File   : bird_coverage.sv
// Purpose: Requirement-oriented functional coverage for BIRD.
//==============================================================================

`ifndef BIRD_COVERAGE_SV
`define BIRD_COVERAGE_SV

class bird_coverage;

  mailbox #(bird_transaction) in_mb;
  mailbox #(bit [31:0])       cfg_mb;
  mailbox #(bird_transaction) out_mb;
  mailbox #(bit [31:0])       ocfg_mb;
  virtual bird_if             vif;

  bit       s_traffic;
  bit [7:0] s_len;
  bit [4:0] s_frag;
  bit [4:0] s_seq;
  bit       s_rsv_7_1;
  bit       s_rsv_23_21;
  bit       s_rsv_31_29;

  bit       s_prev_traffic;
  bit       s_transition_valid;
  bit [1:0] s_remote_order;

  bit       s_in_bp;
  bit       s_local_bp;
  bit       s_remote_bp;
  bit [1:0] s_drop_event;

  bit       have_prev_packet;
  bit       have_prev_remote;
  bit [4:0] prev_remote_seq;
  bit [4:0] prev_remote_frag;

  int unsigned packets_sampled;
  int unsigned cycles_sampled;

  // Weight 4: most specification requirements concern packet/config cases.
  covergroup cg_input;
    option.per_instance = 1;
    option.weight       = 4;

    cp_traffic : coverpoint s_traffic {
      bins loc  = {0};
      bins remote = {1};
    }

    cp_len : coverpoint s_len {
      bins invalid_zero = {0};
      bins minimum      = {1};
      bins sml        = {[2:15]};
      bins med       = {[16:127]};
      bins lrg        = {[128:254]};
      bins maximum      = {255};
    }

    cp_frag : coverpoint s_frag {
      bins invalid_zero = {0};
      bins first        = {1};
      bins middle       = {[2:30]};
      bins maximum      = {31};
    }

    cp_seq : coverpoint s_seq {
      bins invalid_zero = {0};
      bins minimum      = {1};
      bins middle       = {[2:30]};
      bins maximum      = {31};
    }

    cp_rsv_7_1 : coverpoint s_rsv_7_1 {
      bins clean = {0};
      bins set   = {1};
    }

    cp_rsv_23_21 : coverpoint s_rsv_23_21 {
      bins clean = {0};
      bins set   = {1};
    }

    cp_rsv_31_29 : coverpoint s_rsv_31_29 {
      bins clean = {0};
      bins set   = {1};
    }

    // iff prevents the first packet from producing a fake transition.
    cp_traffic_transition : coverpoint {s_prev_traffic, s_traffic}
                            iff (s_transition_valid) {
      bins local_to_local   = {2'b00};
      bins local_to_remote  = {2'b01};
      bins remote_to_local  = {2'b10};
      bins remote_to_remote = {2'b11};
    }

    cp_remote_order : coverpoint s_remote_order iff (s_traffic) {
      bins first_or_new_seq = {0};
      bins ascending        = {1};
      bins descending       = {2};
      bins duplicate        = {3};
    }

    x_traffic_len  : cross cp_traffic, cp_len;
    x_traffic_frag : cross cp_traffic, cp_frag;
  endgroup

  // Weight 2: valid/ready behavior on the three interfaces.
  covergroup cg_protocol;
    option.per_instance = 1;
    option.weight       = 2;

    cp_input_backpressure : coverpoint s_in_bp {
      bins absent  = {0};
      bins present = {1};
    }

    cp_local_backpressure : coverpoint s_local_bp {
      bins absent  = {0};
      bins present = {1};
    }

    cp_remote_backpressure : coverpoint s_remote_bp {
      bins absent  = {0};
      bins present = {1};
    }
  endgroup

  // Weight 1: hold, increment and true ffff->0000 wrap behavior.
  covergroup cg_counter;
    option.per_instance = 1;
    option.weight       = 1;

    cp_drop_event : coverpoint s_drop_event {
      bins unchanged = {0};
      bins increment = {1};
      ignore_bins wrap_unreachable = {2};
      illegal_bins unexpected_jump = {3};
    }
  endgroup

  function new(mailbox #(bird_transaction) in_mb,
               mailbox #(bit [31:0])       cfg_mb,
               mailbox #(bird_transaction) out_mb,
               mailbox #(bit [31:0])       ocfg_mb,
               virtual bird_if             vif);
    this.in_mb  = in_mb;
    this.cfg_mb = cfg_mb;
    this.out_mb = out_mb;
    this.ocfg_mb = ocfg_mb;
    this.vif     = vif;

    have_prev_packet = 0;
    have_prev_remote = 0;
    packets_sampled  = 0;
    cycles_sampled   = 0;

    cg_input    = new();
    cg_protocol = new();
    cg_counter  = new();
  endfunction

  task sample_protocol_and_counter();
    bit [15:0] previous_drop;
    bit [15:0] current_drop;

    @(vif.cb);
    previous_drop = vif.cb.drop_cnt;

    forever begin
      @(vif.cb);

      s_in_bp     = vif.in_vld     && !vif.cb.in_rdy;
      s_local_bp  = vif.cb.local_vld  && !vif.local_rdy;
      s_remote_bp = vif.cb.remote_vld && !vif.remote_rdy;
      cg_protocol.sample();

      current_drop = vif.cb.drop_cnt;
      if (current_drop == previous_drop)
        s_drop_event = 0;
      else if (previous_drop == 16'hffff && current_drop == 16'h0000)
        s_drop_event = 2;
      else if (current_drop == previous_drop + 16'd1)
        s_drop_event = 1;
      else
        s_drop_event = 3;

      cg_counter.sample();
      previous_drop = current_drop;
      cycles_sampled++;
    end
  endtask

  task run();
    bird_transaction tr;
    bit [31:0] raw_cfg;

    fork
      sample_protocol_and_counter();
    join_none

    forever begin
      in_mb.get(tr);
      cfg_mb.get(raw_cfg);

      s_traffic   = tr.traffic_type;
      s_len       = tr.payload_len;
      s_frag      = tr.frag_num;
      s_seq       = tr.seq_num;
      s_rsv_7_1   = |raw_cfg[7:1];
      s_rsv_23_21 = |raw_cfg[23:21];
      s_rsv_31_29 = |raw_cfg[31:29];

      s_transition_valid = have_prev_packet;

      if (s_traffic) begin
        if (!have_prev_remote || s_seq != prev_remote_seq)
          s_remote_order = 0;
        else if (s_frag > prev_remote_frag)
          s_remote_order = 1;
        else if (s_frag < prev_remote_frag)
          s_remote_order = 2;
        else
          s_remote_order = 3;
      end
      else begin
        s_remote_order   = 0;
        have_prev_remote = 0;
      end

      cg_input.sample();
      packets_sampled++;

      s_prev_traffic   = s_traffic;
      have_prev_packet = 1;

      if (s_traffic) begin
        have_prev_remote = 1;
        prev_remote_seq  = s_seq;
        prev_remote_frag = s_frag;
      end

      out_mb.put(tr);
      ocfg_mb.put(raw_cfg);
    end
  endtask

  function void report();
    real input_cov;
    real protocol_cov;
    real counter_cov;
    real overall_cov;

    input_cov    = cg_input.get_inst_coverage();
    protocol_cov = cg_protocol.get_inst_coverage();
    counter_cov  = cg_counter.get_inst_coverage();
    overall_cov  = ((4.0 * input_cov) +
                    (2.0 * protocol_cov) + counter_cov) / 7.0;

    $display("============================================================");
    $display("[bird_coverage] FUNCTIONAL COVERAGE REPORT");
    $display("  packets sampled       : %0d", packets_sampled);
    $display("  cycles sampled        : %0d", cycles_sampled);
    $display("  input/scenario        : %0.2f %%", input_cov);
    $display("  protocol/backpressure : %0.2f %%", protocol_cov);
    $display("  drop counter behavior : %0.2f %%", counter_cov);
    $display("  weighted overall      : %0.2f %%", overall_cov);
    $display("============================================================");
  endfunction

endclass : bird_coverage

`endif
