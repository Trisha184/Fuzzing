
 
module satellite_fuzzer_tb;
 
    localparam WATCHDOG_LIMIT  = 50;
    localparam TRACE_DEPTH     = 64;
 
    // Clock and Reset
    logic clk;
    logic rst_n;
 
    logic               fuzz_en;
    logic               bus_start;
    logic [127:0]       bus_state;
    logic [127:0]       bus_key;

    
    logic [127:0]       aes_out;
    logic               aes_out_valid;
    
    logic         alarm_timeout;
    logic         alarm_collision;

    logic [127:0]   error_key;
    logic [127:0]   error_state;
    logic [127:0]   error_out;
 

    satellite_fuzzer #(
        .WATCHDOG_LIMIT(WATCHDOG_LIMIT),
        .TRACE_DEPTH(TRACE_DEPTH)
    ) sat_fuzz (
        .clk(clk),
        .rst_n(rst_n),
        .fuzz_en(fuzz_en),
        .bus_start(bus_start),
        .bus_state(bus_state),
        .bus_key(bus_key),
        .aes_out(aes_out),
        .aes_out_valid(aes_out_valid),
        .alarm_timeout(alarm_timeout),
        .alarm_collision(alarm_collision),
        .error_key(error_key),
        .error_state(error_state),
        .error_out(error_out)

    );
 

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end
 
   
    initial begin

        rst_n     = 0;
        fuzz_en   = 0;
        bus_start  = 0;
        bus_state  = 0;
        bus_key = 0;
 
        $display("[%0t] Resetting System...", $time);

        #100;
        rst_n = 1;
        #50;

        fuzz_en = 1;
        $display("[%0t] Fuzzing Mode Enabled.", $time);
        
        fork
            begin
                wait (alarm_timeout || alarm_collision);
                $display("[%0t] Timeout Alarm Triggered!", $time);
                $display("----------------------------------");
                $display("Anomaly Type: %s", alarm_timeout ? "Timeout" : "Collision");
                $displayh("collision = ", alarm_collision);
                $display("Culprit state", error_state);
                $display("Culprit key  : %h", error_key);
                $display("Ciphertext   : %h", error_out);
                $display("----------------------------------");
                #100;
                $finish;
            end
            begin
                int i;
                for (i = 0; i < 1000000/1000; i = i + 1) begin
                    $display("It's running.............. [%0t]", $time);
                    #50000000;
                end
                $display("No anomalies detected within the time limit.");
                $finish;
            end
        join_any
 
        
       
 
        $finish;

    end
 
    // --- 4. Waveform Generation (VCS/DVE) ---

    initial begin

        $vcdpluson; // For VCS/DVE

        // $dumpfile("fuzzer_sim.vcd"); // For GTKWave

        // $dumpvars(0, tb_sha256_fuzzer_system);

    end
 
endmodule
 