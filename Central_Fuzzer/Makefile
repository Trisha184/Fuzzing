SRC_FILES := central_fuzz_fsm.sv wishbone_dual.sv central_top.sv central_top_tb.sv


FLAGS := -sverilog

CFtest : clean
	vcs $(SRC_FILES) $(FLAGS) && ./simv


.PHONY: CFtest

.PHONY: clean

clean: 
	rm -rf simv* csrc* *.log ucli.key