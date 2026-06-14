// Author: Dana Taher - 1221240

// File: bird_driver.sv
// Purpose: Drive BIRD input transactions using the valid/ready handshake.



class bird_driver;

  virtual bird_if vif;
  mailbox #(bird_transaction) seq2drv;

  // Constructor receives the interface and the sequence-to-driver mailbox.
  function new(virtual bird_if vif,
               mailbox #(bird_transaction) seq2drv);
    this.vif     = vif;
    this.seq2drv = seq2drv;
  endfunction

  // Initialize all signals driven by the testbench.
  task initialize_signals();
    vif.cb.in_vld     <= 1'b0;
    vif.cb.data_in    <= 8'h00;
    vif.cb.cfg        <= 32'h00000000;
    vif.cb.local_rdy  <= 1'b1;
    vif.cb.remote_rdy <= 1'b1;
    @(vif.cb);
  endtask

  // Drive one byte and hold all input signals stable during backpressure.
  task drive_byte(input bit [7:0]  byte_value,
                  input bit [31:0] cfg_word);
    vif.cb.in_vld  <= 1'b1;
    vif.cb.data_in <= byte_value;
    vif.cb.cfg     <= cfg_word;

    // A byte transfers only on a clock edge where in_vld and in_rdy are 1.
    do begin
      @(vif.cb);
    end while (vif.cb.in_rdy !== 1'b1);
  endtask

  // Drive the payload bytes followed by the two CRC16 bytes.
  task drive_transaction(input bird_transaction tr);
    bit [31:0] cfg_word;

    cfg_word = tr.get_cfg();
    $display("[bird_driver] Driving transaction cfg=0x%08h", cfg_word);

    foreach (tr.payload[i]) begin
      drive_byte(tr.payload[i], cfg_word);
    end

    // The specification does not state the CRC byte order. High byte is sent
    // first, then low byte; confirm this order with the DUT if needed.
    drive_byte(tr.crc16[15:8], cfg_word);
    drive_byte(tr.crc16[7:0],  cfg_word);

    // Leave one idle cycle between transactions.
    vif.cb.in_vld  <= 1'b0;
    vif.cb.data_in <= 8'h00;
    vif.cb.cfg     <= 32'h00000000;
    @(vif.cb);
  endtask

  // Receive transactions from the sequence and drive them continuously.
  task run();
    bird_transaction tr;

    initialize_signals();

    // rst_n is asynchronous and is accessed directly, not through vif.cb.
    wait (vif.rst_n === 1'b1);
    @(vif.cb);

    forever begin
      seq2drv.get(tr);
      drive_transaction(tr);
    end
  endtask

endclass : bird_driver
