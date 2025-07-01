`timescale 1ns / 1ps

module mutated_fuzzer #(
    parameter int MAX_WAIT_CYCLES,
    parameter int TEST_PATTERN,
    parameter int READ_DATA_WIDTH,
    parameter int BUFFER_DEPTH = 16,
	parameter int MUTATION_WIDTH = 8)(
    input logic clk,
    input logic rst_n,
    input logic enable,

    // instance IP wrapper bus
    // IP interface (Fuzzing inputs)   
    output logic [31:0] wb_addr,
    output logic [31:0] wb_data,
    output logic [3:0] wb_sel,
	output logic wb_stb, wb_cyc, wb_we,
    input logic [31:0] wb_data_o,
    input logic wb_ack, wb_err, int_, 

	//input of motitoring the IP 
	input logic [31:0] wb_mon_addr,
	input logic  [31:0] wb_mon_data,
	input logic [3:0] wb_mon_sel,
	input logic  wb_mon_stb, wb_mon_cyc, wb_mon_we,

    // Central Fuzzer Communication
    output logic crash_detected,
    output logic hang_detected,
    output logic mismatch_detected,
    output logic overflow_detected,
    output logic ack,
    output logic [31:0] IP_output,

	//
	output logic trigger
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
    typedef struct packed {
        logic [31:0] addr;
        logic [31:0] data;
        logic [3:0]  sel;
        logic        we;
		logic        stb;
		logic        cyc;
    } test_pattern_t;

    test_pattern_t base_buffer[BUFFER_DEPTH];
    test_pattern_t mutated_buffer[BUFFER_DEPTH];
    test_pattern_t mutated_pattern;

    logic [$clog2(BUFFER_DEPTH)-1:0] pattern_index;
    logic ready;
    logic [7:0] wait_counter;
	logic all_tests_applied;

	logic [31:0] actual, circular_buffer_result;

    // Dummy pattern generator
    /*always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < BUFFER_DEPTH; i++) begin
                base_buffer[i].addr <= i * 4;
                base_buffer[i].data <= 32'hA5A5_0000 + i;
            end
        end
    end*/

    //logic [3:0] test_pattern_index;
    logic store_enable;

    // Control signals for IP isolation
    logic disconnect_IP;  // High -> Disconnect IP from SoC
    logic reconnect_IP;   // High -> Reconnect IP to SoC

    // Timeout counter for hang detection
    logic [7:0] timeout_counter;

    logic [3:0] buffer_head, buffer_tail; // Buffer pointers
    logic buffer_full, buffer_empty;
	logic [$clog2(BUFFER_DEPTH)-1:0] buffer_index;


    // Buffer Full/Empty Conditions
    assign buffer_full  = ((buffer_tail + 1) % BUFFER_DEPTH) == buffer_head;
    assign buffer_empty = (buffer_head == buffer_tail);


    // Random sampling logic (choose a random window to mutate)
    function test_pattern_t mutate(input test_pattern_t in);
        test_pattern_t out;
        logic [MUTATION_WIDTH-1:0] rand_bits;
        rand_bits = $urandom_range(0, 2**MUTATION_WIDTH - 1);

        // Apply mutation to selected bits in addr/data
        out.addr = in.addr ^ (rand_bits << (32 - MUTATION_WIDTH));
        out.data = in.data ^ (rand_bits << (32 - MUTATION_WIDTH));
        out.sel  = in.sel;
        out.we   = in.we;
        return out;
    endfunction

    // Monitor and store patterns
	always_ff @(posedge clk) begin
		if (!rst_n) begin
		    pattern_index <= 0;
		    for (int i = 0; i < BUFFER_DEPTH; i++) begin
		        base_buffer[i].addr <= i * 4;
		        base_buffer[i].data <= 32'hA5A5_0000 + i;
		        base_buffer[i].sel  <= 4'b0000;
		        base_buffer[i].we   <= 1'b0;
		        base_buffer[i].stb  <= 1'b0;
		        base_buffer[i].cyc  <= 1'b0;
		    end
		end else if (store_enable && pattern_index < BUFFER_DEPTH) begin
		    base_buffer[pattern_index].addr <= wb_mon_addr;
		    base_buffer[pattern_index].data <= wb_mon_data;
		    base_buffer[pattern_index].sel  <= wb_mon_sel;
		    base_buffer[pattern_index].we   <= wb_mon_we;
		    pattern_index <= pattern_index + 1;
		end
	end
    /*always_ff @(posedge clk) begin
        if (!rst_n) begin
            pattern_index <= 0;
        end else if (store_enable && pattern_index < BUFFER_DEPTH) begin
            base_buffer[pattern_index].addr <= wb_mon_addr;
            base_buffer[pattern_index].data <= wb_mon_data;
            base_buffer[pattern_index].sel  <= wb_mon_sel;
            base_buffer[pattern_index].we   <= wb_mon_we;
            pattern_index <= pattern_index + 1;
        end
    end*/
    // Fetch stored test patterns into circular buffers




    // Apply Mutation in the Mutation State

	logic [$clog2(BUFFER_DEPTH)-1:0] mutate_idx;

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
		    mutate_idx <= 0;
		end else if (state == MUTATE_PATTERNS) begin
		    mutated_buffer[mutate_idx] <= mutate(base_buffer[mutate_idx]);
		    mutate_idx <= mutate_idx + 1;
		end else begin
		    mutate_idx <= 0;
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


    // FSM Logic
    always_ff @(posedge clk  ) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
		trigger = 1'b0;  // default for all states
        case (state)
            IDLE:
                if (enable) 
                    next_state = MONITOR_EXECUTION;
            MONITOR_EXECUTION: 
                if (wb_ack)  
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

            APPLY_TESTS: begin
				trigger = 1'b1; 
				next_state = all_tests_applied ? OBSERVE_OUTPUT : APPLY_TESTS;
			end
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
			default: next_state = IDLE;
        endcase
    end




    // APPLY_TESTS state logic
	logic transaction_in_progress;
	logic [$clog2(BUFFER_DEPTH)-1:0] num_patterns_sent;

	always_ff @(posedge clk) begin
		if (!rst_n) begin
		    wb_addr <= 0;
		    wb_data <= 0;
		    wb_sel  <= 4'b0000;
		    wb_stb  <= 0;
		    wb_cyc  <= 0;
		    wb_we   <= 0;
		    buffer_index <= 0;
		    transaction_in_progress <= 0;
		    num_patterns_sent <= 0;
		end else if (state == APPLY_TESTS) begin
		    if (!transaction_in_progress) begin
		        // Load pattern and assert signals
		        mutated_pattern <= mutated_buffer[buffer_index];
		        wb_addr <= mutated_buffer[buffer_index].addr;
		        wb_data <= mutated_buffer[buffer_index].data;
		        wb_sel  <= 4'b1111;
		        wb_we   <= 1;
		        wb_stb  <= 1;
		        wb_cyc  <= 1;
		        transaction_in_progress <= 1;
		    end else if (transaction_in_progress && wb_ack) begin
		        // Transaction finished, move to next
		        wb_stb <= 0;
		        wb_cyc <= 0;
		        wb_we  <= 0;
		        buffer_index <= (buffer_index + 1) % BUFFER_DEPTH;
		        num_patterns_sent <= num_patterns_sent + 1;
		        transaction_in_progress <= 0;
		    end
		end else begin
		    // Reset driving signals
		    wb_stb <= 0;
		    wb_cyc <= 0;
		    wb_we  <= 0;
		    transaction_in_progress <= 0;
		end
	end

	always_ff @(posedge clk) begin
		if (!rst_n) begin
		    crash_detected <= 0;
		    hang_detected  <= 0;
		    IP_output      <= 0;
		    wait_counter   <= 0;
		end else if (state == APPLY_TESTS && !wb_ack && transaction_in_progress) begin
		    wait_counter <= wait_counter + 1;
		    if (wait_counter > MAX_WAIT_CYCLES)
		        hang_detected <= 1;
		end else if (state == OBSERVE_OUTPUT && wb_ack) begin
		    // Only observe after confirmed ACK
		    IP_output <= wb_data_o;
		    crash_detected <= (wb_data_o === 32'hXXXX || wb_data_o === 32'hZZZZ || wb_err);
		    wait_counter <= 0;
		end else begin
		    wait_counter <= 0;
		    crash_detected <= 0;
		    hang_detected <= 0;
		end
	end
    // Detect Crashes & Hangs

	always_ff @(posedge clk) begin
		if (!rst_n) begin
		    actual <= 32'h0;
		    circular_buffer_result <= 32'h0;
		end else if (state == OBSERVE_OUTPUT && wb_ack) begin
		    actual <= wb_data_o;
		    circular_buffer_result <= mutated_pattern.data;
		end
	end
    assign mismatch_detected = (actual !== circular_buffer_result);
    assign all_tests_applied = (num_patterns_sent == BUFFER_DEPTH);
    // Notify Central Fuzzer
    assign disconnect_IP = enable && (crash_detected);
    assign reconnect_IP  = ~disconnect_IP;
    assign store_enable   = (state == STORE_PATTERNS);
    assign ack = (state == RECONNECT_IP);

endmodule
