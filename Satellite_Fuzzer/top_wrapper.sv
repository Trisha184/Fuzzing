module top_wrapper #(
    parameter INPUT_WIDTH = 256, //total bits of input combined
    parameter OUTPUT_WIDTH = 128, //total bits of output combined
    parameter WATCHDOG_LIMIT = 1000,
    parameter TRACE_DEPTH = 32
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic [1:0]                    fuzz_en, // 00 = normal, 01 = random, 10 = mutated

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

logic rand_en;
logic mut_en;

assign rand_en = (fuzz_en == 2'b01) ? 1'b1 : 1'b0;
assign mut_en  = (fuzz_en == 2'b10) ? 1'b1 : 1'b0;

logic [INPUT_WIDTH-1:0]  rand_to_ip_data;
logic                     rand_to_ip_start;

logic [INPUT_WIDTH-1:0]  mut_to_ip_data;
logic                     mut_to_ip_start;


logic [INPUT_WIDTH-1:0]  mux_input;
logic                     mux_start;

logic [OUTPUT_WIDTH-1:0]   ip_out_data;
logic                     ip_out_valid;
logic                     ip_ready;

logic   rand_hang, rand_col;
logic [7:0] rand_coverage;
logic [INPUT_WIDTH-1:0]    rand_err_in;
logic [OUTPUT_WIDTH-1:0]     rand_err_out;

logic   mut_hang, mut_col;
logic [7:0] mut_coverage;
logic [INPUT_WIDTH-1:0]    mut_err_in;
logic [OUTPUT_WIDTH-1:0]     mut_err_out;


// assign mux_input = fuzz_en ? fuzz_to_ip_data : bus_input;
// assign mux_start = fuzz_en ? fuzz_to_ip_start : bus_start;

always_comb begin
    case (fuzz_en)
        2'b01: begin
            mux_input = rand_to_ip_data;
            mux_start = rand_to_ip_start;
            alarm_hang = rand_hang;
            alarm_collision = rand_col;
            coverage_score = rand_coverage;
            error_input = rand_err_in;
            error_output = rand_err_out;
        end
        2'b10: begin
            mux_input = mut_to_ip_data;
            mux_start = mut_to_ip_start;
            alarm_hang = mut_hang;
            alarm_collision = mut_col;
            coverage_score = mut_coverage;
            error_input = mut_err_in;
            error_output = mut_err_out;
        end
        default: begin
            mux_input = bus_input;
            mux_start = bus_start;
            alarm_hang = 1'b0;
            alarm_collision = 1'b0;
            coverage_score = 8'd0;
            error_input = {INPUT_WIDTH{1'b0}};
            error_output = {OUTPUT_WIDTH{1'b0}};
        end
    endcase
end

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
    .rand_en(rand_en),
    .fuzz_to_ip_data(rand_to_ip_data),
    .fuzz_to_ip_start(rand_to_ip_start),
    .ip_to_fuzz_ready(ip_ready),
    .ip_to_fuzz_data(ip_out_data),
    .ip_to_fuzz_valid(ip_out_valid),
    .alarm_hang(rand_hang),
    .alarm_collision(rand_col),
    .coverage_score(rand_coverage),
    .error_input(rand_err_in),
    .error_output(rand_err_out)
);

mutated_fuzz #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .WATCHDOG_LIMIT(WATCHDOG_LIMIT),
    .POOL_DEPTH(16)
) u_mutated_fuzzer (
    .clk(clk),
    .rst_n(rst_n),
    .mut_en(mut_en),
    .bus_input(bus_input),
    .bus_start(bus_start),
    .fuzz_to_ip_data(mut_to_ip_data),
    .fuzz_to_ip_start(mut_to_ip_start),
    .ip_to_fuzz_ready(ip_ready),
    .ip_to_fuzz_data(ip_out_data),
    .ip_to_fuzz_valid(ip_out_valid),
    .alarm_hang(mut_hang), 
    .alarm_collision(mut_col), 
    .coverage_score(mut_coverage), 
    .error_input(mut_err_in), 
    .error_output(mut_err_out) 
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