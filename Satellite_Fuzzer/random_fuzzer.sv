module random_fuzzer #(
    parameter INPUT_WIDTH = 256, //total bits of input combined
    parameter OUTPUT_WIDTH = 128, //total bits of output combined
    parameter WATCHDOG_LIMIT = 1000,
    parameter TRACE_DEPTH = 32
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic                     rand_en,
    
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

logic [INPUT_WIDTH-1:0] prng_data;
logic                   prng_valid;

trng #(.OUTPUT_WIDTH(INPUT_WIDTH)) u_prng (
        .clk(clk),
        .rst_n(rst_n),
        .en(rand_en),
        .data_o(prng_data),
        .valid_o(prng_valid)

);

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
    end else if (rand_en) begin
        case (state)
            IDLE: begin
                if (prng_valid && ip_to_fuzz_ready) begin
                    fuzz_to_ip_data  <= prng_data;
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
                    if (first_run_done && (ip_to_fuzz_data == last_result) && (fuzz_to_ip_data != last_full_input)) begin
                        alarm_collision <= 1;
                        error_input <= fuzz_to_ip_data;
                        error_output <= ip_to_fuzz_data;
                        state <= HALT;
                    end
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
    end
end

// -----Circular trace buffer----
logic [INPUT_WIDTH+OUTPUT_WIDTH-1:0] trace_mem [TRACE_DEPTH];
logic [$clog2(TRACE_DEPTH)-1:0] wr_ptr;

always @(posedge clk) begin
    if (ip_to_fuzz_valid && rand_en && state != HALT) begin
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

// always_comb begin
//     integer temp_count = 0;
    
//     for (int i = 0; i < INPUT_WIDTH; i++) begin
//         if (seen_h[i] == 1'b1 && seen_l[i] == 1'b1) begin
//             temp_count = temp_count + 1;
//         end
//     end
//     count = temp_count;
//     coverage_score = (count * 100) / INPUT_WIDTH;
// end

// 1. Declare at the module level
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