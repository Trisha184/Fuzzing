SRC_FILES := sha256.v lec25dscc25.v sha_top.sv sha_top_tb.sv

FLAGS := -sverilog -suppress -R +vcs+vcdpluson +vcs+lic+wait

SHAtest : clean
	vcs $(FLAGS) $(SRC_FILES)

.PHONY: SHAtest

.PHONY: clean

clean: 
	rm -rf simv.daidir/ $(WORK_DIR) WORK/