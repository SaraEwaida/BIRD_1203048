# BIRD — Functional Verification Report

**Project:** BIRD (Birzeit Integrated Router Design)
**Course:** ENCS5337 — Chip Design Verification, Birzeit University
**Instructor:** Eng. Elias Khalil
**DUT:** `bird` behavioral model (`design/bird.sv`, provided by the instructor — verified unchanged)
**Specification:** BIRD Functional Specification
**Simulator:** Synopsys VCS T-2022.06-SP2 (Birzeit EDA server)

---

## 1. Executive summary

A complete class-based SystemVerilog verification environment (no UVM) was built
for the BIRD packet router and run against the instructor-provided DUT. The
environment compiles and runs cleanly, achieves **88.51% functional coverage**
and **69.95% code coverage**, and its scoreboard detected **three spec
violations** in the DUT. The two most serious findings are confirmed directly
against the DUT source and the specification, so they are defensible rather than
speculative.

| Metric | Result |
|--------|--------|
| Compilation / elaboration | Clean (VCS) |
| Directed tests (merged for coverage) | 8 |
| Local output checks (directed env run) | pass for valid SEQ=1, fails reproduce BUG-1 |
| Remote output checks | 0 pass — reproduce BUG-2 |
| Drop-count check | mismatch reproduces BUG-3 |
| Functional (covergroup) coverage | 88.51% (per-instance 89.83%) |
| Code coverage | 69.95% (line 71.5 / cond 63.4 / toggle 54.7 / FSM 80 / branch 72.7) |
| Defects found | 3 (2 High, 1 Medium–High) |

The overall `FINAL RESULT: FAIL` is the **correct** outcome: it reflects real
DUT defects caught by the testbench, not testbench errors.

---

## 2. Verification environment

The testbench follows the class/slide structure (no UVM):

| Component | File | Role |
|-----------|------|------|
| Interface + clocking | `tb/bird_if.sv` | DUT pins, single TB clocking block, modports |
| Transaction | `tb/bird_transaction.sv` | Randomized packet (cfg fields, payload, CRC16) |
| Sequence | `tb/bird_sequence.sv` | Directed + constrained-random stimulus |
| Driver | `tb/bird_driver.sv` | Drives bytes on the valid/ready handshake + output backpressure |
| Monitor | `tb/bird_monitor.sv` | Reconstructs inputs, samples local/remote outputs |
| Functional coverage | `tb/bird_coverage.sv` | Covergroups: input/scenario, protocol/backpressure, drop-counter |
| Scoreboard | `tb/bird_scoreboard.sv` | Spec reference model + checker + end-of-test report |
| Environment | `tb/bird_env.sv` | Builds/wires components, runs, drains, reports |
| Test | `tb/bird_test.sv`, `tests/` | Single env test + 8 directed tests (`+TEST=<tag>`) |
| Top | `tb/bird_top.sv`, `tests/bird_tests_top.sv` | Clock/reset, DUT instantiation |

Data flow: `sequence → driver → DUT → monitor → coverage → scoreboard`.
Coverage is interposed on the monitor→scoreboard input path: it samples each
observed input and forwards it unchanged, so the scoreboard sees the identical
stream. The 8 directed tests are merged into one coverage database for the
final report.

---

## 3. Defects found

### BUG-1 (High) — Local traffic dropped when SEQ_NUM ≠ 1

- **Spec:** §Local Traffic Processing — "SEQ_NUM identifies the packet but has no functional impact on local routing." A local packet is valid with FRAG_NUM = 1 and any SEQ_NUM in 1–31.
- **DUT:** `cfg_invalid()` marks local packets invalid unless `c[28:24] == 1` (SEQ_NUM = 1).
- **Trigger:** `LOCAL seq=5, frag=1, len=4` (cfg `0x05010400`).
- **Expected:** payload + CRC forwarded on the local interface.
- **Observed:** packet dropped (only a partial leak of the first bytes appears on the local output).
- **Impact:** any legitimate local packet with SEQ_NUM ≠ 1 is silently lost.

### BUG-2 (High) — Remote reassembly indexes by SEQ_NUM, not FRAG_NUM

- **Spec:** §Remote Traffic Processing — fragments are "buffered and indexed by FRAG_NUM"; all fragments of a packet share one SEQ_NUM; reorder by FRAG_NUM and merge.
- **DUT:** uses `frag_seen[rx_seq]` / `frag_payload[rx_seq]` and gating conditions such as `rx_seq <= rx_frag`, i.e. it indexes by SEQ_NUM and conflates SEQ with FRAG.
- **Trigger:** `REMOTE seq=7` with fragments 1, 2, 3 (and single-fragment `REMOTE seq=31`).
- **Expected:** merged payload + regenerated CRC on the remote interface.
- **Observed:** no correct remote output produced (all remote checks fail).
- **Impact:** multi-fragment remote packets — the core BIRD feature — do not reassemble per spec.

### BUG-3 (Medium–High) — `drop_cnt` does not match the spec counting rule

- **Spec:** §Drop Counter — "increments by one for each packet that is dropped … once per packet."
- **Observed:** the spec reference model and the DUT `drop_cnt` disagree on the number of dropped packets in the directed runs.
- **Impact:** the dropped-packet count is unreliable; consistent with the mis-indexing in BUG-2 causing extra/missed drop events.

### Candidate (to confirm) — payload-length boundary handling

The DUT advances to the CRC state using `payload_left == 3`, which appears to
mishandle short payloads (partial local forwarding was observed for the dropped
local packet). Flagged for review; not counted as a confirmed defect.

---

## 4. Functional and code coverage

Coverage is measured across **8 directed tests** merged into one URG database
(`reports/coverage/`). The functional model uses three covergroups:

- **Input/scenario** — traffic type, payload-length bins, fragment/sequence bins, reserved-bit fields, traffic transitions, remote ordering, and crosses.
- **Protocol/backpressure** — valid/ready behaviour on the input, local and remote interfaces.
- **Drop-counter behaviour** — hold, increment, wrap.

**Merged results: functional (covergroup) coverage 88.51% (per-instance 89.83%);
code coverage 69.95%** (line 71.5%, condition 63.4%, toggle 54.7%, FSM 80%,
branch 72.7%).

Two bins are **physically unreachable** and are therefore excluded with
`ignore_bins` (a standard, documented practice — no stimulus can hit them):

- **Drop-counter `wraparound`** — the 16-bit `drop_cnt` would have to roll over from 65535 to 0, which cannot occur within a finite directed simulation.
- **Input-backpressure `present`** — the DUT ties `in_rdy` high (always ready), so `in_vld && !in_rdy` can never be observed.

One remaining hole is **remote-interface backpressure**: it cannot be exercised
because the remote output path is defective (BUG-2), so `remote_vld` never
asserts. This is a consequence of the DUT defect, not a testbench limitation.

---

## 5. How to run

### EDA Playground (no VPN required)
1. Design pane: paste `design/bird.sv` (the DUT).
2. Testbench pane: paste `sim/edaplayground/bird_tb_single_file.sv` (the whole testbench in one file).
3. Tools & Simulators: **Synopsys VCS**; language **SystemVerilog**.
4. Run. The log prints the scoreboard end-of-test report and the functional coverage %.

### Synopsys EDA server (Birzeit)
Connect via MobaXterm (enter the password manually when prompted — it is not stored in this repo):
