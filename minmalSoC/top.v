module top # (
    parameter S0_ENABLE = 1,
    parameter S0_RANGE_WIDTH = 4,
    parameter S0_RANGE_MATCH = 4'b0000,
    parameter S1_ENABLE = 1,
    parameter S1_RANGE_WIDTH = 4,
    parameter S1_RANGE_MATCH = 4'b0001
) (
    input clk,
    input rst,

    output wire trap,        // Crucial for detecting faults/crashes
    output wire mem_instr,   // Useful trigger for glitching
    output wire [31:0] io_out
);
 
    // --- 1. Master Signals (CPU) ---
    wire [31:0] cpu_adr;
    wire [31:0] cpu_dat_w;
    wire [31:0] cpu_dat_r;
    wire [3:0]  cpu_sel;
    wire        cpu_cyc;
    wire        cpu_stb;
    wire        cpu_we;
    wire        cpu_ack;

    wire        pcpi_valid;
	wire [31:0] pcpi_insn;
	wire [31:0] pcpi_rs1;
	wire [31:0] pcpi_rs2;
    wire [31:0] eoi;
    wire        rvfi_valid;
	wire [63:0] rvfi_order;
	wire [31:0] rvfi_insn;
	wire        rvfi_trap;
	wire        rvfi_halt;
	wire        rvfi_intr;
	wire [ 4:0] rvfi_rs1_addr;
	wire [ 4:0] rvfi_rs2_addr;
	wire [31:0] rvfi_rs1_rdata;
	wire [31:0] rvfi_rs2_rdata;
	wire [ 4:0] rvfi_rd_addr;
	wire [31:0] rvfi_rd_wdata;
	wire [31:0] rvfi_pc_rdata;
	wire [31:0] rvfi_pc_wdata;
	wire [31:0] rvfi_mem_addr;
	wire [ 3:0] rvfi_mem_rmask;
	wire [ 3:0] rvfi_mem_wmask;
	wire [31:0] rvfi_mem_rdata;
	wire [31:0] rvfi_mem_wdata;
    wire        trace_valid;
	wire [35:0] trace_data;

	// wire mem_instr;
    // wire trap;
 
    // --- 2. Slave 0 Signals (RAM) ---
    wire [31:0] ram_adr;
    wire [31:0] ram_dat_w;
    wire [31:0] ram_dat_r;
    wire [3:0]  ram_sel;
    wire        ram_cyc;
    wire        ram_stb;
    wire        ram_we;
    wire        ram_ack;
 
    // --- 3. Slave 1 Signals (AES) ---
    wire [31:0] aes_adr;
    wire [31:0] aes_dat_w;
    wire [31:0] aes_dat_r;
    wire [3:0]  aes_sel;
    wire        aes_cyc;
    wire        aes_stb;
    wire        aes_we;
    wire        aes_ack;

    assign io_out = cpu_dat_w;

    
 
    // --- 4. CPU Instantiation ---
    picorv32_top cpu (
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .wbm_adr_o(cpu_adr),
        .wbm_dat_o(cpu_dat_w),
        .wbm_sel_o(cpu_sel),
        .wbm_cyc_o(cpu_cyc),
        .wbm_stb_o(cpu_stb),
        .wbm_we_o (cpu_we),
        .wbm_dat_i(cpu_dat_r),
        .wbm_ack_i(cpu_ack),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .eoi(eoi),
        // .rvfi_valid(rvfi_valid),
        // .rvfi_order(rvfi_order),
        // .rvfi_insn(rvfi_insn),
        // .rvfi_trap(rvfi_trap),
        // .rvfi_halt(rvfi_halt),
        // .rvfi_intr(rvfi_intr),
        // .rvfi_rs1_addr(rvfi_rs1_addr),
        // .rvfi_rs2_addr(rvfi_rs2_addr),
        // .rvfi_rs1_rdata(rvfi_rs1_rdata),
        // .rvfi_rs2_rdata(rvfi_rs2_rdata),
        // .rvfi_rd_addr(rvfi_rd_addr),
        // .rvfi_rd_wdata(rvfi_rd_wdata),
        // .rvfi_pc_rdata(rvfi_pc_rdata),
        // .rvfi_pc_wdata(rvfi_pc_wdata),
        // .rvfi_mem_addr(rvfi_mem_addr),
        // .rvfi_mem_rmask(rvfi_mem_rmask),
        // .rvfi_mem_wmask(rvfi_mem_wmask),
        // .rvfi_mem_rdata(rvfi_mem_rdata),
        // .rvfi_mem_wdata(rvfi_mem_wdata),
        .trace_valid(trace_valid),
        .trace_data(trace_data),
        .mem_instr(mem_instr),
        .trap(trap)
    );
 
    // --- 5. RAM Instantiation ---
    wbram #(.depth(16384), .memfile("firmware.hex")) ram (
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .wb_adr_i(ram_adr),
        .wb_dat_i(ram_dat_w),
        .wb_sel_i(ram_sel),
        .wb_cyc_i(ram_cyc),
        .wb_stb_i(ram_stb),
        .wb_we_i (ram_we),
        .wb_dat_o(ram_dat_r),
        .wb_ack_o(ram_ack)
    );
 
    // --- 6. AES Instantiation ---
    aes_top aes_inst (
        .wb_clk_i(clk),
        .wb_rst_i(rst), // Fixed reset polarity to match system
        .wb_adr_i(aes_adr),
        .wb_dat_i(aes_dat_w),
        .wb_sel_i(aes_sel),
        .wb_cyc_i(aes_cyc),
        .wb_stb_i(aes_stb),
        .wb_we_i (aes_we),
        .wb_dat_o(aes_dat_r),
        .wb_ack_o(aes_ack)
    );
 
    // --- 7. Bus Interconnect ---
    wb_bus_b3 #(
        .MASTERS(1),
        .SLAVES(2),
        .S0_ENABLE(S0_ENABLE),
        .S0_RANGE_WIDTH(S0_RANGE_WIDTH),
        .S0_RANGE_MATCH(S0_RANGE_MATCH),
        .S1_ENABLE(S1_ENABLE),
        .S1_RANGE_WIDTH(S1_RANGE_WIDTH),
        .S1_RANGE_MATCH(S1_RANGE_MATCH)
    ) u_bus (
        .clk_i(clk),
        .rst_i(rst),
        // Master Port
        .m_adr_i(cpu_adr),
        .m_dat_i(cpu_dat_w),
        .m_cyc_i(cpu_cyc),
        .m_stb_i(cpu_stb),
        .m_sel_i(cpu_sel),
        .m_we_i (cpu_we),
        .m_cti_i(3'b000),
        .m_bte_i(2'b00),
        .m_dat_o(cpu_dat_r),
        .m_ack_o(cpu_ack),
        .m_err_o(),
        .m_rty_o(),
 
        // Slave Ports (Manual Concatenation)
        .s_adr_o({aes_adr,   ram_adr}),
        .s_dat_o({aes_dat_w, ram_dat_w}),
        .s_cyc_o({aes_cyc,   ram_cyc}),
        .s_stb_o({aes_stb,   ram_stb}),
        .s_sel_o({aes_sel,   ram_sel}),
        .s_we_o ({aes_we,    ram_we}),
        .s_cti_o(),
        .s_bte_o(),
        .s_dat_i({aes_dat_r, ram_dat_r}),
        .s_ack_i({aes_ack,   ram_ack}),
        .s_err_i(2'b00),
        .s_rty_i(2'b00),

        .snoop_adr_o(),
        .snoop_en_o(),
 
        .bus_hold(1'b0),
        .bus_hold_ack()
    );
 
endmodule