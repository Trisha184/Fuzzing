SRC_FILES := aes_128.v round.v table.v trng.sv random_fuzzer.sv mutated_fuzz.sv satellite_fuzzer.sv satellite_fuzzer_tb.sv

FLAGS := -sverilog -debug_access+all

TCL_SCRIPT = compiledc.tcl

SFtest : clean
	vcs $(SRC_FILES) $(FLAGS) && ./simv


synthesis: clean 
	dc_shell -f compiledc.tcl


.PHONY: SFtest synthesis

.PHONY: clean

clean: 
	rm -rf simv.daidir/ $(WORK_DIR) WORK/ *.log ucli.key .nfs* csrc/ cds.lib simv vcdplus.vpd *.vcd