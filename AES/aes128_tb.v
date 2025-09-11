// `timescale 1ns / 1ps

module aes128_tb;

    parameter CLK_PERIOD = 10; 

    // Test Vector from NIST FIPS-197, Appendix B
    parameter [127:0] PLAINTEXT          = 128'h00112233445566778899aabbccddeeff;
    parameter [127:0] KEY                = 128'h000102030405060708090a0b0c0d0e0f;
    parameter [127:0] EXPECTED_CIPHERTEXT = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    
    reg           clk;
    reg           start;
    reg [127:0]   state;
    reg [127:0]   key;
    wire [127:0]  out;
    wire          out_valid;

    
    aes_128 aes128 (
        .clk(clk),
        .start(start),
        .state(state),
        .key(key),
        .out(out),
        .out_valid(out_valid)
    );

    
    initial begin
        clk = 0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    
    initial begin
        start <= 0;
        state <= 0;
        key   <= 0;

        $display("----------------------------------------------------");
        $display("AES-128 Test Start Here");
        
        
       
        repeat (2) @(posedge clk);

        
        state <= PLAINTEXT;
        key   <= KEY;

        $display("   Plaintext: %h", PLAINTEXT);
        $display("   Key:       %h", KEY);
        
        @(posedge clk);

        
        start <= 1;
        @(posedge clk);
        start <= 0;

        
        $display("Waiting for output to be valid...");
        wait (out_valid); 
        $display("Output is valid");
        
        // #1; 

        
        if (out === EXPECTED_CIPHERTEXT) begin
            $display("    TEST PASSED!");
            $displayh("   Expected: ", EXPECTED_CIPHERTEXT);
            $displayh("   Actual:   ", out);
        end else begin
            $display("   TEST FAILED!");
            $displayh("   Expected: ", EXPECTED_CIPHERTEXT);
            $displayh("   Actual:   ", out);
        end

        
        $finish;
    end


endmodule