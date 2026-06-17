// BIRD test list - Student 4: Maysam Abu Eid - 1220675
// Project: BIRD - Birzeit Integrated Router Design (ENCS5337)
//
// VCS filelist for the tests directory. Compile the tb classes first
// (sim/bird.f), then add this file with -f ../tests/test_list.f. Select the
// active test in bird_top via +TEST=<tag>.
//
//   +TEST tag             test class                      covers (test plan)
//   legal                 bird_test_legal                 TP-01, TP-04, TP-05
//   remote                bird_test_remote                TP-02, TP-03
//   drop_seq0             bird_test_drop_seq0             TP-07
//   drop_frag0            bird_test_drop_frag0            TP-08
//   drop_len0             bird_test_drop_len0             TP-06
//   drop_local_bad        bird_test_drop_local_bad        TP-10
//   remote_seqmismatch    bird_test_remote_seqmismatch    TP-11

+incdir+../tests

../tests/bird_seq_lib.sv
../tests/bird_base_test.sv
../tests/bird_test_legal.sv
../tests/bird_test_remote.sv
../tests/bird_test_drop_seq0.sv
../tests/bird_test_drop_frag0.sv
../tests/bird_test_drop_len0.sv
../tests/bird_test_drop_local_bad.sv
../tests/bird_test_remote_seqmismatch.sv
