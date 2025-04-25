`timescale 1ns / 1ps

module random_fuzzer #(  
    parameter int MAX_WAIT_CYCLES ,  
    parameter int DATA_WIDTH   = 32,
    parameter int BUFFER_DEPTH = 8 ) (
    input logic clk,
    input logic rst_n,
    input logic enable,


    // instance IP wrapper bus
    // IP interface (Fuzzing inputs)   
    output logic [31:0] alu_a,
    output logic [31:0] alu_b,
    output logic [3:0] alu_op,
    input logic [31:0] alu_result,
    input logic alu_carry,         // ALU carry signal

    // Crash/Hang Detection
    
    output logic crash_detected,
    output logic hang_detected,
    output logic overflow_detected,
    output logic ack,          //DIFFERENT TYPE OF ack...
    output logic [32:0] IP_output
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE,
        DISCONNECT_IP,
        GENERATE_TESTS,
        STORE_PATTERN,
        APPLY_TESTS,
        OBSERVE_OUTPUT,
        CRASH_DETECTED,
        RECONNECT_IP
    } fuzzer_state_t;

    fuzzer_state_t state, next_state;

    // hang,crash detected
    logic [7:0] wait_counter;


    // Control signals for IP isolation
    logic disconnect_IP;  // High -> Disconnect IP from SoC
    logic reconnect_IP;   // High -> Reconnect IP to SoC


    // checking to apply test if the IP disconnected
    bit alu_ready;
    logic ready;
    // Random Pattern Generator (Using LFSR)
    logic [31:0] lfsr_reg;
    logic [3:0] lfsr_op;
    logic [DATA_WIDTH-1:0] rng_value [BUFFER_DEPTH-1:0];

    // Circular Buffer (FIFO-style) for storing test patterns
    logic [DATA_WIDTH-1:0] circular_buffer [0:BUFFER_DEPTH-1];
    logic [$clog2(BUFFER_DEPTH)-1:0] buffer_head, buffer_tail;
    logic buffer_full, buffer_empty;

    always_ff @(posedge clk) begin
        if (!rst_n)
            lfsr_reg <= 32'hACE1;  // Seed value
        else
            lfsr_reg <= {lfsr_reg[30:0], lfsr_reg[31] ^ lfsr_reg[21]}; // LFSR Feedback
    end


    // FSM Logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if(enable) begin
                    next_state = DISCONNECT_IP;
                end
            DISCONNECT_IP: 
                next_state = GENERATE_TESTS;

            GENERATE_TESTS:
                if(ready) 
                    next_state = STORE_PATTERN;
                else
                    next_state = GENERATE_TESTS;
            STORE_PATTERN:
                if (buffer_full) 
                    next_state = APPLY_TESTS;
                else
                    next_state = STORE_PATTERN; 
            APPLY_TESTS:
                if (alu_ready) 
                    next_state = OBSERVE_OUTPUT;
                else
                    next_state = APPLY_TESTS;

            OBSERVE_OUTPUT: 
                if (alu_result === 32'hXXXX || alu_result === 32'hZZZZ) // Detect crash/hang
                    next_state = CRASH_DETECTED;
                else 
                    next_state = RECONNECT_IP;

            CRASH_DETECTED: 
                next_state = RECONNECT_IP;

            RECONNECT_IP: 
                next_state = IDLE;
                
        endcase
    end

    // Instantiate TRNG (32-bit output)
    trng #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_DEPTH(BUFFER_DEPTH)) trng_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(state == GENERATE_TESTS),  // Enable TRNG only in GENERATE_TESTS state
        .random_numbers(rng_value),
        .ready(ready)
    );


    // Circular Buffer Logic
    assign buffer_full  = ((buffer_tail + 1) % BUFFER_DEPTH) == buffer_head;
    assign buffer_empty = (buffer_head == buffer_tail);

	always_ff @(posedge clk) begin
	    if (!rst_n) begin
            buffer_head <= 0;
            buffer_tail <= 0;
	    end else if (state == STORE_PATTERN && !buffer_full && ready) begin
		    circular_buffer[buffer_tail] <= rng_value[buffer_tail]; // Store new test pattern
		    buffer_tail <= (buffer_tail + 1) % BUFFER_DEPTH; // Move tail pointer
		end
	end


    // Output Logic
    // Control IP Disconnection Logic (Handled Locally)
    always_comb begin
        disconnect_IP = (state == DISCONNECT_IP) || (enable && crash_detected);
        reconnect_IP  = (state == RECONNECT_IP) && !disconnect_IP;
        ack = (state == RECONNECT_IP);
    end



    // AHB Response
    assign hrdata = (state == IDLE) ? 32'h0 :
                    (state == CRASH_DETECTED) ? 32'hDEADDEAD : 32'h1;

    // need to select one.............................................commnets.................

    // Add disconnect/reconnect logic for IP interface (inside the wrapper) and apply tests

    // Tri-state Bus Signals	Works for AHB/APB/Wishbone, but not AXI

    // Blocking Transactions	Works for AXI, prevents IP from receiving requests

    // Clock Gating	Saves power, but keeps IP state intact

    always_comb begin
        if (alu_a == 'Z && alu_b == 'Z && alu_op=='Z )
            alu_ready = 1'b1;
        else
            alu_ready = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;
        end else if (disconnect_IP) begin
            // Disconnect the IP from the rest of the SoC (disconnect the bus signals)
            alu_a <= 'Z;
            alu_b <= 'Z;
            alu_op <= 'Z;
            //alu_result = 'Z;
           //alu_carry = 'Z;
        end else if (state == APPLY_TESTS && !buffer_empty) begin
        // Iterate over all stored patterns
            for (int i = buffer_tail; i != buffer_head; i = (i + 1) % BUFFER_DEPTH) begin
                alu_a  = circular_buffer[i];       // Apply test pattern from buffer
                alu_b  = ~circular_buffer[i];      // Inverted pattern for variation
                alu_op = lfsr_op;
            end
        end else if (reconnect_IP) begin
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;
        end else begin
            alu_a <= alu_a;
            alu_b <= alu_b;
            alu_op <= alu_op;      
        end
    end


    // OBSERVE_OUTPUT State Logic - Monitor IP Response
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wait_counter <= 0;
            hang_detected <= 0;
            crash_detected <= 0;
            IP_output <= 0;
        end else if (state == APPLY_TESTS) begin
            if (!alu_ready) begin
            wait_counter <= wait_counter + 1;
                if (wait_counter > MAX_WAIT_CYCLES)
                    hang_detected <= 1;
            end else begin
            wait_counter <= 0;
            hang_detected <= 0;
            end
        end else if (state == OBSERVE_OUTPUT) begin
            IP_output <= {alu_carry, alu_result};
            crash_detected <= (alu_result === 32'hXXXX || alu_result === 32'hZZZZ); // Detect crash
        end else begin
            wait_counter <= 0;
            hang_detected <= 0; 
            crash_detected <= 0;  
            end     
    end


        // Overflow (basic ALU overflow check)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            overflow_detected <= 0;
        end else if (state == OBSERVE_OUTPUT) begin
            // For ADD operation overflow (example)
            if ((alu_a[31] == alu_b[31]) && (alu_result[31] != alu_a[31]))
                overflow_detected <= 1;
        end
    end

endmodule



module trng #(
    parameter int DATA_WIDTH,   // Number of bits per generated random value
    parameter int BUFFER_DEPTH   // Number of values to generate
)(
    input logic clk,
    input logic rst_n,
    input logic enable,
    output logic [DATA_WIDTH-1:0] random_numbers [BUFFER_DEPTH-1:0],
    output logic ready
);

    logic ring_out;
    logic [DATA_WIDTH-1:0] rand_sample;
    logic [DATA_WIDTH-1:0] rand_buffer [BUFFER_DEPTH-1:0];

    // Ring Oscillator: Odd number of inverters in a feedback loop
    logic [5:0] inv_chain;  // 5-stage inverter chain (odd number)

    always_comb begin
        if(enable) begin
            inv_chain[0] = ~inv_chain[5]; // AND gate for enable control
            inv_chain[1] = ~inv_chain[0];
            inv_chain[2] = ~inv_chain[1];
            inv_chain[3] = ~inv_chain[2];
            inv_chain[4] = ~inv_chain[3];
            inv_chain[5] = ~inv_chain[4];
        end
        else begin
            inv_chain = 6'b000000;          
        end
    end
    assign ring_out = inv_chain[5]; // Final output of ring oscillator

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else if (enable) begin
            ready <= 1'b0;
            for (int i = 0; i < BUFFER_DEPTH; i = i + 1) begin
                rand_sample <= {rand_sample[DATA_WIDTH-2:0], ring_out}; // Shift sampled bits
                rand_buffer[i] <= rand_sample;
            end
            ready <= 1'b1;
        end
    end

    // Assign generated numbers to output
    assign random_numbers = rand_buffer;

endmodule




