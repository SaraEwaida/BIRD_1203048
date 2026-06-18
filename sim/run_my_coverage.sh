#!/usr/bin/env bash
#==============================================================================
# run_my_coverage.sh - Student 4: Maysam Abu Eid - 1220675
# Project: BIRD - Birzeit Integrated Router Design (ENCS5337)
#
# Compiles the directed tests top, runs every test into one coverage database,
# then builds the code + functional coverage report into reports/coverage.
# Run from the sim/ directory on the EDA server (VCS tools on PATH):
#   bash run_my_coverage.sh
#==============================================================================
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

CM="line+cond+fsm+tgl+branch"
VDB="bird_tests.vdb"
TOP="../tests/bird_tests_top.sv"
DUT="../design/bird.sv"

echo "== Compiling =="
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
    -cm "$CM" -cm_dir "$VDB" +incdir+../tb +incdir+../tests \
    "$DUT" "$TOP" -o simv_tests -l comp_tests.log

if [ ! -x ./simv_tests ]; then
  echo "ERROR: compile failed. Open sim/comp_tests.log to see why."
  exit 1
fi

echo "== Running all tests =="
for T in legal remote drop_seq0 drop_frag0 drop_len0 drop_local_bad remote_seqmismatch; do
  echo "-- TEST=$T --"
  ./simv_tests -cm "$CM" -cm_dir "$VDB" -cm_name "$T" +TEST="$T" -l "sim_$T.log"
done

echo "== Generating coverage report =="
urg -dir "$VDB" -format both -report ../reports/coverage

echo "Done. Report: reports/coverage/dashboard.html"
