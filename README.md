# BIRD_1203048 — Birzeit Integrated Router Design (Verification)

ENCS5337 — Chip Design Verification, Birzeit University.
Class-based SystemVerilog verification environment (no UVM) for the instructor-provided **BIRD** packet router DUT: test plan, testbench, directed tests, scoreboard, functional + code coverage.

> The DUT (`design/bird.sv`) is instructor-provided and verified **unchanged**.

## Repository structure
- `design/`            — bird.sv (instructor DUT, do not modify)
- `tb/`                — interface, transaction, driver, monitor, scoreboard, coverage, env, test, top
- `tests/`             — 8 directed tests + bird_tests_top.sv (select with +TEST=<tag>)
- `sim/`               — Makefile, run.sh, run_my_coverage.sh, bird.f, edaplayground/
- `test_plan/`         — test_plan.md
- `docs/`              — verification_report.md
- `reports/coverage/`  — committed URG code + functional coverage report

## How to run

### EDA Playground (no server)
1. Design pane: paste design/bird.sv
2. Testbench pane: paste sim/edaplayground/bird_tb_single_file.sv
3. Tools: Synopsys VCS, language SystemVerilog, then Run.

### Synopsys EDA server (Birzeit) — full coverage
    ssh -L 6018:localhost:6018 st18@176.119.254.181   # enter password manually; never stored
    cd ~/BIRD_1203048/sim
    chmod +x run_my_coverage.sh
    ./run_my_coverage.sh      # compiles + runs all 8 tests + builds the URG report
Report: reports/coverage/dashboard.html  (text summary: reports/coverage/dashboard.txt)

## Results
- Functional (covergroup) coverage: 77.4% (input/scenario covergroup ~90%, per-instance 85%).
- Code coverage: 69.95% (line 71.5, cond 63.4, toggle 54.7, FSM 80, branch 72.7).
- Scoreboard finds 3 DUT spec violations (see docs/verification_report.md):
  - BUG-1: local packets with SEQ_NUM != 1 are wrongly dropped.
  - BUG-2: remote reassembly indexes by SEQ_NUM instead of FRAG_NUM.
  - BUG-3: drop_cnt does not match the one-per-dropped-packet rule.
- FINAL RESULT: FAIL is correct — it reflects the real DUT bugs, not testbench errors.

## Team
Sara Ewaida, Maysam Abu Eid, Veronica Wakileh, Dana Taher.

## Notes
Server passwords are never stored in this repo. VCS build artifacts (sim/csrc, simv*, *.vdb, logs) are git-ignored.
