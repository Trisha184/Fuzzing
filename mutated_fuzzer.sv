`timescale 1ns / 1ps

module mutated_fuzzer #(
    parameter int MAX_WAIT_CYCLES,
    parameter int TEST_PATTERN,
    parameter int BUFFER_DEPTH = 16)(
    input logic clk,
    input logic rst_n,
    input logic enable,

    // ALU interface (Monitoring inputs)
    output logic [31:0] alu_a,   
    output logic [31:0] alu_b,   
    output logic [3:0]  alu_op,   
    input logic [31:0] alu_result,  
    input logic alu_carry,      

    // Central Fuzzer Communication
    output logic crash_detected,
    output logic hang_detected,
    output logic mismatch_detected,
    output logic overflow_detected,
    output logic ack,
    output logic [32:0] IP_output
);

    // FSM States
    typedef enum logic [3:0] {
        IDLE,
        MONITOR_EXECUTION,
        STORE_PATTERNS,
        DISCONNECT_IP,
        FETCH_STORED_PATTERNS,
        MUTATE_PATTERNS,
        STORE_MUTATED_PATTERNS,
        APPLY_TESTS,
        OBSERVE_OUTPUT,
        REPORT_STATUS,
        CRASH_DETECTED,
        RECONNECT_IP
    } fuzzer_state_t;

    fuzzer_state_t state, next_state;


    // Storage for test patterns
    struct packed {
        logic [31:0] a;
        logic [31:0] b;
        logic [3:0]  op;
        logic [31:0] result;
    } test_patterns [0:TEST_PATTERN]; 

    integer test_pattern_index;


    //logic [3:0] test_pattern_index;
    logic store_enable;

    // Circular buffers for fetched test pattern
    logic [31:0] circular_buffer_a, mutated_buffer_a;
    logic [31:0] circular_buffer_b, mutated_buffer_b;
    logic [3:0]  circular_buffer_op, mutated_buffer_op;
    logic [31:0] circular_buffer_result; // Expected stored result

    // Control signals for IP isolation
    logic disconnect_IP;  // High -> Disconnect IP from SoC
    logic reconnect_IP;   // High -> Reconnect IP to SoC

    // Timeout counter for hang detection
    logic [7:0] timeout_counter;

    // Circular Buffer Parameters
    //localparam BUFFER_DEPTH = 16;

    // checking to apply test if the IP disconnected
    bit alu_ready;
    
    logic [31:0] circular_buffer_mutated_a [BUFFER_DEPTH]; // Buffer for operand A
    logic [31:0] circular_buffer_mutated_b [BUFFER_DEPTH]; // Buffer for operand B
    logic [3:0]  circular_buffer_mutated_op [BUFFER_DEPTH]; // Buffer for operations

    logic [3:0] buffer_head, buffer_tail; // Buffer pointers
    logic buffer_full, buffer_empty;

    // Buffer Full/Empty Conditions
    assign buffer_full  = ((buffer_tail + 1) % BUFFER_DEPTH) == buffer_head;
    assign buffer_empty = (buffer_head == buffer_tail);

    // Reset & Buffer Pointer Control
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            buffer_head <= 0;
            buffer_tail <= 0;
        end 
        else if (state == STORE_MUTATED_PATTERNS && !buffer_full) begin
            // Store mutated test patterns into circular buffer
            circular_buffer_mutated_a[buffer_tail]  <= mutated_buffer_a;
            circular_buffer_mutated_b[buffer_tail]  <= mutated_buffer_b;
            circular_buffer_mutated_op[buffer_tail] <= mutated_buffer_op;

            // Move tail pointer
            buffer_tail <= (buffer_tail + 1) % BUFFER_DEPTH;
        end
    end        

    // Monitoring Logic: Store observed input-output patterns
    always_ff @(posedge clk) begin
        if (!rst_n)
            test_pattern_index <= 0;
        else if (store_enable && test_pattern_index < TEST_PATTERN)
            test_pattern_index <= test_pattern_index + 1;
    end

    always_ff @(posedge clk) begin
        if (store_enable) begin
            test_patterns[test_pattern_index].a      <= alu_a;
            test_patterns[test_pattern_index].b      <= alu_b;
            test_patterns[test_pattern_index].op     <= alu_op;
            test_patterns[test_pattern_index].result <= alu_result; // Store result for later comparison
        end
    end

    // Fetch stored test patterns into circular buffers
    always_ff @(posedge clk) begin
        if (state == FETCH_STORED_PATTERNS) begin
            circular_buffer_a      <= test_patterns[test_pattern_index].a;
            circular_buffer_b      <= test_patterns[test_pattern_index].b;
            circular_buffer_op     <= test_patterns[test_pattern_index].op;
            circular_buffer_result <= test_patterns[test_pattern_index].result; // Load expected result
        end
    end

    // Apply Mutation in the Mutation State
    // bit flip, shifting left/right, insert/delete values at different position, randomly change some bits of the input.
    always_ff @(posedge clk) begin
        if (state == MUTATE_PATTERNS) begin
            mutated_buffer_a  <= circular_buffer_a ^ 32'hA5A5A5A5; // XOR mutation
            mutated_buffer_b  <= ~circular_buffer_b;               // Bitwise NOT mutation
            mutated_buffer_op <= circular_buffer_op ^ 4'hF;        // XOR operation mutation
        end
    end

    // Timeout Counter for Hang Detection
    always_ff @(posedge clk) begin
        if (!rst_n)
            timeout_counter <= 0;
        else if (state == APPLY_TESTS)
            timeout_counter <= timeout_counter + 1;
        else
            timeout_counter <= 0;
    end

    // OBSERVE OUTPUT: Compare Actual vs. Expected Result
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            crash_detected <= 0;
            IP_output <= 'z;
        end else if (state == OBSERVE_OUTPUT) begin
            if (alu_result === 32'hXXXX || alu_result === 32'hZZZZ) begin
                crash_detected <= 1;
                //mismatch_detected <= 0;
            end 
            else if (timeout_counter > 100) begin //
                hang_detected <= 1;
                //mismatch_detected <= 0;
                crash_detected <= 1;
            end 
            else begin
               IP_output <= alu_result; 
            end
        end
    end

    // FSM Logic
    always_ff @(posedge clk  ) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (enable) 
                    next_state = MONITOR_EXECUTION;

            MONITOR_EXECUTION: 
                if (alu_ready)  
                    next_state = STORE_PATTERNS;
                else
                    next_state = MONITOR_EXECUTION;

            STORE_PATTERNS: 
                next_state = FETCH_STORED_PATTERNS;

            FETCH_STORED_PATTERNS: 
                next_state = MUTATE_PATTERNS;

            MUTATE_PATTERNS: 
                next_state = STORE_MUTATED_PATTERNS; 
            
            STORE_MUTATED_PATTERNS: 
                next_state = APPLY_TESTS; 

            APPLY_TESTS: 
                if (alu_ready) 
                    next_state = OBSERVE_OUTPUT;
                else
                    next_state = APPLY_TESTS;

            OBSERVE_OUTPUT: 
                if (crash_detected) 
                    next_state = CRASH_DETECTED;
                else 
                    next_state = REPORT_STATUS;

            REPORT_STATUS:
                if (crash_detected)
                    next_state = CRASH_DETECTED;
                else 
                    next_state = RECONNECT_IP;

            CRASH_DETECTED: 
                next_state = RECONNECT_IP;

            RECONNECT_IP: 
                next_state = IDLE;
        endcase
    end

    always_comb begin
        if (alu_a == 'Z && alu_b == 'Z && alu_op=='Z )
            alu_ready = 1'b1;
        else
           alu_ready = 1'b0;
    end


    // ALU Disconnect/Reconnect Logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;
        end else if (disconnect_IP) begin
            // Disconnect ALU signals (high-impedance)
            alu_a <= 'z;
            alu_b <= 'z;
            alu_op <= 'z;

        end 
        else if (state == APPLY_TESTS && !buffer_empty) begin
        // Iterate over all stored patterns
            for (int i = buffer_tail; i != buffer_head; i = (i + 1) % BUFFER_DEPTH) begin
                alu_a  <= circular_buffer_mutated_a[i];
                alu_b  <= circular_buffer_mutated_b[i];
                alu_op <= circular_buffer_mutated_op[i];
            end
        end 
        else if (reconnect_IP) begin
            // Retain ALU values when reconnecting
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;
           
        end else begin
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;
            
    end
end

    // Detect Crashes & Hangs
    //assign crash_detected = (alu_result === 32'hXXXX || alu_result === 32'hZZZZ);
    //assign hang_detected  = (timeout_counter > 100);
    assign mismatch_detected = (alu_result !== circular_buffer_result);
    
    // Notify Central Fuzzer
    assign disconnect_IP = enable && (crash_detected);
    assign reconnect_IP  = ~disconnect_IP;
    assign store_enable   = (state == STORE_PATTERNS);
    assign ack = (state == RECONNECT_IP);

endmodule
