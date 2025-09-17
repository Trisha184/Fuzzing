
`include "fuzz_defines.vh"
 
module testbench;
 
    localparam CLK_PERIOD = 10; // 10ns = 100MHz clock
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam IP_NUM = 4;
    localparam IP_SELECTOR_WIDTH = 2;
    localparam TRAFFIC_N = 2;
    localparam EXT_RW_WIDTH = 32;
 
    
    logic clk;
    logic rst;

    logic [1:0]                                  mode_selector;
    logic [IP_SELECTOR_WIDTH-1:0]               ip_selector;
    logic [EXT_RW_WIDTH-1:0]                    corner_case_payload;

     // Wishbone Slave Interface 
    logic                              wbs_cyc_i;
    logic                              wbs_stb_i;
    logic                              wbs_we_i;
    logic [ADDR_WIDTH-1:0]             wbs_adr_i;
    logic [DATA_WIDTH-1:0]             wbs_dat_i;
    logic [DATA_WIDTH-1:0]             wbs_dat_o;
    logic [DATA_WIDTH/8-1:0]           wbs_sel_i;
    logic [2:0]                        wbs_cti_i;
    logic [1:0]                        wbs_bte_i;
    logic                              wbs_ack_o;

    // Wishbone Master Interface
    logic                              wbm_cyc_o;
    logic                              wbm_stb_o;
    logic                              wbm_we_o;
    logic [ADDR_WIDTH-1:0]             wbm_adr_o;
    logic [DATA_WIDTH-1:0]             wbm_dat_o;
    logic [DATA_WIDTH-1:0]             wbm_dat_i;
    logic [DATA_WIDTH/8-1:0]           wbm_sel_o;
    logic [2:0]                        wbm_cti_o;
    logic [1:0]                        wbm_bte_o;
    logic                              wbm_ack_i;
    
    localparam [31:0] traffic_address [0:1] = `TRAFFIC_ADDR_MAP;
    localparam [31:0] start_addr = traffic_address[0];
    localparam [31:0] end_addr   = traffic_address[1];
    localparam int     BUFFER_DEPTH = (end_addr - start_addr) / 4 + 1;
 
    
    logic [31:0] traffic_memory [0:BUFFER_DEPTH-1];
    logic [31:0] verification_memory [0:BUFFER_DEPTH-1];

    logic error_found = 0;
 
    
    central_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .EXT_RW_WIDTH(EXT_RW_WIDTH),
                   .IP_NUM(IP_NUM), .IP_SELECTOR_WIDTH(IP_SELECTOR_WIDTH), .TRAFFIC_N(TRAFFIC_N))
                   central_dut (.*);
 
   
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
 
    
    initial begin
        $display("TB: Test starting...");

        // Mimicking traffic data
        for (int i = 0; i < BUFFER_DEPTH; i++) begin
            traffic_memory[i] = 32'hBEEF0000 + i;
        end

        // --- Reset Phase ---
        rst = 1;
        wbs_stb_i = 0;
        wbs_cyc_i = 0;
        wbs_we_i  = 0;
        wbs_sel_i = '1;
        # (CLK_PERIOD * 5);
        rst = 0;
        $display("TB: Reset released.");
 
        // Sending trigger to start fuzzing
        trigger();

        $display("CF: Central fuzzer is entering bus traffic monitoring mode......");
       
        repeat(50) @(posedge clk);

        anomaly_task(`ANOMALY_INDICATION_DATA);
        
        fuzz_test();
       
    end

    task automatic trigger();
        mode_selector = 2'b01; // Mutated fuzz
        ip_selector   = 2'b01; // Fuzz IP 1
        $display("CF: Sending Trigger to start fuzzing.....");

        while (central_dut.fuzz_fsm.state_r == central_dut.fuzz_fsm.MONITOR_READ) begin
            @(posedge clk);
        end
    endtask 

    // this task is mimicking when satellite fuzzer is writing on the bus as master
    task automatic wishbone_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        wbs_stb_i <= 1;
        wbs_cyc_i <= 1;
        wbs_we_i  <= 1;
        wbs_adr_i<= addr;
        wbs_dat_i <= data;
        wait (wbs_ack_o);
        // $displayh("checking slave read data: ", wbs_dat_i);
        @(posedge clk);
        wbs_stb_i <= 0;
        wbs_cyc_i <= 0;
    endtask

    task automatic fuzz_test();
         // Satellite fuzzer is sending completion ACK
        wishbone_write(`FUZZ_ACK_ADDR, 32'h63A91243);
        // while (!central_dut.fuzz_fsm.fuzz_ack_received_r) begin
        //     @(posedge clk);
        // end
        // $displayh("check fuzz signal = ", central_dut.fuzz_fsm.fuzz_ack_received_r);
        
        $display("CF: Fuzzing completion ACK received from  satellite fuzzer......");
        $display("CF: Central fuzzer is transmitting monitored data to satellite fuzzer......");
        wait (central_dut.fuzz_fsm.state_r == central_dut.fuzz_fsm.IDLE);
        @(posedge clk);
    

        $display("TB: verifying transmitted data......");
    
        for (int i = 0; i < BUFFER_DEPTH; i++) begin
            if (traffic_memory[i] != verification_memory[i]) begin
                $error("TB: DATA MISMATCH at index %0d! Expected %h, Got %h", i, traffic_memory[i], verification_memory[i]);
                error_found = 1;
            end
        end
        if (!error_found) begin
            $display("CF: SUCCESSFULL data transmission......");
        end
 
        $display("TB: Test finished successfully!");
        $finish;
    endtask //automatic

    task automatic trigger_anomaly(input [DATA_WIDTH-1:0] data);
        // $display("TB: Injecting anomaly.......");
        wishbone_write(`ANOMALY_INDICATION_ADDR, data);
        if (wbs_adr_i == `ANOMALY_INDICATION_ADDR && wbs_dat_i == `ANOMALY_INDICATION_DATA) begin
            $display("TB: Anomaly detected, informing central fuzzer.......");
        end
        else begin
           fuzz_test();
        end

        $display("TB: Sending corner case payload.......");
        wishbone_write(`ANOMALY_DATA_ADDR, `ANOMALY_PAYLOAD);
        
    endtask 

    task automatic anomaly_task(input [DATA_WIDTH-1:0] data);
        trigger_anomaly(data);
        verify_anomaly(`ANOMALY_PAYLOAD);
        $display("TB: Test finished successfully!");
        $finish;

    endtask 

    task automatic verify_anomaly(input [DATA_WIDTH-1:0] expected_payload);
        wait (central_dut.fuzz_fsm.state_r == central_dut.fuzz_fsm.IDLE);
        $display("TB: Verifying anomaly payload...");
        if (corner_case_payload == expected_payload) begin
            $display("TB: SUCCESS! Anomaly payload correctly captured: %h", corner_case_payload);
        end else begin
            $error("TB: FAILURE! Anomaly payload mismatch. Expected: %h, Got: %h", expected_payload, corner_case_payload);
        end
    endtask

    always_comb begin
        wbm_ack_i = wbm_stb_o && wbm_cyc_o;
        wbm_dat_i = 0;

        if (wbm_stb_o && !wbm_we_o) begin // Read operation
            if (wbm_adr_o == `TRIGGER_ACK_ADDR) begin
                wbm_dat_i = `TRIGGER_ACK_DATA;
                $displayh("CF: Trigger ack recevied from satellite fuzzer..... ");
            end
            else if (wbm_adr_o >= start_addr && wbm_adr_o <= end_addr) begin
                logic [$clog2(BUFFER_DEPTH)-1:0] index;
                index = (wbm_adr_o - start_addr) / 4;
                wbm_dat_i = traffic_memory[index];
            end
        end
    end
 
    
    always @(posedge clk) begin

        if (!rst && wbm_stb_o && wbm_ack_i) begin
            if (wbm_we_o) begin // Write operation
                $displayh("CF: Central Fuzzer is WRITING data ", wbm_dat_o, " to address ", wbm_adr_o);
                if (wbm_adr_o >= start_addr && wbm_adr_o <= end_addr) begin
                    logic [$clog2(BUFFER_DEPTH)-1:0] index;
                    index = (wbm_adr_o - start_addr) / 4;
                    verification_memory[index] = wbm_dat_o;
                end
            end
        else begin // Read operation
            $displayh("CF: Central Fuzzer is READING data ", wbm_dat_i, " to address ", wbm_adr_o);
        end
    end
    end

    
 
endmodule

