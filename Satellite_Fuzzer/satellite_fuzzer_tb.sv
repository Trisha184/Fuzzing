module satellite_fuzzer_tb;

localparam INPUT_WIDTH = 256;
localparam OUTPUT_WIDTH = 128;
localparam WATCHDOG_LIMIT = 1000;
localparam TRACE_DEPTH = 32;

logic                     clk;
logic                     rst_n;
logic  [1:0]                   fuzz_en;

logic [INPUT_WIDTH-1:0]        bus_input;
logic                          bus_start;
logic [OUTPUT_WIDTH-1:0]       bus_output;
logic                          bus_output_valid;
logic                          bus_ready;

logic                     alarm_hang;
logic                     alarm_collision;
logic [7:0]               coverage_score;
logic [INPUT_WIDTH-1:0]    error_input;
logic [OUTPUT_WIDTH-1:0]     error_output;

satellite_fuzzer #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .WATCHDOG_LIMIT(WATCHDOG_LIMIT),
    .TRACE_DEPTH(TRACE_DEPTH)
) u_top (.*);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

always @(coverage_score) begin
    if (fuzz_en) begin
        $display("[%0t] Coverage Score: %0d", $time, coverage_score);
    end
end

always @(posedge clk) begin
    if (u_top.u_random_fuzzer.fuzz_to_ip_start) begin
        $display("[%0t] >> Fuzz Injection: key/state = %0h", $time, u_top.u_random_fuzzer.fuzz_to_ip_data);
    end
end

initial begin
    $dumpfile("top.vcd");
    $dumpvars(0, satellite_fuzzer_tb);

    rst_n = 0;
    fuzz_en = 2'b00;
    bus_input = '0;
    bus_start = 0;

    $display("[%0t] System Reset..........", $time);
    #100
    rst_n = 1;
    #50

    // Normal bus mode for monitoring
    $display("[%0t] Phase 1: Starting Normal Bus Mode...", $time);
    for (int i = 0; i < 16; i++) begin
        wait(bus_ready);
        @(posedge clk);
        bus_input = $urandom;
        bus_start = 1;
        @(posedge clk);
        bus_start = 0;
        wait(bus_output_valid);
        #20;
    end
    $display("[%0t] Phase 1 Complete.", $time);

    // Enable random fuzzing
    $display("[%0t] Phase 2: Starting Random Fuzzing...", $time);
    fuzz_en = 2'b01;
    #100000;
    $display("[%0t] Random Fuzzing Snapshot - Coverage: %0d%%", $time, coverage_score);

    // Mutated Fuzzing
    $display("[%0t] PHASE 3: Switching to MUTATED FUZZING (10)...", $time); 
    fuzz_en = 2'b10; 
    #50000; 
    $display("[%0t] Final Report:", $time); $display(">> Final Coverage: %0d%%", coverage_score); 
    if (alarm_hang || alarm_collision) begin
        $display(">> ANOMALY DETECTED! Input: %h", error_input); 
    end else begin
        $display(">> No anomalies found in this run.");
    end

    $finish;
end

// Optional: Monitor for alarms in real-time 
always @(posedge clk) begin 
    if (alarm_hang) begin
        $display("[%0t] !! ALARM HANG !!", $time); 
    end
    if (alarm_collision) begin
        $display("[%0t] !! ALARM COLLISION !!", $time); 
    end
end

// initial begin
//     $vcdpluson;
// end

endmodule