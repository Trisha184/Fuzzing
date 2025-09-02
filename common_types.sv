//common types for satellite fuzzer
`timescale 1ns / 1ps
package common_types;

typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
} test_pattern_t;

endpackage
