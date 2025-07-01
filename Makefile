SIM_DIR = sim
TB_NAME = tb_satellite_fuzzer_wrapper
TOP_MODULE = tb_satellite_fuzzer_wrapper
VCS_FLAGS = -full64 -debug_access+all -sverilog +vcs+vcdpluson +incdir+$(SHA256_DIR)
RUN_FLAGS = -R | tee run.log
 
# File list
VERILOG_FILES = top_module.sv wishbone_dual.sv common_types.sv Satellite_fuzzer_wb.sv random_fuzzer.sv mutated_fuzzer.sv 
SHA256_DIR = sha256
SHA256_FILES = $(wildcard $(SHA256_DIR)/*.v)
TESTBENCH_FILE = satellite_tb_wb.sv
#TESTBENCH_FILE = satellite_tb.sv
 
# Create simulation directory
$(SIM_DIR):
	mkdir -p $(SIM_DIR)
 
# Compile and run VCS simulation inside sim/
# Default target
.PHONY: all
all: simulate
#simulate: $(SIM_DIR)
#	cp $(VERILOG_FILES) $(SIM_DIR)/
#	cp $(TESTBENCH_FILE) $(SIM_DIR)/
#	cp $(SHA256_FILES) $(SIM_DIR)/
#	cd $(SIM_DIR) && vcs $(VCS_FLAGS) $(VERILOG_FILES) $(SHA256_FILES) $(TESTBENCH_FILE) -top $(TB_NAME) $(RUN_FLAGS)

simulate: $(SIM_DIR)
	cp $(VERILOG_FILES) $(SIM_DIR)/
	cp $(TESTBENCH_FILE) $(SIM_DIR)/
	cp $(SHA256_FILES) $(SIM_DIR)/
	@echo "Files being compiled:"
	@echo $(VERILOG_FILES)
	@echo $(SHA256_FILES)
	@echo $(TESTBENCH_FILE)
	cd $(SIM_DIR) && vcs $(VCS_FLAGS) $(notdir $(VERILOG_FILES)) $(notdir $(SHA256_FILES)) $(notdir $(TESTBENCH_FILE)) -top $(TB_NAME) $(RUN_FLAGS)


 
# Clean the simulation directory
.PHONY: clean
clean:
	rm -rf $(SIM_DIR)

.PHONY: list_sha256
list_sha256:
	@echo "SHA256 Files:"
	@for file in $(SHA256_FILES); do echo $$file; done
 
