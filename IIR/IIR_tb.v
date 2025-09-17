//
// Testbench for the IIR_filter module
//
// `timescale 1ns / 1ps

module iir_filter_tb;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    parameter CLK_PERIOD = 10;          // Clock period in nanoseconds
    parameter FRACTIONAL_BITS = 8;      // As specified in the generated code

    //--------------------------------------------------------------------------
    // Testbench Signals
    //--------------------------------------------------------------------------
    // Inputs to the DUT (Device Under Test) are declared as 'reg'
    reg clk;
    reg reset;
    reg signed [31:0] inData;

    // Outputs from the DUT are declared as 'wire'
    wire signed [31:0] outData;

    //--------------------------------------------------------------------------
    // Instantiate the IIR Filter (DUT)
    //--------------------------------------------------------------------------
    IIR_filter dut (
        .inData(inData),
        .clk(clk),
        .outData(outData),
        .reset(reset)
    );

    //--------------------------------------------------------------------------
    // Clock Generator
    //--------------------------------------------------------------------------
    // This `always` block generates a continuous clock signal.
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end

    //--------------------------------------------------------------------------
    // Main Test Sequence
    //--------------------------------------------------------------------------
    initial begin
        // --- 1. SETUP AND INITIALIZATION ---
        // Initialize all inputs to a known state.
        $display("--- Simulation Starting ---");
        reset = 1'b1; // Start with reset de-asserted
        inData = 0;
        #5; // Wait for signals to settle

        // Setup waveform dumping for debugging
        $dumpfile("iir_filter_tb.vcd");
        $dumpvars(0, iir_filter_tb);

        // --- 2. APPLY ASYNCHRONOUS RESET ---
        // The filter uses an active-low reset.
        $display("Applying active-low reset...");
        reset = 1'b0; // Assert reset
        #(CLK_PERIOD * 2); // Hold reset for 2 clock cycles
        reset = 1'b1; // De-assert reset
        @(posedge clk);
        $display("Reset released. Filter is operational.");
        #10;

        // --- 3. TEST SCENARIO: IMPULSE RESPONSE ---
        // An impulse is a single, non-zero sample followed by zeros.
        // For Q23.8 fixed-point format, the value 1.0 is represented by 2^8 = 256.
        $display("\n--- Testing Impulse Response ---");
        inData = 256; // Input an impulse of 1.0
        @(posedge clk);
        inData = 0; // Return input to zero
        $display("Impulse applied. Observing output for 30 cycles...");
        repeat(30) begin
            @(posedge clk);
        end
        #10;
        
        // --- 4. TEST SCENARIO: STEP RESPONSE ---
        // A step is a constant input value held over time.
        // We'll use a step value of 0.5, which is 0.5 * 2^8 = 128.
        $display("\n--- Testing Step Response ---");
        inData = 128; // Input a step of 0.5
        $display("Step input of 0.5 applied. Observing output for 50 cycles...");
        repeat(50) begin
            @(posedge clk);
        end
        inData = 0; // Return to zero
        repeat(10) @(posedge clk); // Allow filter to settle
        #10;
        
        // --- 5. TEST SCENARIO: SINE WAVE RESPONSE ---
        // Input a pre-calculated sine wave to observe filtering action.
        // Values are sin(theta) * 2^8, rounded to the nearest integer.
        $display("\n--- Testing Sine Wave Response ---");
        // Values for one period of a sine wave with 16 samples
        integer sine_wave [0:15] = '{  0,  50,  98, 142, 181, 212, 236, 250,
                                     255, 250, 236, 212, 181, 142,  98,  50};
        
        // Run the sine wave through the filter for two full cycles
        for (integer j = 0; j < 2; j = j + 1) begin
            $display("Applying sine wave cycle %0d", j + 1);
            for (integer i = 0; i < 16; i = i + 1) begin
                inData = sine_wave[i];
                @(posedge clk);
            end
        end
        inData = 0;
        #10;

        // --- 6. END SIMULATION ---
        $display("\n--- All test scenarios complete. Finishing simulation. ---");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Output Monitor
    //--------------------------------------------------------------------------
    // This block prints changes in signals to the console during simulation.
    initial begin
        $monitor("Time=%0t ns | Reset: %b | InData: %10d | OutData: %10d",
                 $time, reset, inData, outData);
    end

endmodule