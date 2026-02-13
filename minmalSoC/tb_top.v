module tb_top;
 
    // --- 1. Clock and Reset Generation ---
    reg clk;
    reg rst;
 
    always #5 clk = ~clk; // 100MHz clock
 
    // --- 2. Unit Under Test (UUT) ---
    top uut (
        .clk(clk),
        .rst(rst)
    );
 
    // --- 3. Simulation Control & Hex Loading ---
    initial begin
        $display("[%t] Simulation Starting...", $time);
        // Initialize signals
        clk = 0;
        rst = 1;
 
        // Load Firmware into RAM
        // Note: Ensure the path to the RAM inside your top.v is correct
        $readmemh("firmware.hex", uut.ram.mem);
 
        // Pre-flight check: Verify HEX actually loaded
        #1;
        $display("[%t] RAM[0] check: %h (Expected 00004137)", $time, uut.ram.mem[0]);
        if (uut.ram.mem[0] === 32'hxxxxxxxx) begin
            $display("FATAL: firmware.hex not found or empty!");
            $finish;
        end
 
        // Reset Sequence
        #100;
        @(posedge clk);
        rst = 0;
        $display("[%t] Reset Released. CPU is running...", $time);
 
        // Global Timeout: 1ms of simulation time
        #1000000;
        $display("[%t] ERROR: Simulation Timeout!", $time);
        $finish;
    end
 
    // --- 4. Logic Monitors (The "Check Engine" Lights) ---
 
    // PC Tracker: Watch the CPU move
    // always @(posedge clk) begin
    //     if (uut.cpu.picorv32_core.mem_valid && uut.cpu.picorv32_core.mem_ready && uut.cpu.picorv32_core.mem_instr) begin
    //         $display("[%t] PC_TRACE: 0x%h | Data: 0x%h", 
    //                  $time, uut.cpu.picorv32_core.mem_addr, uut.cpu.picorv32_core.mem_rdata);
    //     end
    // end
 
    // Bus Integrity: Catch Z or X values on critical control lines
    always @(posedge clk) begin
        if (!rst) begin
            if (^uut.ram.wb_adr_i === 1'bX) 
                $display("[%t] !!! WARNING: RAM Address is Floating/X: %h", $time, uut.ram.wb_adr_i);
            if (uut.ram.wb_stb_i === 1'bZ)
                $display("[%t] !!! WARNING: RAM Strobe is High-Z (Disconnected)!", $time);
        end
    end

always @(posedge clk) begin
    if (uut.ram.tests_passed) begin
        $display("----------------------------------------------------------");
        $display("[%t] TESTBENCH: RAM Success Flag Detected!", $time);
        $display("[%t] >>> AES VERIFICATION PASSED: Data matches Golden Value <<<", $time);
        $display("----------------------------------------------------------");
        #100; $finish;
    end
    // Catch the failure code if data doesn't match
    if (uut.ram.mem[32'h2000/4] == 32'hDEADBEEF) begin
        $display("----------------------------------------------------------");
        $display("[%t] !!! AES VERIFICATION FAILED: Ciphertext Mismatch !!!", $time);
        $display("----------------------------------------------------------");

        $display("--- AES DEBUG: ACTUAL OUTPUT ---");
        $display("CT: %h", uut.aes_inst.ct); // You may need to 'force' a read here
        // internal registers value for ciphertext
        $display("INTERNAL CT: %h %h %h %h", 
                uut.aes_inst.ct[127:96], uut.aes_inst.ct[95:64], uut.aes_inst.ct[63:32], uut.aes_inst.ct[31:0]);
        $display("--------------------------------");
        #100; $finish;
    end
end

 
    // --- 5. VCD Dumping for Waveform Analysis ---
    initial begin
        $vcdplusfile("simv.vpd");
        $vcdpluson;
        // If using open source tools like iverilog/gtkwave, use:
        // $dumpfile("dump.vcd");
        // $dumpvars(0, tb_top);
    end
 
endmodule