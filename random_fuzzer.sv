`timescale 1ns / 1ps

import common_types::*;
module random_fuzzer #(  
    parameter int MAX_WAIT_CYCLES ,  
    parameter int DATA_WIDTH   = 32,
    parameter int READ_DATA_WIDTH,
    parameter int BUFFER_DEPTH = 8 ) (
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

    // Crash/Hang Detection
    
    output logic crash_detected,
    output logic hang_detected,
    output logic overflow_detected,
    output logic ack,          //DIFFERENT TYPE OF ack...
    output logic [READ_DATA_WIDTH-1:0] IP_output
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
    //logic [DATA_WIDTH-1:0] rng_value [BUFFER_DEPTH-1:0];


	/*typedef struct packed {
    logic [DATA_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
	} test_pattern_t;*/

	test_pattern_t rng_value [BUFFER_DEPTH-1:0];
	test_pattern_t circular_buffer [0:BUFFER_DEPTH-1];

    // Circular Buffer (FIFO-style) for storing test patterns
    //logic [DATA_WIDTH-1:0] circular_buffer [0:BUFFER_DEPTH-1];
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
                if (wb_ack)                                  ///check this signal from SHA256
                    next_state = OBSERVE_OUTPUT;
                else
                    next_state = APPLY_TESTS;

            OBSERVE_OUTPUT: 
                if (wb_data_o === 32'hXXXX || wb_data_o === 32'hZZZZ) // Detect crash/hang
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


    // need to select one.............................................commnets.................

    // Add disconnect/reconnect logic for IP interface (inside the wrapper) and apply tests

    // Tri-state Bus Signals	Works for AHB/APB/Wishbone, but not AXI

    // Blocking Transactions	Works for AXI, prevents IP from receiving requests

    // Clock Gating	Saves power, but keeps IP state intact


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wb_addr <= wb_addr;
            wb_data <= wb_data;
            wb_sel <= wb_sel;
			wb_stb <= wb_stb;
			wb_cyc <= wb_cyc;
			wb_we <= wb_we;
        end else if (disconnect_IP) begin
            // Disconnect the IP from the rest of the SoC (disconnect the bus signals)
            wb_addr <= 'Z;
            wb_data <= 'Z;
            wb_sel <= 'Z;
			wb_stb  <= 1'b0;
			wb_cyc  <= 1'b0;
			wb_we   <= 1'b0;
        end else if (state == APPLY_TESTS && !buffer_empty) begin
			wb_addr <= circular_buffer[buffer_head].addr;    // Set address
			wb_data <= circular_buffer[buffer_head].data;    // Set data
			wb_sel  <= 4'b1111;                              // Enable all bytes
			wb_we   <= 1'b1;                                 // Write enable
			wb_stb  <= 1'b1;                                 // Start bus transaction
			wb_cyc  <= 1'b1;
		    if (wb_ack) begin
		        buffer_head <= (buffer_head + 1) % BUFFER_DEPTH;
		    end
        end else if (reconnect_IP || state != APPLY_TESTS) begin
			wb_stb  <= 1'b0;
			wb_cyc  <= 1'b0;
			wb_we   <= 1'b0;
        end else begin
            wb_addr <= wb_addr;
            wb_data <= wb_data;
            wb_sel <= wb_sel;
			wb_stb <= wb_stb;
			wb_cyc <= wb_cyc;
			wb_we <= wb_we;      
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
		    if (!wb_ack) begin
		        wait_counter <= wait_counter + 1;
		        if (wait_counter > MAX_WAIT_CYCLES)
		            hang_detected <= 1;
		    end else begin
		        wait_counter  <= 0;
		        hang_detected <= 0;
		    end
		end else if (state == OBSERVE_OUTPUT) begin
		    IP_output <= wb_data_o[READ_DATA_WIDTH-1:0];  // Capture SHA result or status

		    crash_detected <= (wb_data_o === 32'hXXXX || wb_data_o === 32'hZZZZ || wb_err);

		end else begin
		    wait_counter     <= 0;
		    hang_detected    <= 0;
		    crash_detected   <= 0;
		end
	end


	always_ff @(posedge clk) begin
		if (!rst_n) begin
		    overflow_detected <= 0;
		end else if (state == OBSERVE_OUTPUT) begin
		    // Flag error if response is not expected
		    if (wb_err || wb_data_o === 32'hXXXX || wb_data_o === 32'hZZZZ) // Example: unexpected value
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
    //output logic [DATA_WIDTH-1:0] random_numbers [BUFFER_DEPTH-1:0],
	output test_pattern_t random_numbers [BUFFER_DEPTH-1:0],

    output logic ready
);

	/*typedef struct packed {
		logic [31:0] addr;
		logic [31:0] data;
	} test_pattern_t;*/

    logic ring_out;
    logic [DATA_WIDTH-1:0] rand_sample;
    test_pattern_t rand_buffer [BUFFER_DEPTH-1:0];

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
                rand_buffer[i].addr <= i * 4; // Sequential addresses (0x00, 0x04, ..., 0x3C)
				rand_buffer[i].data <= rand_sample;
            end
            ready <= 1'b1;
        end
    end

    // Assign generated numbers to output
    assign random_numbers = rand_buffer;

endmodule



