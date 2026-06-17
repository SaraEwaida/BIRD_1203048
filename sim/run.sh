#!/usr/bin/env bash
#==============================================================================
# run.sh : one-command compile + run + coverage for BIRD (Synopsys VCS)
# Project: BIRD - Birzeit Integrated Router Design (ENCS5337)
#
# Use this if you prefer not to use 'make'. Run from the sim/ directory on the
# EDA server AFTER the Synopsys/VCS tools are on your PATH.
#
# Usage:
#   ./run.sh [DUT_PATH] [NTX]
# Examples:
#   ./run.sh ../rtl/bird.sv          # default 20 transactions
#   ./run.sh ../rtl/bird.sv 50       # 50 transactions
#==============================================================================
set -euo pipefail

DUT="${1:-../rtl/bird.sv}"      # path to the BIRD design (module "bird")
NTX="${2:-20}"                  # number of transactions
CM="line+cond+fsm+tgl+branch"   # code coverage metrics
CM_DIR="bird.vdb"
COV_OUT="../coverage/urgReport"

if [ ! -f "$DUT" ]; then
  echo "ERROR: DUT file not found: $DUT"
  echo "Pass the correct path, e.g.: ./run.sh ../rtl/bird.sv"
  exit 1
fi

echo "== Compiling =="
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
    -cm "$CM" -cm_dir "$CM_DIR" +incdir+../tb \
    "$DUT" -f bird.f -o simv -l comp.log

echo "== Running (NTX=$NTX) =="
./simv -cm "$CM" -cm_dir "$CM_DIR" -cm_name bird_test +NTX="$NTX" -l sim.log

echo "== Building coverage report =="
urg -dir "$CM_DIR" -format both -report "$COV_OUT"

echo
echo "Report: $COV_OUT/dashboard.html"
grep -E "FINAL RESULT|FUNCTIONAL COVERAGE|functional coverage" sim.log || true
