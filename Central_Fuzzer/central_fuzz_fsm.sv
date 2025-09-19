`include "fuzz_defines.vh"
 
module central_fuzz_fsm #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter EXT_RW_WIDTH      = 32,
    parameter IP_NUM            = 4,
    parameter IP_SELECTOR_WIDTH = 2,
     parameter TRAFFIC_N         = 2 
)(
    input  logic clk,
    input  logic rst,
 
    // Control Inputs
    input  logic  [1:0]                      mode_selector,
    input  logic [IP_SELECTOR_WIDTH-1:0]     ip_selector,
    output logic [EXT_RW_WIDTH-1:0]            corner_case_payload,
 
    // From Wishbone Master Interface
    input  logic [DATA_WIDTH-1:0]            ext_master_rdata,
    input  logic                             ext_master_read_done,
    input  logic                             ext_master_write_done,
 
    // To Wishbone Master Interface
    output logic                              ext_master_req,
    output logic                              ext_master_we,
    output logic [ADDR_WIDTH-1:0]             ext_master_addr_read,
    output logic [ADDR_WIDTH-1:0]             ext_master_addr_write,
    output logic [DATA_WIDTH-1:0]             ext_master_wdata,
 
    // From Wishbone Slave Interface
    input  logic                              ext_slave_we,
    input  logic [ADDR_WIDTH-1:0]             ext_slave_addr_write,
    input  logic [ADDR_WIDTH-1:0]             ext_slave_addr_read,
    input  logic [DATA_WIDTH-1:0]             ext_slave_rdata,
    input  logic                              ext_slave_read_done,
    input logic                               ext_slave_write_done,
 
    // To Wishbone Slave Interface
    output logic [DATA_WIDTH-1:0]             ext_slave_wdata
);
 
    // FSM States
    typedef enum logic [3:0] {
        IDLE,
        TRIGGER_IP,
        TRIGGER_IP_WAIT,
        TRIGGER_ACK,
        TRIGGER_ACK_EXTRA,
        MONITOR_READ,
        MONITOR_READ_WAIT,
        TRANSMIT_TRACE,
        TRANSMIT_TRACE_WAIT,
        ANOMALY_INDICATION,
        ANOMALY_INDICATION_WAIT
    } state_t;
    // Internal Registers for state and data
    state_t state_r, state_next;
    
 
    // Define constants for clarity
    localparam [ADDR_WIDTH-1:0] ip_address [IP_NUM-1:0] = `IP_ADDR_MAP;
    localparam [ADDR_WIDTH-1:0] traffic_address [0:1] = `TRAFFIC_ADDR_MAP;
    localparam [ADDR_WIDTH-1:0] start_addr = traffic_address[0];
    localparam [ADDR_WIDTH-1:0] end_addr   = traffic_address[1];
    localparam int BUFFER_DEPTH = (end_addr - start_addr) / (DATA_WIDTH/8) + 1;
    // The trace buffer itself
    typedef struct packed {
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
    } trace_entry_t;
    trace_entry_t trace_buffer [0:BUFFER_DEPTH-1];

    logic [ADDR_WIDTH-1:0] current_traffic_addr_r, current_traffic_addr_next;
    logic [$clog2(BUFFER_DEPTH)-1:0] wr_idx_r, wr_idx_next;
    logic [$clog2(BUFFER_DEPTH)-1:0] rd_idx_r, rd_idx_next;
    logic fuzz_ack_received_r, fuzz_ack_received_next;

    logic anomaly_ack_r, anomaly_ack_next;

    logic [EXT_RW_WIDTH-1:0] corner_case_payload_next;
 
   
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r <= IDLE;
            wr_idx_r <= 0;
            rd_idx_r <= 0;
            current_traffic_addr_r <= start_addr;
            fuzz_ack_received_r <= 1'b0;
            // corner_case_payload <= 0;
            anomaly_ack_r <= 1'b0;
        end else begin
            state_r <= state_next;
            wr_idx_r <= wr_idx_next;
            rd_idx_r <= rd_idx_next;
            current_traffic_addr_r <= current_traffic_addr_next;
            fuzz_ack_received_r <= fuzz_ack_received_next;
            corner_case_payload <= corner_case_payload_next;
            anomaly_ack_r <= anomaly_ack_next;
        end
    end
    // Logic to store data into the buffer (also sequential)
    always @(posedge clk) begin
        if (state_r == MONITOR_READ_WAIT && ext_master_read_done) begin
            trace_buffer[wr_idx_r].addr <= current_traffic_addr_r;
            trace_buffer[wr_idx_r].data <= ext_master_rdata;
        end
    end
 
   
    always_comb begin
        // Default assignments to avoid latches
        state_next = state_r;
        wr_idx_next = wr_idx_r;
        rd_idx_next = rd_idx_r;
        current_traffic_addr_next = current_traffic_addr_r;
        fuzz_ack_received_next = fuzz_ack_received_r;
        corner_case_payload_next = corner_case_payload;
        anomaly_ack_next = anomaly_ack_r;
 
        // Concurrently check for the ACK signal from the slave port
        if (ext_slave_we && ext_slave_addr_read == `ANOMALY_INDICATION_ADDR && ext_slave_rdata == `ANOMALY_INDICATION_DATA) begin
                anomaly_ack_next = 1'b1;
                state_next = ANOMALY_INDICATION;
        end
        else if (ext_slave_we && ext_slave_addr_read == `FUZZ_ACK_ADDR && ext_slave_rdata == 32'h63A91243) begin
            fuzz_ack_received_next = 1'b1;
        end
 
        case (state_r)
            IDLE: begin
                if (mode_selector > 0) begin
                    state_next = TRIGGER_IP;
                end
                else begin
                    state_next = IDLE;
                end
            end
            TRIGGER_IP: begin
                ext_master_req   = 1;
                ext_master_we    = 1;
                ext_master_addr_write  = ip_address[ip_selector];
                if (mode_selector == 2'b01) begin
                    ext_master_wdata = 32'hA0000111;
                end
                else if (mode_selector == 2'b10) begin
                    ext_master_wdata = 32'hA0000222;
                end
                // ext_master_wdata = (mode_selector == 0) ? 32'hA0000111 : 32'hA0000222;
                state_next = TRIGGER_IP_WAIT;
            end
                
            TRIGGER_IP_WAIT: begin
                if (ext_master_write_done) begin
                    ext_master_req = 0;
                    ext_master_we = 0;
                    state_next = TRIGGER_ACK;
                end  
            end

            TRIGGER_ACK : begin
                // $display("entering TRIGGER_ACK");
                ext_master_req = 1;
                ext_master_we = 0;
                ext_master_addr_read = `TRIGGER_ACK_ADDR;
                state_next = TRIGGER_ACK_EXTRA;
            end

            TRIGGER_ACK_EXTRA : begin
                // $display("ENTERING TRIGGER ACK EXTRA");
                if (ext_master_read_done) begin
                    if (ext_master_addr_read == `TRIGGER_ACK_ADDR && ext_master_rdata == `TRIGGER_ACK_DATA) begin
                        ext_master_req = 0;
                        ext_master_we = 0;
                        state_next = MONITOR_READ;
                    end
                    else begin
                        state_next = TRIGGER_ACK;
                    end
                end
            end
                
            MONITOR_READ: begin
                if (fuzz_ack_received_r) begin
                    // $display("check fuzz ack state");
                    state_next = TRANSMIT_TRACE; 
                    // ext_master_req = 1;
                    // ext_master_we = 1;
                    rd_idx_next = 0;
                end 
                else begin
                    ext_master_req = 1;
                    ext_master_we = 0;
                    ext_master_addr_read = current_traffic_addr_r;
                    state_next = MONITOR_READ_WAIT;
                end
            end
            MONITOR_READ_WAIT: begin
                if (ext_master_read_done) begin
                    if (current_traffic_addr_r >= end_addr) begin
                        current_traffic_addr_next = start_addr;
                        wr_idx_next = 0;
                    end else begin
                        current_traffic_addr_next = current_traffic_addr_r + (DATA_WIDTH/8);
                        wr_idx_next = wr_idx_r + 1;
                        rd_idx_next = rd_idx_r - 1;
                    end
                    state_next = MONITOR_READ;
                end
            end
            TRANSMIT_TRACE : begin
                // $display("Check TRANSMIT TRACE");
                if (rd_idx_r < BUFFER_DEPTH) begin
                    ext_master_req = 1;
                    ext_master_we = 1;
                    ext_master_addr_write = trace_buffer[rd_idx_r].addr;
                    ext_master_wdata = trace_buffer[rd_idx_r].data;
                    state_next = TRANSMIT_TRACE_WAIT;
                end
                else begin
                    state_next = IDLE;
                end
            end
            TRANSMIT_TRACE_WAIT : begin
                // $display("Check TRANSMIT TRACE WAIT");
                if (ext_master_write_done) begin
                    rd_idx_next = rd_idx_r + 1;
                    state_next = TRANSMIT_TRACE;
                end
                // else begin
                //     state_next = TRANSMIT_TRACE_WAIT;
                // end
            end
            ANOMALY_INDICATION : begin
                // if (anomaly_ack_r) begin
                    if (ext_slave_we && ext_slave_addr_read == `ANOMALY_DATA_ADDR) begin
                        if (ext_slave_read_done) begin
                            corner_case_payload_next = ext_slave_rdata;
                            $displayh("corner case payload received: ", corner_case_payload_next);
                            state_next = IDLE;
                        end   
                    end          
                // end
            end
            default: state_next = IDLE;
        endcase
    end
 
endmodule