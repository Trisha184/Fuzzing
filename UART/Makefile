TX_SRC_FILES := uart_tx.v tb_tx.v

RX_SRC_FILES := uart_rx.v tb_rx.v

UART_SRC_FILES := uart_rx.v uart_tx.v uart_top.v uart_top_tb.v


TXtest : clean
	vcs $(TX_SRC_FILES) && ./simv

RXtest : clean
	vcs $(RX_SRC_FILES) && ./simv

UARTtest : clean
	vcs $(UART_SRC_FILES) && ./simv

.PHONY: TXtest RXtest UARTtest

.PHONY: clean

clean: 
	rm -rf simv* csrc* *.log ucli.key