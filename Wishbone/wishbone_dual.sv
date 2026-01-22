module wishbone_dual #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter EXT_RW_WIDTH    = 256  // External read/write width in bits
)(
    input  logic                        clk,
    input  logic                        rst,
 
    // Wishbone Slave Interface 
    input  logic                        wbs_cyc_i,
    input  logic                        wbs_stb_i,
    input  logic                        wbs_we_i,
    input  logic [ADDR_WIDTH-1:0]       wbs_adr_i,
    input  logic [DATA_WIDTH-1:0]       wbs_dat_i,
    output logic [DATA_WIDTH-1:0]       wbs_dat_o,
    input  logic [DATA_WIDTH/8-1:0]     wbs_sel_i,
    input  logic [2:0]                  wbs_cti_i,
    input  logic [1:0]                  wbs_bte_i,
    output logic                        wbs_ack_o,
 
    // Wishbone Master Interface 
    output logic                        wbm_cyc_o,
    output logic                        wbm_stb_o,
    output logic                        wbm_we_o,
    output logic [ADDR_WIDTH-1:0]       wbm_adr_o,
    output logic [DATA_WIDTH-1:0]       wbm_dat_o,
    input  logic [DATA_WIDTH-1:0]       wbm_dat_i,
    output logic [DATA_WIDTH/8-1:0]     wbm_sel_o,
    output logic [2:0]                  wbm_cti_o,
    output logic [1:0]                  wbm_bte_o,
    input  logic                        wbm_ack_i,
 
    // External Interface (to/from central fuzzer)
    input  logic                        ext_master_req,
    input  logic                        ext_master_we,
    input  logic [ADDR_WIDTH-1:0]       ext_master_addr_read,
    input  logic [ADDR_WIDTH-1:0]       ext_master_addr_write,
    input  logic [EXT_RW_WIDTH-1:0]     ext_master_wdata,
    output logic [EXT_RW_WIDTH-1:0]     ext_master_rdata,
    output logic                        ext_master_read_done,
    output logic                        ext_master_write_done,
 
    
    input  logic [EXT_RW_WIDTH-1:0]     ext_slave_wdata,
    output logic                        ext_slave_we,
    output logic [ADDR_WIDTH-1:0]       ext_slave_addr_read,
    output logic [ADDR_WIDTH-1:0]       ext_slave_addr_write,
    output logic [EXT_RW_WIDTH-1:0]     ext_slave_rdata,
    output logic                        ext_slave_read_done,
    output logic                        ext_slave_write_done
);
 
    localparam BURST_LEN = EXT_RW_WIDTH / DATA_WIDTH;
 
    // Burst buffer for reads and writes
    logic [DATA_WIDTH-1:0] master_buffer [0:BURST_LEN-1];
    logic [DATA_WIDTH-1:0] slave_buffer  [0:BURST_LEN-1];

    logic [DATA_WIDTH-1:0] rdata_temp [0:BURST_LEN-1];
 
    
    typedef enum logic [2:0] {
        M_IDLE, M_READ, M_WRITE, M_READ_DONE, M_WRITE_DONE
    } master_state_t;
 
    typedef enum logic [2:0] {
        S_IDLE, S_READ, S_WRITE, S_READ_DONE, S_WRITE_DONE
    } slave_state_t;
 
    master_state_t mstate;
    slave_state_t  sstate;
 
    logic [3:0] m_idx;
    logic [3:0] s_idx;
    logic [1:0] write_counter;

 
    ///////////////////////////////////////////////////////////////// Master///////////////////////////////////////////////////
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstate         <= M_IDLE;
            wbm_cyc_o      <= 0;
            wbm_stb_o      <= 0;
            wbm_we_o       <= 0;
            wbm_adr_o      <= 0;
            wbm_dat_o      <= 0;
            wbm_sel_o      <= '1;
            wbm_cti_o      <= 3'b000;
            wbm_bte_o      <= 2'b00;
            m_idx          <= 0;
            ext_master_read_done <= 0;
            ext_master_write_done <= 0;
            write_counter <= 0;
        end else begin
            ext_master_read_done <= 0;
            ext_master_write_done <= 0;
            case (mstate)
                M_IDLE: begin
                    if (ext_master_req) begin
                        m_idx      <= 0;
                        wbm_we_o   <= ext_master_we;
                        mstate <= ext_master_we ? M_WRITE : M_READ;
                    end
                end
                M_READ: begin
                    wbm_adr_o  <= ext_master_addr_read;
                    wbm_cyc_o  <= 1;
                    wbm_stb_o  <= 1;
                    if (wbm_ack_i) begin
                        master_buffer[m_idx] <= wbm_dat_i;
                        $displayh("Read address: ", wbm_adr_o, " & Read Data: ", wbm_dat_i);
                        m_idx <= m_idx + 1;
                        wbm_adr_o <= wbm_adr_o + 4;
                        if (m_idx == BURST_LEN - 2) begin
                            wbm_cti_o <= 3'b111;
                        end
                        else if (m_idx == BURST_LEN - 1) begin
                            wbm_cyc_o <= 0;
                            wbm_stb_o <= 0;
                            // ext_master_rdata <= {>>{master_buffer}}; // pack master buffer into ext_master_rdata and stream 
                            // $displayh("master buffer: ", master_buffer);
                            mstate <= M_READ_DONE;
                        end
                    end
                end
                M_WRITE : begin
                    wbm_adr_o  <= ext_master_addr_write;
                    for (int i = 0; i < BURST_LEN; i++) begin
                        master_buffer[i] = ext_master_wdata[i*DATA_WIDTH +: DATA_WIDTH]; // divide the data into chunks and load it in buffer
                    end
                    wbm_cyc_o <= 1;
                    wbm_stb_o <= 1;
                    wbm_dat_o <= master_buffer[m_idx];
                    wbm_cti_o  <= (BURST_LEN > 1) ? 3'b010 : 3'b111;
                    if (wbm_ack_i) begin
                        $displayh("write address: ", wbm_adr_o, "  write data: ", wbm_dat_o);
                        wbm_adr_o <=  wbm_adr_o + 4;
                        m_idx <= m_idx + 1;
                        wbm_dat_o <= master_buffer[m_idx + 1];
                        if (m_idx == BURST_LEN - 2) begin
                            wbm_cti_o <= 3'b111;
                        end
                        else if (m_idx == BURST_LEN - 1) begin
                            wbm_cyc_o <= 0;
                            wbm_stb_o <= 0;
                            mstate <= M_WRITE_DONE;
                        end
                    end
                end
                M_READ_DONE: begin
                    ext_master_rdata <= {>>{master_buffer}};
                    ext_master_read_done  <= 1;
                    mstate           <= M_IDLE;
                end
                M_WRITE_DONE: begin
                    ext_master_write_done  <= 1;
                    mstate           <= M_IDLE;
                end
            endcase
        end
    end
 
    /////////////////////////////////////////////////////// Slave /////////////////////////////////////////////////////////////////////
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sstate      <= S_IDLE;
            wbs_ack_o   <= 0;
            s_idx       <= 0;
            ext_slave_we  <= 0;
            ext_slave_addr_read <= 0;
            ext_slave_addr_write <= 0;
        end else begin
            case (sstate)
                S_IDLE: begin
                    ext_slave_read_done <= 0;
                    ext_slave_write_done <= 0;
                    if (wbs_cyc_i && wbs_stb_i) begin
                        ext_slave_we <= wbs_we_i;
                        ext_slave_addr_read <= wbs_adr_i;
                        ext_slave_addr_write <= wbs_adr_i;
                        sstate <= wbs_we_i ? S_READ : S_WRITE;
                    end
                end
                S_READ : begin
                    if (wbs_cyc_i && wbs_stb_i && !wbs_ack_o) begin
                        slave_buffer[s_idx] <= wbs_dat_i;
                        wbs_ack_o <= 1;
                        s_idx <= s_idx + 1;
                        if (s_idx == BURST_LEN -1) begin
                            sstate <= S_READ_DONE;
                        end  
                    end
                    else begin
                        wbs_ack_o <= 0;
                    end
                end
                S_WRITE : begin
                      for (int i = 0; i < BURST_LEN;  i++) begin
                        slave_buffer[i] = ext_slave_wdata[i*DATA_WIDTH +: DATA_WIDTH];
                      end 
                        wbs_dat_o <= slave_buffer[s_idx];
                        wbs_ack_o <= 1;
                        if (s_idx == BURST_LEN - 1) begin
                            sstate <= S_WRITE_DONE;
                        end
                        else begin
                            s_idx <= s_idx + 1;
                        end
                end
                S_READ_DONE : begin
                    ext_slave_rdata <= {>>{slave_buffer}};
                    s_idx <= 0;
                    wbs_ack_o <= 0;
                    ext_slave_read_done <= 1;
                    sstate <= S_IDLE;
                end
                S_WRITE_DONE : begin
                    wbs_ack_o <= 0;
                    s_idx <= 0;
                    ext_slave_write_done <= 1;
                    sstate <= S_IDLE;
                end
            endcase
        end
    end
endmodule

