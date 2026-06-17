#==============================================================================
# Makefile : BIRD verification - Synopsys VCS
# Project  : BIRD - Birzeit Integrated Router Design (ENCS5337)
#
# Run from the sim/ directory on the EDA server, AFTER the Synopsys/VCS tools
# are on your PATH (see the README / server setup notes).
#
# Quick start:
#   make all DUT=../rtl/bird.sv          # compile + run + coverage report
#   make run NTX=50                      # re-run with 50 transactions
#   make verdict                         # print PASS/FAIL + coverage
#   make clean                           # remove generated files
#==============================================================================

# ---- User-overridable settings -------------------------------------------
# Path to the BIRD design file (module "bird"). REQUIRED - adjust to match
# where the DUT lives in your repo or on the server.
DUT      ?= ../rtl/bird.sv

FILELIST ?= bird.f
TB_TOP   ?= bird_top
NTX      ?= 20          # number of transactions (+NTX plusarg)
SEED     ?= 1           # randomization seed

# ---- Coverage (code coverage metrics) -------------------------------------
CM       = line+cond+fsm+tgl+branch
CM_DIR   = bird.vdb
CM_NAME  = bird_test
COV_OUT  = ../coverage/urgReport

# ---- Tool option groups ----------------------------------------------------
VCS_OPTS = -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
           -cm $(CM) -cm_dir $(CM_DIR) +incdir+../tb

SIM_OPTS = -cm $(CM) -cm_dir $(CM_DIR) -cm_name $(CM_NAME) \
           +ntb_random_seed=$(SEED) +NTX=$(NTX)

.PHONY: all comp run cov verdict clean help

# Default: compile, run, then build the coverage report.
all: comp run cov

# 1) Compile DUT + testbench into ./simv
comp:
	vcs $(VCS_OPTS) $(DUT) -f $(FILELIST) -o simv -l comp.log

# 2) Run the simulation (writes sim.log and fills the coverage database)
run:
	./simv $(SIM_OPTS) -l sim.log

# 3) Merge + generate HTML/text coverage reports (code AND functional/covergroups)
cov:
	urg -dir $(CM_DIR) -format both -report $(COV_OUT)
	@echo "Coverage report written to: $(COV_OUT)/dashboard.html"

# Show the scoreboard result + functional coverage line from the run log
verdict:
	@grep -E "FINAL RESULT|FUNCTIONAL COVERAGE|functional coverage" sim.log || \
	  echo "No verdict found - run 'make run' first."

clean:
	rm -rf simv simv.daidir csrc *.log $(CM_DIR) \
	       ucli.key vc_hdrs.h DVEfiles *.vpd *.vcd novas* verdiLog inter.vpd

help:
	@echo "make all DUT=path/to/bird.sv  - compile + run + coverage"
	@echo "make comp DUT=path/to/bird.sv - compile only"
	@echo "make run  NTX=50              - run (default NTX=20)"
	@echo "make cov                      - build URG code+functional report"
	@echo "make verdict                  - print PASS/FAIL + coverage"
	@echo "make clean                    - remove generated files"
