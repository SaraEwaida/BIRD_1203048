//==============================================================================
// File   : bird_driver.sv
// Author : Dana Taher - 1221240
// Purpose: Drive BIRD input transactions and deterministic output backpressure.
//==============================================================================

class bird_driver;

  virtual bird_if             vif;
  mailbox #(bird_transaction) seq2drv;
  bit                         enable_backpressure;

  function new(virtual bird_if             vif,
               mailbox #(bird_transaction) seq2drv,
               bit                         enable_backpressure = 1);
    this.vif                 = vif;
    this.seq2drv             = seq2drv;
    this.enable_backpressure = enable_backpressure;
  endfunction

  task initialize_signals();
    vif.cb.in_vld     <= 0;
    vif.cb.data_in    <= '0;
    vif.cb.cfg        <= '0;
    vif.cb.local_rdy  <= 1;
    vif.cb.remote_rdy <= 1;
    @(vif.cb);
  endtask

  // Ready is low for several consecutive cycles so valid output is forced to
  // remain stable. The pattern is deterministic and reproducible.
  task drive_output_ready();
    int unsigned cycle = 0;

    forever begin
      @(vif.cb);
      if (enable_backpressure) begin
        vif.cb.local_rdy  <= !((cycle % 10) inside {[2:4]});
        vif.cb.remote_rdy <= !((cycle % 12) inside {[6:8]});
      end
      else begin
        vif.cb.local_rdy  <= 1;
        vif.cb.remote_rdy <= 1;
      end
      cycle++;
    end
  endtask

  task drive_byte(input bit [7:0] byte_value,
                  input bit [31:0] cfg_word);
    vif.cb.in_vld  <= 1;
    vif.cb.data_in <= byte_value;
    vif.cb.cfg     <= cfg_word;

    do begin
      @(vif.cb);
    end while (vif.cb.in_rdy !== 1'b1);
  endtask

  task drive_transaction(input bird_transaction tr);
    bit [31:0] cfg_word = tr.get_cfg();

    $display("[bird_driver] Driving transaction cfg=0x%08h", cfg_word);

    foreach (tr.payload[i])
      drive_byte(tr.payload[i], cfg_word);

    drive_byte(tr.crc16[15:8], cfg_word);
    drive_byte(tr.crc16[7:0],  cfg_word);

    vif.cb.in_vld  <= 0;
    vif.cb.data_in <= '0;
    vif.cb.cfg     <= '0;
    @(vif.cb);
  endtask

  task drive_input_stream();
    bird_transaction tr;

    forever begin
      seq2drv.get(tr);
      drive_transaction(tr);
    end
  endtask

  task run();
    initialize_signals();
    wait (vif.rst_n === 1'b1);
    @(vif.cb);

    fork
      drive_input_stream();
      drive_output_ready();
    join
  endtask

endclass : bird_driver
