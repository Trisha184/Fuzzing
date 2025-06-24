`timescale 1ns / 1ps

module satellite_fuzzer_wrapper #(
    parameter int DATA_WIDTH   = 32,
    parameter int BUFFER_DEPTH = 8, // Entry width (8-64 bits)
    parameter int MAX_WAIT_CYCLES = 100, // given by IP vendor
    parameter int TEST_PATTERN = 15  // For muttated fuzzer number of patterns
)(
    input logic clk,
    input logic rst_n,

    // AHB-Lite Interface (Communication with Central Fuzzer)
    input logic hsel,       // Select signal from Central Fuzzer
    input logic hwrite,     // Write enable
    input logic [31:0] hwdata, // Data from Central Fuzzer (mode selection)
    output logic [31:0] hrdata, // Status feedback to Central Fuzzer

    // IPs in the SoC
    //output logic disconnect_IP,  // IP disconnection control
    //output logic reconnect_IP,   // IP reconnection control
    output logic [32:0] random_output,   // Random fuzz output
    output logic [32:0] mutated_output, // mutated fuzz output
    output logic ack_rand,
    output logic ack_mut
);

    // Mode Selection: 0 - Idle, 1 - Random Fuzz, 2 - Mutated Fuzz
    logic [1:0] fuzz_mode;
    
    // ALU Signals (Selected Inputs)
    logic [31:0] alu_a_sel, alu_b_sel;
    logic [3:0] alu_op_sel;
    logic [31:0] alu_result_int;
    logic alu_carry_int;

    // Crash Detection, Hanged, Overflow
    logic crash_detected_random, crash_detected_mutated;
    logic hang_detected_random, hang_detected_mutated;
    logic overflow_detected_random, overflow_detected_mutated, mismatch_detected_mutated;

    // Fuzzer Outputs
    logic [31:0] rand_fuzz_alu_a, rand_fuzz_alu_b, rand_fuzz_alu_result;
    logic [31:0] mut_fuzz_alu_a, mut_fuzz_alu_b, mut_fuzz_alu_result;
    logic [3:0] rand_fuzz_op, mut_fuzz_op;
    logic rand_carry, mut_carry;

    // Assign Mode Selection
    always_ff @(posedge clk) begin
        if (!rst_n)
            fuzz_mode <= 2'b00;
        else if (hsel && hwrite)
            fuzz_mode <= hwdata[1:0]; // Select fuzz mode based on AHB data
    end

    // ALU Muxing Logic
    always_comb begin
        case (fuzz_mode)
            2'b01: begin  // Random Fuzzing
                alu_a_sel = rand_fuzz_alu_a;
                alu_b_sel = rand_fuzz_alu_b;
                alu_op_sel = rand_fuzz_op;
            end
            2'b10: begin  // Mutated Fuzzing
                alu_a_sel = mut_fuzz_alu_a;
                alu_b_sel = mut_fuzz_alu_b;
                alu_op_sel = mut_fuzz_op;
            end
            default: begin  // Default (Idle)
                alu_a_sel = 0;
                alu_b_sel = 0;
                alu_op_sel = 0;
            end
        endcase
    end

    // Instantiate ALU
    alu_unit ALU (
        .A(alu_a_sel),
        .B(alu_b_sel),
        .Op(alu_op_sel),
        .Result(alu_result_int),
        .carry(alu_carry_int)
    );

    // Instantiate Random Fuzzing
    random_fuzzer #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_DEPTH(BUFFER_DEPTH), .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES)) rand_fuzz (
        .clk(clk),
        .rst_n(rst_n),
        .enable(fuzz_mode == 2'b01), // Active when mode is Random Fuzz
        .alu_a(rand_fuzz_alu_a),
        .alu_b(rand_fuzz_alu_b),
        .alu_op(rand_fuzz_op),
        .alu_result(rand_fuzz_alu_result),
        .alu_carry(rand_carry),
        .crash_detected(crash_detected_random),
        .hang_detected(hang_detected_random),
        .overflow_detected(overflow_detected_random),
        .ack(ack_rand),
        .IP_output(random_output)
    );

// sending to Central fuzzer for thecrash, hang, overflow detected

    always_comb begin
    case (fuzz_mode)
        2'b01: begin  // Random Fuzzing
            if (crash_detected_random)
                hrdata = 32'hDEAD0001;
            else if (hang_detected_random)
                hrdata = 32'hBEEF0001;
            else if (overflow_detected_random)
                hrdata = 32'hC0DE0001;
            else
                hrdata = 32'h1;
        end
        2'b10: begin  // Mutated Fuzzing
            if (crash_detected_mutated)
                hrdata = 32'hDEAD0002;
            else if (hang_detected_mutated)
                hrdata = 32'hBEEF0002;
            else if (overflow_detected_mutated)
                hrdata = 32'hC0DE0002;
            else if (mismatch_detected_mutated)
                hrdata = 32'hFFFF0002;
            else
                hrdata = 32'h2;
        end
        default: hrdata = 32'h0;
    endcase
    end

    // Instantiate Mutated Fuzzing
    mutated_fuzzer #(.TEST_PATTERN(TEST_PATTERN), .BUFFER_DEPTH(BUFFER_DEPTH), .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES)) mut_fuzz (
        .clk(clk),
        .rst_n(rst_n),
        .enable(fuzz_mode == 2'b10),
        .alu_a(mut_fuzz_alu_a),
        .alu_b(mut_fuzz_alu_b),
        .alu_op(mut_fuzz_op),
        .alu_result(mut_fuzz_alu_result),
        .alu_carry(mut_carry),
        .crash_detected(crash_detected_mutated),
        .hang_detected(hang_detected_mutated),
        .overflow_detected(overflow_detected_mutated),
        .mismatch_detected(mismatch_detected_mutated),
        .ack(ack_mut),
        .IP_output(mutated_output)
    );

    // Central Fuzzer Response
    //assign hrdata = (fuzz_mode == 2'b00) ? 32'h0 : 
    //                (fuzz_mode == 2'b01 && crash_detected_random) ? 32'hDEAD0001 : 
    //                (fuzz_mode == 2'b10 && crash_detected_mutated) ? 32'hDEAD0002 : 32'hF0000000;

endmodule


// ALU Unit
module alu_unit (
    input logic [31:0] A, B,
    input logic [3:0] Op,
    output logic [31:0] Result,
    output logic carry
);
    assign {carry, Result} = (Op == 4'b0000) ? {1'b1, A + B} :
                             (Op == 4'b0001) ? {1'b1, A - B} :
                             (Op == 4'b0010) ? {1'b1, A & B} :
                             (Op == 4'b0011) ? {1'b1, A | B} :
                             (Op == 4'b0100) ? {1'b1, A ^ B} : {1'b0, 32'b0};
endmodule
