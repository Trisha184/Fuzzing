module top_tb;

localparam INPUT_WIDTH = 256;
localparam OUTPUT_WIDTH = 128;
localparam WATCHDOG_LIMIT = 1000;
localparam TRACE_DEPTH = 32;

logic                     clk;
logic                     rst_n;
logic                     fuzz_en;

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

top_wrapper #(
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
    $dumpvars(0, top_tb);

    rst_n = 0;
    fuzz_en = 0;
    bus_input = '0;
    bus_start = 0;

    $display("[%0t] System Reset..........", $time);
    #100
    rst_n = 1;
    #50

    // Normal bus mode
    $display("[%0t] Starting Normal Bus Mode...", $time);
    wait(bus_ready);
    @(posedge clk);
    bus_start = 1;
    bus_input = $urandom_range(0, 2**INPUT_WIDTH-1);
    @(posedge clk);
    bus_start = 0;

    wait(bus_output_valid);
    $display("[%0t] Bus Output Received: %0h", $time, bus_output);
    #100;

    // Fuzzing mode
    $display("[%0t] Enabling Fuzzing Mode...", $time);
    fuzz_en = 1;
    #250000;

    // $display("[%0t] !!! Injecting Hang !!!!", $time);
    // force u_top.u_aes128.out_valid = 0;
    // wait(alarm_hang);

    if (alarm_hang || alarm_collision) begin
        $display("\n[!] Anomaly Detected!");
        $display("    Alarm Hang: %0b", alarm_hang);
        $display("    Alarm Collision: %0b", alarm_collision);
        $display("    Error Input: %0h", error_input);
        $display("    Error Output: %0h", error_output);
    end else begin
        $display("\n[*] Fuzzing Completed without Anomalies.");
        $display("    Final Coverage Score: %0d", coverage_score);
    end

    // release u_top.u_aes128.out_valid;

    $finish;
end

initial begin
    $vcdpluson;
end

endmodule