module satellite_fuzzer #(
    parameter WATCHDOG_LIMIT = 50, // Cycles before declaring a hang
    parameter TRACE_DEPTH = 64

)(
    input  logic         clk,
    input  logic         rst_n,

    // Control Signal
    input  logic         fuzz_en,      // 1: Fuzzing Mode, 0: Normal Mode
 
    // System Bus Interface (Example signals)
    input  logic                bus_start,
    input  logic [127:0]        bus_state,
    input  logic [127:0]        bus_key,

    // AES outputs
    output logic [127:0]       aes_out,
    output logic               aes_out_valid,
    
    // Anomaly Alarms
    output logic         alarm_timeout,
    output logic         alarm_collision,

    // Anomalous snapshot ports
    output logic [127:0]   error_key,
    output logic [127:0]   error_state,
    output logic [127:0]   error_out

);
 
    // --- Internal Signals ---

    logic [255:0] prng_data;
    logic         prng_valid;
    logic         fuzz_start;
    logic [127:0] last_ciphertext;

    logic [127:0] current_fuzz_state;
    logic [127:0] current_fuzz_key;

    assign current_fuzz_state = prng_data[127:0];
    assign current_fuzz_key   = prng_data[255:128];


    trng #(.OUTPUT_WIDTH(256)) u_prng (
        .clk(clk),
        .rst_n(rst_n),
        .en(fuzz_en),
        .data_o(prng_data),
        .valid_o(prng_valid)

    );
 
    // --- 2. Multiplexer Logic ---

    logic mux_start;
    logic [127:0] mux_state, mux_key;
 
    assign mux_start  = fuzz_en ? fuzz_start : bus_start;
    assign mux_state  = fuzz_en ? prng_data[1023:0]    : bus_state;
    assign mux_key = fuzz_en ? prng_data[255:128] : bus_key;
 
    

    aes_128 aes_128_inst (
        .clk(clk),
        .start(mux_start),
        .state(mux_state),
        .key(mux_key),
        .out(aes_out),
        .out_valid(aes_out_valid)
    );
 
    // --- 4. Fuzzer Control & Monitoring FSM ---

    typedef enum logic [1:0] {IDLE, TRIGGER, MONITOR, HALT} state_t;
    state_t state;

    logic [7:0] timer;
    logic first_run_done;
    logic [255:0] last_full_input;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fuzz_start <= 0;
            timer <= 0;
            first_run_done <= 0;
            alarm_timeout <= 0;
            alarm_collision <= 0;
            last_ciphertext <= 0;
            error_key <= 0;
            error_state <= 0;
            error_out <= 0;
        end else if (fuzz_en) begin
            case (state)
                IDLE: begin
                    // Wait for PRNG to have a block and SHA to be ready
                    if (prng_valid) begin
                        fuzz_start <= 1;
                        state <= TRIGGER;
                    end
                end
                TRIGGER: begin
                    fuzz_start <= 0;
                    timer <= 0;
                    state <= MONITOR;
                end
                MONITOR: begin
                    timer <= timer + 1;
                    // A. Timeout Detection
                    if (timer > WATCHDOG_LIMIT) begin
                        alarm_timeout <= 1;
                        error_key <= mux_key;
                        error_state <= mux_state;
                        error_out <= 128'hAAAA; //mark as invalid
                        state <= HALT;
                    end
                    if (aes_out_valid) begin
                        // B. Collision Detection
                        if (first_run_done && (aes_out == last_ciphertext) && ({mux_key, mux_state} != last_full_input)) begin
                            alarm_collision <= 1;
                            error_key <= mux_key;
                            error_state <= mux_state;
                            error_out <= aes_out;
                            state <= HALT;
                        end
                        last_ciphertext <= aes_out;
                        last_full_input <= {mux_key, mux_state};
                        first_run_done <= 1;
                        state <= IDLE;
                    end
                end
                HALT: begin
                    // Remain in HALT until reset
                    fuzz_start <= 0;
                end
            endcase
        end
    end
 
    // --- 5. Circular Trace Buffer ---

    logic [383:0] trace_mem [TRACE_DEPTH]; //3*128 = 384 bits wide [key, state, out]
    logic [$clog2(TRACE_DEPTH)-1:0] wr_ptr;
 
    always @(posedge clk) begin
        if (aes_out_valid && fuzz_en && state != HALT) begin
            trace_mem[wr_ptr] <= {mux_key, mux_state, aes_out};
            wr_ptr <= wr_ptr + 1;
        end
    end
 
endmodule
 