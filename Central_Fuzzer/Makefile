SRC_FILES := central_fuzz_fsm.sv wishbone_dual.sv central_top.sv central_top_tb.sv


FLAGS := -sverilog

TCL_SCRIPT = compiledc.tcl

CFtest : clean
	vcs $(SRC_FILES) $(FLAGS) && ./simv

synthesis: clean 
	dc_shell -f compiledc.tcl


.PHONY: CFtest synthesis

.PHONY: clean

clean: 
	rm -rf simv.daidir/ $(WORK_DIR) WORK/ *.log ucli.key .nfs* csrc/ cds.lib 