SRC_FILES := aes_128.v round.v table.v aes128_tb.v



AES128test : clean
	vcs $(SRC_FILES) && ./simv


.PHONY: AES128test

.PHONY: clean

clean: 
	rm -rf simv* csrc* *.log ucli.key