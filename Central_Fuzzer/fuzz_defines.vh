`define IP_ADDR_MAP {32'h43C00000, 32'h43D00000, 32'h43E00000, 32'h43B00000}
`define TRAFFIC_ADDR_MAP {32'h53C00000, 32'h53C00028} // monitor any transaction happening between these addresses
`define FUZZ_ACK_ADDR {32'h63C00000} // the address where satelitte fuzzer will send ack for fuzzing being done 
`define ANOMALY_INDICATION_ADDR {32'h28A00000}
`define ANOMALY_INDICATION_DATA {32'h3333CCCC}
`define ANOMALY_DATA_ADDR {32'h27A00000}
`define TRIGGER_ACK_ADDR 32'h83C00004
`define TRIGGER_ACK_DATA 32'h1234ABCD
`define ANOMALY_PAYLOAD 32'hDEADBEEF