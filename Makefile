SIM_DIR = sim
TB_NAME = tb_satellite_fuzzer_wrapper
TOP_MODULE = tb_satellite_fuzzer_wrapper
VCS_FLAGS = -full64 -debug_access+all -sverilog +vcs+vcdpluson
RUN_FLAGS = -R | tee run.log
 
# File list
VERILOG_FILES = satellite_fuzzer.sv random_fuzzer.sv mutated_fuzzer.sv
TESTBENCH_FILE = satellite_fuzzer_tb.sv
 
# Create simulation directory
$(SIM_DIR):
	mkdir -p $(SIM_DIR)
 
# Compile and run VCS simulation inside sim/
# Default target
.PHONY: all
all: simulate
simulate: $(SIM_DIR)
	cp $(VERILOG_FILES) $(SIM_DIR)/
	cp $(TESTBENCH_FILE) $(SIM_DIR)/
	cd $(SIM_DIR) && vcs $(VCS_FLAGS) $(VERILOG_FILES) $(TESTBENCH_FILE) -top $(TB_NAME) $(RUN_FLAGS)
 
# Clean the simulation directory
.PHONY: clean
clean:
	rm -rf $(SIM_DIR)
 
