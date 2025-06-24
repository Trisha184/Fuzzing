`timescale 1ns / 1ps

module satellite_fuzzer_wrapper #(
    parameter int DATA_WIDTH      = 32,
    parameter int READ_DATA_WIDTH = 64,
    parameter int BUFFER_DEPTH    = 8,
    parameter int MAX_WAIT_CYCLES = 100,
    parameter int TEST_PATTERN    = 15,
    parameter int ADDR_WIDTH      = 32,
    parameter int EXT_RW_WIDTH    = 256,
	parameter int MUTATION_WIDTH  = 8
)(
    input  logic clk,
    input  logic rst_n,

	// External Master Interface (Satellite -> Central Fuzzer)
	output  logic                        ext_master_req,
	output  logic                        ext_master_we,
	output  logic [ADDR_WIDTH-1:0]       ext_master_addr_read,
	output  logic [ADDR_WIDTH-1:0]       ext_master_addr_write,
	output  logic [EXT_RW_WIDTH-1:0]     ext_master_wdata,
	input logic [EXT_RW_WIDTH-1:0]     ext_master_rdata,
	input logic                        ext_master_read_done,
	input logic                        ext_master_write_done,

	// External Slave Interface (Central Fuzzer -> Satellite)
	output  logic [EXT_RW_WIDTH-1:0]     ext_slave_wdata,
	input  logic                        ext_slave_we,
	input  logic [ADDR_WIDTH-1:0]       ext_slave_addr_read,
	input  logic [ADDR_WIDTH-1:0]       ext_slave_addr_write,
	input logic [EXT_RW_WIDTH-1:0]     ext_slave_rdata,
	input logic                        ext_slave_read_done,
	input logic                        ext_slave_write_done,

    // GPIO outputs
    output logic ack_rand,
    output logic ack_mut
);

    // ------------------------------------------
    // Internal registers
    // ------------------------------------------
    logic [1:0] fuzz_mode_reg;
    logic [READ_DATA_WIDTH-1:0] status_reg;



    // Random fuzzer outputs
    logic [ADDR_WIDTH-1:0] rand_fuzz_addr;
	logic [DATA_WIDTH-1:0] rand_fuzz_data;
	logic  rand_fuzz_we, rand_fuzz_stb, rand_fuzz_cyc;
    logic [3:0]  rand_fuzz_sel;

    logic        crash_detected_random, hang_detected_random, overflow_detected_random;
	// Mutated fuzzer outputs
    logic [ADDR_WIDTH-1:0] mut_fuzz_addr;
	logic [DATA_WIDTH-1:0] mut_fuzz_data;
	logic  mut_fuzz_we, mut_fuzz_stb, mut_fuzz_cyc;
    logic [3:0]  mut_fuzz_sel;

    logic        crash_detected_mutated, hang_detected_mutated, overflow_detected_mutated, mismatch_detected_mutated;

    // SHA-256 IP Instance (DUT under fuzzing)

	// To IP connection signals.......
    logic [31:0] sha_wb_adr;
    logic        sha_wb_cyc, sha_wb_stb, sha_wb_we;
    logic [DATA_WIDTH-1:0] sha_wb_dat_i;
    logic [(DATA_WIDTH/8)-1:0] sha_wb_sel;
    logic        sha_wb_ack, sha_wb_err;
    logic [READ_DATA_WIDTH-1:0] sha_wb_dat_o;
    logic        sha_int;
	logic sha_clk, sha_rst_n;

	// From SoC just monitoring
    logic [31:0] monitor_adr;
    logic        monitor_cyc, monitor_stb, monitor_we;
    logic [DATA_WIDTH-1:0] monitor_dat_i;
    logic [(DATA_WIDTH/8)-1:0] monitor_sel;

	logic monitor_clk, monitor_rst_n;


	// From mutated fuzzer or random fuzzer
    logic [31:0] mutran_wb_adr;
    logic        mutran_wb_cyc, mutran_wb_stb, mutran_wb_we;
    logic [DATA_WIDTH-1:0] mutran_wb_dat_i;
    logic [(DATA_WIDTH/8)-1:0] mutran_wb_sel;


	// Fuzz path control
	logic use_fuzz_inputs;
	logic mutated_trigger;

	// mux implemented to monitor or apply test to an IP block...
	assign sha_clk = monitor_clk;  // only monitoring
	assign sha_rst_n = monitor_rst_n; // only monitoring

	assign sha_wb_adr = use_fuzz_inputs ? mutran_wb_adr : monitor_adr;
	assign sha_wb_cyc = use_fuzz_inputs ? mutran_wb_cyc : monitor_cyc;
	assign sha_wb_dat_i = use_fuzz_inputs ? mutran_wb_dat_i : monitor_dat_i;
	assign sha_wb_sel = use_fuzz_inputs ? mutran_wb_sel : monitor_sel;
	assign sha_wb_stb = use_fuzz_inputs ? mutran_wb_stb : monitor_stb;
	assign sha_wb_we = use_fuzz_inputs ? mutran_wb_we : monitor_we;

	//assign sha_wb_ack = monitor_ack // output only monitoring
	//assign sha_wb_err = monitor_err // output only monitoring
	//assign sha_wb_dat_o = monitor_dat_o // output only monitoring
	//assign sha_int = monitor_int    // output only monitoring


	//control logic of monitoring or driving
	assign use_fuzz_inputs =  mutated_trigger;

    sha256_top dut (
        .wb_clk_i(sha_clk),   ///if you want to monitor the clk, rst
        .wb_rst_i(sha_rst_n),
        .wb_adr_i(sha_wb_adr),
        .wb_cyc_i(sha_wb_cyc),
        .wb_dat_i(sha_wb_dat_i),
        .wb_sel_i(sha_wb_sel),
        .wb_stb_i(sha_wb_stb),
        .wb_we_i(sha_wb_we),
        .wb_ack_o(sha_wb_ack),
        .wb_err_o(sha_wb_err),
        .wb_dat_o(sha_wb_dat_o),
        .int_o(sha_int)
    );

    // ------------------------------------------
    // Wishbone Slave Logic - control input
    // ------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fuzz_mode_reg <= 2'b00;
        else if (ext_slave_we && ext_slave_addr_write[7:0] == 8'h00)
            fuzz_mode_reg <= ext_slave_rdata[1:0];
    end

	assign ext_slave_wdata = (ext_slave_addr_read[7:0] == 8'h00) ? {30'b0, fuzz_mode_reg} :
		                     (ext_slave_addr_read[7:0] == 8'h04) ? status_reg[31:0] :
		                     32'hDEADBEEF;

	assign ext_slave_read_done = 1'b1; // Always ready OR gate this with your FSM if needed

    // ------------------------------------------
    // sha256 selection logic based on fuzz mode
    // ------------------------------------------
    always_comb begin
        // Default idle (all zero)
        sha_wb_adr   = 32'd0;
        sha_wb_dat_i = '0;
        sha_wb_we    = 1'b0;
        sha_wb_stb   = 1'b0;
        sha_wb_sel   = '0;
        sha_wb_cyc   = 1'b0;

        case (fuzz_mode_reg)
            2'b01: begin  // Random Fuzzer
                sha_wb_adr   = rand_fuzz_addr;
                sha_wb_dat_i = rand_fuzz_data;
                sha_wb_we    = rand_fuzz_we;
                sha_wb_stb   = rand_fuzz_stb;
                sha_wb_sel   = rand_fuzz_sel;
                sha_wb_cyc   = rand_fuzz_cyc;
            end
            2'b10: begin  // Mutated Fuzzer
                sha_wb_adr   = mut_fuzz_addr;
                sha_wb_dat_i = mut_fuzz_data;
                sha_wb_we    = mut_fuzz_we;
                sha_wb_stb   = mut_fuzz_stb;
                sha_wb_sel   = mut_fuzz_sel;
                sha_wb_cyc   = mut_fuzz_cyc;
            end
            default: ; // stay idle
        endcase
    end

    // ------------------------------------------
    // Instantiate Fuzzers
    // ------------------------------------------
    // Random Fuzzer
    random_fuzzer #(.DATA_WIDTH(DATA_WIDTH), .READ_DATA_WIDTH(READ_DATA_WIDTH), .BUFFER_DEPTH(BUFFER_DEPTH), .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES)) rand_fuzz (
        .clk(clk),
        .rst_n(rst_n),
        .enable(fuzz_mode_reg == 2'b01),
        .wb_addr(mutran_wb_adr),
        .wb_data(mutran_wb_dat_i),
        .wb_sel(mutran_wb_sel),
        .wb_stb(mutran_wb_stb),
        .wb_cyc(mutran_wb_cyc),
        .wb_we(mutran_wb_we),
        .wb_ack(sha_wb_ack),
        .wb_err(sha_wb_err),
        .wb_data_o(sha_wb_dat_o),
		.int_(sha_int),
        .ack(ack_rand),
        .crash_detected(crash_detected_random),
        .hang_detected(hang_detected_random),
        .overflow_detected(overflow_detected_random)
    );

    // Mutated Fuzzer
    mutated_fuzzer #(.TEST_PATTERN(TEST_PATTERN), .READ_DATA_WIDTH(READ_DATA_WIDTH), .BUFFER_DEPTH(BUFFER_DEPTH), .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES), .MUTATION_WIDTH(MUTATION_WIDTH)) mut_fuzz (
        .clk(clk),
        .rst_n(rst_n),
		.trigger(mutated_trigger),   //triggering for monitoring and applying tests from mutated fuzzer
        .enable(fuzz_mode_reg == 2'b10),
		// monitoring signals....
        .wb_mon_addr(monitor_adr),
        .wb_mon_data(monitor_dat_i),
        .wb_mon_sel(monitor_sel),
        .wb_mon_stb(monitor_stb),
        .wb_mon_cyc(monitor_cyc),
        .wb_mon_we(monitor_we),

        .wb_addr(mutran_wb_adr),
        .wb_data(mutran_wb_dat_i),
        .wb_sel(mutran_wb_sel),
        .wb_stb(mutran_wb_stb),
        .wb_cyc(mutran_wb_cyc),
        .wb_we(mutran_wb_we),
        .wb_ack(sha_wb_ack),
        .wb_err(sha_wb_err),
        .wb_data_o(sha_wb_dat_o),
		.int_(sha_int),
        .ack(ack_mut),
        .crash_detected(crash_detected_mutated),
        .hang_detected(hang_detected_mutated),
        .overflow_detected(overflow_detected_mutated),
        .mismatch_detected(mismatch_detected_mutated)
    );

    // ------------------------------------------
    // Status Register Update Logic
    // ------------------------------------------
    always_comb begin
        case (fuzz_mode_reg)
            2'b01: begin
                if (crash_detected_random)
                    status_reg = 32'hDEAD0001;
                else if (hang_detected_random)
                    status_reg = 32'hBEEF0001;
                else if (overflow_detected_random)
                    status_reg = 32'hC0DE0001;
                else
                    status_reg = 32'h00000001;
            end
            2'b10: begin
                if (crash_detected_mutated)
                    status_reg = 32'hDEAD0002;
                else if (hang_detected_mutated)
                    status_reg = 32'hBEEF0002;
                else if (overflow_detected_mutated)
                    status_reg = 32'hC0DE0002;
                else if (mismatch_detected_mutated)
                    status_reg = 32'hFFFF0002;
                else
                    status_reg = 32'h00000002;
            end
            default: status_reg = 32'h00000000;
        endcase
    end

    // ------------------------------------------
    // Wishbone Master Logic - report issues
    // ------------------------------------------
	typedef enum logic [1:0] {
		IDLE, ISSUE_DETECTED, WAIT_DONE
	} ext_master_state_e;

	ext_master_state_e ext_master_state;
	logic ext_master_req_reg;

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
		    ext_master_state <= IDLE;
		    ext_master_req_reg <= 0;
		end else begin
		    case (ext_master_state)
		        IDLE: begin
		            if ((fuzz_mode_reg == 2'b01 && (crash_detected_random || hang_detected_random || overflow_detected_random)) ||
		                (fuzz_mode_reg == 2'b10 && (crash_detected_mutated || hang_detected_mutated || overflow_detected_mutated || mismatch_detected_mutated))) begin
		                ext_master_state <= ISSUE_DETECTED;
		                ext_master_req_reg <= 1;
		            end
		        end
		        ISSUE_DETECTED: begin
		            ext_master_state <= WAIT_DONE;
		        end
		        WAIT_DONE: begin
		            if (ext_master_write_done)
		                ext_master_state <= IDLE;
		        end
		    endcase
		end
	end

	assign ext_master_req         = ext_master_req_reg;
	assign ext_master_we          = 1'b1;
	assign ext_master_addr_write  = 32'h80000000;
	assign ext_master_wdata       = {{(EXT_RW_WIDTH-32){1'b0}}, status_reg[31:0]};
	assign ext_master_addr_read   = 32'h00000000;  // unused


endmodule
