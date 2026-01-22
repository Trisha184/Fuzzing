module top_wrapper #(
    parameter INPUT_WIDTH = 256, //total bits of input combined
    parameter OUTPUT_WIDTH = 128, //total bits of output combined
    parameter WATCHDOG_LIMIT = 1000,
    parameter TRACE_DEPTH = 32
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic                     fuzz_en,

    // system bus interface
    input logic [INPUT_WIDTH-1:0]        bus_input,
    input logic                          bus_start,
    output logic [OUTPUT_WIDTH-1:0]      bus_output,
    output logic                         bus_output_valid,
    output logic                         bus_ready,

    output logic                     alarm_hang,
    output logic                     alarm_collision,
    output logic [7:0]               coverage_score,

    output logic [INPUT_WIDTH-1:0]    error_input,
    output logic [OUTPUT_WIDTH-1:0]     error_output
);

logic [INPUT_WIDTH-1:0]  fuzz_to_ip_data;
logic                     fuzz_to_ip_start;

logic [INPUT_WIDTH-1:0]  mux_input;
logic                     mux_start;

logic [OUTPUT_WIDTH-1:0]   ip_out_data;
logic                     ip_out_valid;
logic                     ip_ready;

assign mux_input = fuzz_en ? fuzz_to_ip_data : bus_input;
assign mux_start = fuzz_en ? fuzz_to_ip_start : bus_start;

assign bus_output       = ip_out_data;
assign bus_output_valid = ip_out_valid;
assign bus_ready        = ip_ready;

random_fuzzer #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .WATCHDOG_LIMIT(WATCHDOG_LIMIT),
    .TRACE_DEPTH(TRACE_DEPTH)
) u_random_fuzzer (
    .clk(clk),
    .rst_n(rst_n),
    .fuzz_en(fuzz_en),
    .fuzz_to_ip_data(fuzz_to_ip_data),
    .fuzz_to_ip_start(fuzz_to_ip_start),
    .ip_to_fuzz_ready(ip_ready),
    .ip_to_fuzz_data(ip_out_data),
    .ip_to_fuzz_valid(ip_out_valid),
    .alarm_hang(alarm_hang),
    .alarm_collision(alarm_collision),
    .coverage_score(coverage_score),
    .error_input(error_input),
    .error_output(error_output)
);

aes_128 u_aes128 (
    .clk(clk),
    .start(mux_start),
    .state(mux_input[127:0]),
    .key(mux_input[255:128]),
    .out(ip_out_data),
    .out_valid(ip_out_valid)
);

assign ip_ready = 1'b1; // Always ready to accept new input

endmodule