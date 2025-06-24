`timescale 1ns / 1ps

module top_module #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter EXT_RW_WIDTH    = 256,
    parameter READ_DATA_WIDTH = 64,
    parameter BUFFER_DEPTH    = 8,
    parameter MAX_WAIT_CYCLES = 100,
    parameter TEST_PATTERN    = 15,
    parameter MUTATION_WIDTH  = 8
)(
    input  logic clk,
    input  logic rst,

    // Wishbone Slave Interface (from Central Fuzzer)
    input  logic                        wbs_cyc_i,
    input  logic                        wbs_stb_i,
    input  logic                        wbs_we_i,
    input  logic [ADDR_WIDTH-1:0]       wbs_adr_i,
    input  logic [DATA_WIDTH-1:0]       wbs_dat_i,
    output logic [DATA_WIDTH-1:0]       wbs_dat_o,
    input  logic [DATA_WIDTH/8-1:0]     wbs_sel_i,
    input  logic [2:0]                  wbs_cti_i,
    input  logic [1:00]                  wbs_bte_i,
    output logic                        wbs_ack_o,

    // Wishbone Master Interface (to Central Fuzzer)
    output logic                        wbm_cyc_o,
    output logic                        wbm_stb_o,
    output logic                        wbm_we_o,
    output logic [ADDR_WIDTH-1:0]       wbm_adr_o,
    output logic [DATA_WIDTH-1:0]       wbm_dat_o,
    input  logic [DATA_WIDTH-1:0]       wbm_dat_i,
    output logic [DATA_WIDTH/8-1:0]     wbm_sel_o,
    output logic [2:0]                  wbm_cti_o,
    output logic [1:0]                  wbm_bte_o,
    input  logic                        wbm_ack_i
);

    // Internal wires for Ext IO between Bus Interface and Satellite Fuzzer
    logic                        ext_master_req;
    logic                        ext_master_we;
    logic [ADDR_WIDTH-1:0]       ext_master_addr_read;
    logic [ADDR_WIDTH-1:0]       ext_master_addr_write;
    logic [EXT_RW_WIDTH-1:0]     ext_master_wdata;
    logic [EXT_RW_WIDTH-1:0]     ext_master_rdata;
    logic                        ext_master_read_done;
    logic                        ext_master_write_done;

    logic [EXT_RW_WIDTH-1:0]     ext_slave_wdata;
    logic                        ext_slave_we;
    logic [ADDR_WIDTH-1:0]       ext_slave_addr_read;
    logic [ADDR_WIDTH-1:0]       ext_slave_addr_write;
    logic [EXT_RW_WIDTH-1:0]     ext_slave_rdata;
    logic                        ext_slave_read_done;
    logic                        ext_slave_write_done;

    // Ack outputs from satellite fuzzer
    logic ack_rand, ack_mut;

    // Instantiate Wishbone Interface Module (Bus)
    wishbone_dual #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .EXT_RW_WIDTH(EXT_RW_WIDTH)
    ) u_bus_interface (
        .clk(clk),
        .rst(rst),

        // Connect to Central Fuzzer (top-level I/Os)
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_we_i(wbs_we_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_dat_o(wbs_dat_o),
        .wbs_sel_i(wbs_sel_i),
        .wbs_cti_i(wbs_cti_i),
        .wbs_bte_i(wbs_bte_i),
        .wbs_ack_o(wbs_ack_o),

        .wbm_cyc_o(wbm_cyc_o),
        .wbm_stb_o(wbm_stb_o),
        .wbm_we_o(wbm_we_o),
        .wbm_adr_o(wbm_adr_o),
        .wbm_dat_o(wbm_dat_o),
        .wbm_dat_i(wbm_dat_i),
        .wbm_sel_o(wbm_sel_o),
        .wbm_cti_o(wbm_cti_o),
        .wbm_bte_o(wbm_bte_o),
        .wbm_ack_i(wbm_ack_i),

        // Connect to Satellite Fuzzer (Ext IO)
        .ext_master_req(ext_master_req),
        .ext_master_we(ext_master_we),
        .ext_master_addr_read(ext_master_addr_read),
        .ext_master_addr_write(ext_master_addr_write),
        .ext_master_wdata(ext_master_wdata),
        .ext_master_rdata(ext_master_rdata),
        .ext_master_read_done(ext_master_read_done),
        .ext_master_write_done(ext_master_write_done),

        .ext_slave_wdata(ext_slave_wdata),
        .ext_slave_we(ext_slave_we),
        .ext_slave_addr_read(ext_slave_addr_read),
        .ext_slave_addr_write(ext_slave_addr_write),
        .ext_slave_rdata(ext_slave_rdata),
        .ext_slave_read_done(ext_slave_read_done),
        .ext_slave_write_done(ext_slave_write_done)
    );

    // Instantiate Satellite Fuzzer Wrapper
    satellite_fuzzer_wrapper #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .READ_DATA_WIDTH(READ_DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH),
        .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES),
        .TEST_PATTERN(TEST_PATTERN),
        .EXT_RW_WIDTH(EXT_RW_WIDTH),
        .MUTATION_WIDTH(MUTATION_WIDTH)
    ) u_satellite_fuzzer (
        .clk(clk),
        .rst_n(~rst),
        .ext_master_req(ext_master_req),
        .ext_master_we(ext_master_we),
        .ext_master_addr_read(ext_master_addr_read),
        .ext_master_addr_write(ext_master_addr_write),
        .ext_master_wdata(ext_master_wdata),
        .ext_master_rdata(ext_master_rdata),
        .ext_master_read_done(ext_master_read_done),
        .ext_master_write_done(ext_master_write_done),

        .ext_slave_wdata(ext_slave_wdata),
        .ext_slave_we(ext_slave_we),
        .ext_slave_addr_read(ext_slave_addr_read),
        .ext_slave_addr_write(ext_slave_addr_write),
        .ext_slave_rdata(ext_slave_rdata),
        .ext_slave_read_done(ext_slave_read_done),
        .ext_slave_write_done(ext_slave_write_done)
	);


endmodule
