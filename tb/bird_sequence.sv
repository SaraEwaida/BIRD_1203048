// Author: Dana Taher - 1221240
// File: bird_sequence.sv
// Purpose: Generate legal random BIRD transactions for the driver.



class bird_sequence;

  mailbox #(bird_transaction) seq2drv;
  int number_of_transactions;

  // By default, generate five legal random transactions.
  function new(mailbox #(bird_transaction) seq2drv,
               int number_of_transactions = 5);
    this.seq2drv                = seq2drv;
    this.number_of_transactions = number_of_transactions;
  endfunction

  // Generate transactions and send their handles to the driver mailbox.
  task run();
    bird_transaction tr;

    for (int i = 0; i < number_of_transactions; i++) begin
      tr = new();

      if (tr.randomize()) begin
        tr.display("[bird_sequence]");
        seq2drv.put(tr);
      end
      else begin
        $display("[bird_sequence] ERROR: transaction randomization failed");
      end
    end
  endtask

endclass : bird_sequence
