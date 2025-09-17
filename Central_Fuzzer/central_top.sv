module central_top #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter EXT_RW_WIDTH      = 32,
    parameter IP_NUM            = 4, // the number of IP supported
    parameter IP_SELECTOR_WIDTH = 2, 
    parameter TRAFFIC_N         = 2 
)(
    input clk,
    input rst,

    input wire [1:0]                            mode_selector,
    input wire [IP_SELECTOR_WIDTH-1:0]          ip_selector,

    output logic [EXT_RW_WIDTH-1:0]             corner_case_payload,

    // Wishbone Slave Interface 
    input  wire                        wbs_cyc_i,
    input  wire                        wbs_stb_i,
    input  wire                        wbs_we_i,
    input  wire [ADDR_WIDTH-1:0]       wbs_adr_i,
    input  wire [DATA_WIDTH-1:0]       wbs_dat_i,
    output logic [DATA_WIDTH-1:0]      wbs_dat_o,
    input  wire [DATA_WIDTH/8-1:0]     wbs_sel_i,
    input  wire [2:0]                  wbs_cti_i,
    input  wire [1:0]                  wbs_bte_i,
    output logic                       wbs_ack_o,
 
    // Wishbone Master Interface 
    output logic                        wbm_cyc_o,
    output logic                        wbm_stb_o,
    output logic                        wbm_we_o,
    output logic [ADDR_WIDTH-1:0]       wbm_adr_o,
    output logic [DATA_WIDTH-1:0]       wbm_dat_o,
    input  wire [DATA_WIDTH-1:0]        wbm_dat_i,
    output logic [DATA_WIDTH/8-1:0]     wbm_sel_o,
    output logic [2:0]                  wbm_cti_o,
    output logic [1:0]                  wbm_bte_o,
    input  wire                         wbm_ack_i

);

 // From Wishbone Master Interface
    wire [EXT_RW_WIDTH-1:0]                ext_master_rdata;
    wire                                   ext_master_read_done;
    wire                                   ext_master_write_done;

    // To Wishbone Master Interface
    wire                                  ext_master_req;
    wire                                  ext_master_we;
    wire [ADDR_WIDTH-1:0]                 ext_master_addr_read;
    wire [ADDR_WIDTH-1:0]                 ext_master_addr_write;
    wire [EXT_RW_WIDTH-1:0]               ext_master_wdata;

    // From Wishbone Slave Interface
    wire                                   ext_slave_we;
    wire [ADDR_WIDTH-1:0]                  ext_slave_addr_read;
    wire [ADDR_WIDTH-1:0]                  ext_slave_addr_write;
    wire [EXT_RW_WIDTH-1:0]                ext_slave_rdata;
    wire                                  ext_slave_read_done;
    wire                                   ext_slave_write_done;

    // To Wishone Slave Interface
    wire [EXT_RW_WIDTH-1:0]               ext_slave_wdata;

    central_fuzz_fsm #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .EXT_RW_WIDTH(EXT_RW_WIDTH), .IP_NUM(IP_NUM), 
    .IP_SELECTOR_WIDTH(IP_SELECTOR_WIDTH), .TRAFFIC_N(TRAFFIC_N)) fuzz_fsm(.*);

    wishbone_dual #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .EXT_RW_WIDTH(EXT_RW_WIDTH)) bus_interface (.*);


endmodule