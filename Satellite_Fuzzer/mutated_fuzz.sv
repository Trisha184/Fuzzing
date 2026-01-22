module mutated_fuzz #(
    parameter INPUT_WIDTH = 256, //total bits of input combined
    parameter OUTPUT_WIDTH = 128, //total bits of output combined
    parameter WATCHDOG_LIMIT = 1000,
    parameter TRACE_DEPTH = 32,
    parameter POOL_DEPTH = 16 //number of golden seeds to store
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic                     mut_en,

    input  logic [INPUT_WIDTH-1:0]                    bus_input,
    input  logic                     bus_start,
    
    output logic [INPUT_WIDTH-1:0]  fuzz_to_ip_data,
    output logic                     fuzz_to_ip_start,
    input logic                     ip_to_fuzz_ready,
    input logic [OUTPUT_WIDTH-1:0]   ip_to_fuzz_data,
    input  logic                     ip_to_fuzz_valid,

    output logic                     alarm_hang,
    output logic                     alarm_collision,

    output logic [7:0]               coverage_score,

    output logic [INPUT_WIDTH-1:0]    error_input,
    output logic [OUTPUT_WIDTH-1:0]     error_output
);


// Seed Pool (learning phase)
logic [INPUT_WIDTH-1:0] seed_pool [POOL_DEPTH];
logic [$clog2(POOL_DEPTH)-1:0] pool_ptr;
logic pool_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pool_ptr <= 0;
        pool_ready <= 0;
    end else if (bus_start && !mut_en) begin
        seed_pool[pool_ptr] <= bus_input;
        pool_ptr <= pool_ptr + 1;
        if (pool_ptr == POOL_DEPTH - 1) begin
            pool_ready <= 1;
        end
    end
end

// Mutation Logic
logic [31:0] mut_lfsr;
logic [INPUT_WIDTH-1:0] selected_seed;
logic [INPUT_WIDTH-1:0] mutated_data;


assign selected_seed = seed_pool[mut_lfsr[$clog2(POOL_DEPTH)-1:0]];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mut_lfsr <= 32'hACE1; 
    end else begin
        mut_lfsr <= {mut_lfsr[30:0], mut_lfsr[31] ^ mut_lfsr[21] ^ mut_lfsr[1]};
    end
end

always_comb begin
    mutated_data = selected_seed;
    /// Bit-flip mutation: XOR the data with a "one-hot" mask based on LFSR
    mutated_data[mut_lfsr[$clog2(INPUT_WIDTH)-1:0]] = ~selected_seed[mut_lfsr[$clog2(INPUT_WIDTH)-1:0]];
end

initial begin
    for (int i = 0; i < POOL_DEPTH; i++) begin
        seed_pool[i] = '0;
    end
end

typedef enum logic [1:0] {IDLE, TRIGGER, MONITOR, HALT} state_t;
state_t state;
logic [31:0] timer;

logic [OUTPUT_WIDTH-1:0] last_result;

logic first_run_done;
logic [INPUT_WIDTH-1:0] last_full_input;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        fuzz_to_ip_start <= 0;
        first_run_done <= 0;
        {alarm_hang, alarm_collision} <= '0;
        {error_input, error_output} <= '0;
    end else if (mut_en && pool_ready) begin
        case (state)
            IDLE: begin
                if (ip_to_fuzz_ready) begin
                    fuzz_to_ip_data  <= mutated_data;
                    fuzz_to_ip_start <= 1;
                    state <= TRIGGER;
                end
            end 
            TRIGGER: begin
                fuzz_to_ip_start <= 0;
                timer <= 0;
                state <= MONITOR;
            end
            MONITOR: begin
                timer <= timer + 1;
                if (timer > WATCHDOG_LIMIT) begin
                    alarm_hang <= 1;
                    error_input <= fuzz_to_ip_data;
                    state <= HALT;
                end 
                if (ip_to_fuzz_valid) begin
                    // Collision detection logic can be added here
                    last_result <= ip_to_fuzz_data;
                    last_full_input <= fuzz_to_ip_data;
                    first_run_done <= 1;
                    state <= IDLE;
                end
            end
            HALT: begin
                fuzz_to_ip_start <= 0;
            end
        endcase
    end else if (!mut_en) begin
        state <= IDLE;
    end
end

// -----Circular trace buffer----
logic [INPUT_WIDTH+OUTPUT_WIDTH-1:0] trace_mem [TRACE_DEPTH];
logic [$clog2(TRACE_DEPTH)-1:0] wr_ptr;

always @(posedge clk) begin
    if (ip_to_fuzz_valid && mut_en && state != HALT) begin
        trace_mem[wr_ptr] <= {fuzz_to_ip_data, ip_to_fuzz_data};
        wr_ptr <= wr_ptr + 1;
    end
end

// ---- Coverage Monitor ------
logic [INPUT_WIDTH-1:0] seen_h, seen_l;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        seen_h <= '0;
        seen_l <= '0;
    end else if (fuzz_to_ip_start) begin
        seen_h <= seen_h | fuzz_to_ip_data;
        seen_l <= seen_l | ~fuzz_to_ip_data;
    end
end

logic [31:0] count;

 logic [31:0] count_bits;
 
    // 2. The calculation block
    always_comb begin : coverage_calculation
        // Local variable must be 'int' and initialized to 0 EVERY time the block triggers
        int temp_count; 
        temp_count = 0; 
        for (int i = 0; i < INPUT_WIDTH; i = i + 1) begin
            // Check for valid 1 and 0 (prevents 'x' or 'z' from counting)
            if ((seen_h[i] === 1'b1) && (seen_l[i] === 1'b1)) begin
                temp_count = temp_count + 1;
            end
        end
        // Drive the module-level signal
        count_bits = temp_count;
        // Final Score Math
        if (INPUT_WIDTH > 0) begin
            // Casting to 64-bit prevents overflow during the multiplication
            coverage_score = 8'((64'(count_bits) * 100) / INPUT_WIDTH);
        end else begin
            coverage_score = 8'h0;
        end
    end

always @(posedge clk) begin
    if (fuzz_to_ip_start) begin
        $display("[%0t] COVERAGE INTERNALS: count_bits=%0d, seen_l_sample=%b", $time, count_bits, seen_l[7:0]);
    end
end


endmodule