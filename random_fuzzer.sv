`timescale 1ns / 1ps

module random_fuzzer #(    
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

    // Control signals for IP isolation
    logic disconnect_IP;  // High -> Disconnect IP from SoC
    logic reconnect_IP;   // High -> Reconnect IP to SoC


    // checking to apply test if the IP disconnected
    bit alu_ready;
    //logic ready;
    // Random Pattern Generator (Using LFSR)
    logic [31:0] lfsr_reg;
    logic [3:0] lfsr_op;
    logic [DATA_WIDTH-1:0] rng_value;

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
                next_state = STORE_PATTERN;

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
                if (alu_result === 32'hXXXX) // Detect crash/hang
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
    trng #(.DATA_WIDTH(32)) trng_inst (
        .clk(clk),
        .enable(state == GENERATE_TESTS),  // Enable TRNG only in GENERATE_TESTS state
        .random_numbers(rng_value)
    );


    // Circular Buffer Logic
    assign buffer_full  = ((buffer_tail + 1) % BUFFER_DEPTH) == buffer_head;
    assign buffer_empty = (buffer_head == buffer_tail);

	always_ff @(posedge clk) begin
	    if (!rst_n) begin
            buffer_head <= 0;
            buffer_tail <= 0;
	    end else if (state == STORE_PATTERN && !buffer_full) begin
		    circular_buffer[buffer_tail] <= rng_value; // Store new test pattern
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
            crash_detected <= 0;
            IP_output <= 0;
        end else if (state == OBSERVE_OUTPUT) begin
            IP_output <= {alu_carry, alu_result};
            crash_detected <= (alu_result === 32'hXXXX); // Detect crash
        end
    end

endmodule


module trng #(
    parameter int DATA_WIDTH
)(
    input  logic clk,        
    input  logic enable,     // Enable signal to turn on TRNG
    output logic [DATA_WIDTH-1:0] random_numbers // Output N-bit random number
);

    logic [DATA_WIDTH-1:0] ring_osc_out;  
    logic [DATA_WIDTH-1:0] sampled_bits;  

    genvar i;
    generate
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin : trng_cells
            logic inv1, inv2, inv3;
            
            // Odd-numbered inverters --------- ring oscillator
            always_comb begin
                if (enable) begin
                    inv1 = ~inv3;  
                    inv2 = ~inv1;  
                    inv3 = ~inv2;  
                end else begin
                    inv1 = 1'b0;
                    inv2 = 1'b0;
                    inv3 = 1'b0;
                end
            end
            
            assign ring_osc_out[i] = inv3;

            // Sampling the ring oscillator output into a flip-flop
            always_ff @(posedge clk) begin
                sampled_bits[i] <= ring_osc_out[i];
            end
        end
    endgenerate

    assign random_bits = sampled_bits; 

endmodule



