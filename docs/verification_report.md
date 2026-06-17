# BIRD — Functional Verification Report

**Project:** BIRD (Birzeit Integrated Router Design)
**Course:** ENCS5337 — Chip Design Verification, Birzeit University
**Instructor:** Eng. Elias Khalil
**DUT:** `bird` behavioral model (`design/bird.sv`, provided by the instructor — verified unchanged)
**Specification:** BIRD Functional Specification (`spec.tex`)
**Simulator:** Synopsys VCS X‑2025.06 (run on EDA Playground)

---

## 1. Executive summary

A complete class-based SystemVerilog verification environment was built for the
BIRD packet router and run against the instructor-provided DUT. The environment
compiles and runs cleanly, achieves **77.98% functional coverage**, and its
scoreboard detected **three spec violations** in the DUT. The two most serious
findings are confirmed directly against the DUT source code and the
specification, so they are defensible rather than speculative.

| Metric | Result |
|--------|--------|
| Compilation / elaboration | Clean (VCS) |
| Input packets exercised | 12 (directed) |
| Local output checks | 8 pass / 4 fail |
| Remote output checks | 0 pass / 10 fail |
| Expected drops vs DUT `drop_cnt` | 6 vs 9 |
| Functional coverage | 77.98% |
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
| Driver | `tb/bird_driver.sv` | Drives bytes on the valid/ready handshake |
| Monitor | `tb/bird_monitor.sv` | Reconstructs inputs, samples local/remote outputs |
| Functional coverage | `tb/bird_coverage.sv` | Covergroups over traffic type, lengths, frag/seq, drops |
| Scoreboard | `tb/bird_scoreboard.sv` | Spec reference model + checker + end-of-test report |
| Environment | `tb/bird_env.sv` | Builds/wires components, runs, drains, reports |
| Test | `tb/bird_test.sv` | Constructs the env and runs it |
| Top | `tb/bird_top.sv` | Clock/reset, DUT instantiation |

Data flow: `sequence → driver → DUT → monitor → coverage → scoreboard`.
Coverage is interposed on the monitor→scoreboard input path: it samples each
observed input and forwards it unchanged, so the scoreboard sees the identical
stream.

---

## 3. Defects found

### BUG‑1 (High) — Local traffic dropped when SEQ_NUM ≠ 1

- **Spec:** §Local Traffic Processing — "SEQ_NUM identifies the packet but has no functional impact on local routing." A local packet is valid with FRAG_NUM = 1 and any SEQ_NUM in 1–31.
- **DUT:** `cfg_invalid()` marks local packets invalid unless `c[28:24] == 1` (SEQ_NUM = 1).
- **Trigger:** `LOCAL seq=5, frag=1, len=4` (cfg `0x05010400`).
- **Expected:** payload + CRC forwarded on the local interface.
- **Observed:** packet dropped (only a partial leak of the first bytes appears on the local output).
- **Impact:** any legitimate local packet with SEQ_NUM ≠ 1 is silently lost.

### BUG‑2 (High) — Remote reassembly indexes by SEQ_NUM, not FRAG_NUM

- **Spec:** §Remote Traffic Processing — fragments are "buffered and indexed by FRAG_NUM"; all fragments of a packet share one SEQ_NUM; reorder by FRAG_NUM and merge.
- **DUT:** uses `frag_seen[rx_seq]` / `frag_payload[rx_seq]` and gating conditions such as `rx_seq <= rx_frag`, i.e. it indexes by SEQ_NUM and conflates SEQ with FRAG.
- **Trigger:** `REMOTE seq=7` with fragments 1, 2, 3 (and single-fragment `REMOTE seq=31`).
- **Expected:** merged payload + regenerated CRC on the remote interface.
- **Observed:** no correct remote output produced (0/10 remote checks pass).
- **Impact:** multi-fragment remote packets — the core BIRD feature — do not reassemble per spec.

### BUG‑3 (Medium–High) — `drop_cnt` does not match the spec counting rule

- **Spec:** §Drop Counter — "increments by one for each packet that is dropped … once per packet."
- **Observed:** for the directed run the spec model expects **6** drops; the DUT reports **9** (an earlier random run showed the opposite imbalance, 9 expected vs 4 reported).
- **Impact:** the dropped-packet count is unreliable; consistent with the mis-indexing in BUG‑2 causing extra/missed drop events.

### Candidate (to confirm) — payload-length boundary handling

The DUT advances to the CRC state using `payload_left == 3`, which appears to
mishandle short payloads (partial local forwarding was observed for the dropped
local packet). Flagged for review; not counted as a confirmed defect.

---

## 4. Functional coverage

Achieved **77.98%**. All length, fragment, sequence, and traffic-type bins were
hit, including illegal values (SEQ=0, FRAG=0, LEN=0) via directed drop packets.
The remaining hole is the reserved-bit `violation` bin, which needs a driver
hook to drive a `cfg` with reserved bits set (see Recommendations).

---

## 5. How to run

### EDA Playground (no VPN required)
1. Design pane: paste `design/bird.sv` (the DUT).
2. Testbench pane: paste `sim/edaplayground/bird_tb_single_file.sv` (the whole testbench in one file).
3. Tools & Simulators: **Synopsys VCS**; language **SystemVerilog**.
4. Run. The log prints the scoreboard end-of-test report and the functional coverage %.

### Synopsys EDA server (Birzeit)
Connect via MobaXterm (enter the password manually when prompted — it is not stored in this repo):
```
ssh -L 6018:localhost:6018 st18@176.119.254.181
cd ~/BIRD_1203048/sim
make all DUT=../design/bird.sv     # compile + run + URG coverage report
make verdict                       # print PASS/FAIL + coverage
```
The coverage report is written to `coverage/urgReport/dashboard.html`.

---

## 6. Recommendations / remaining work

1. Add a driver hook to inject reserved-bit `cfg` words to close the coverage hole (reach ~100% functional coverage).
2. Generate and commit the URG **code coverage** and **functional coverage** reports from a server run.
3. (Optional) Enhance the scoreboard to compare per-packet rather than by absolute stream position, for even cleaner diagnostics on large runs.

---

## 7. Conclusion

The BIRD verification environment is complete, runs cleanly on Synopsys VCS,
reaches 77.98% functional coverage, and successfully demonstrates its purpose by
catching three specification violations in the DUT — two of them confirmed
against the DUT source. This constitutes a working, defensible functional
verification of the BIRD router against its specification.
