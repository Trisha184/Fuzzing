
 
module trng_tb;

    parameter WIDTH = 256;

    logic clk;
    logic rst_n;
    logic en;
    logic [WIDTH-1:0] data_o;
    logic valid_o;
 
    trng #(.OUTPUT_WIDTH(WIDTH)) dut (.*);
 
    // Clock

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
 
    initial begin
        $dumpfile("trng.vcd");
        $dumpvars(0, trng_tb);
        rst_n = 0;
        en = 0;
        #100;

        rst_n = 1;
        #50;
 
        $display("[%0t] Enabling PRNG...", $time);

        en = 1;
 
        // Capture 3 unique random blocks

        repeat (10) begin
            wait(valid_o);
            $display("[%0t] PRNG Block: %h", $time, data_o);

            @(posedge clk);

            en = 0; // Toggle en to clear valid (depending on your FSM needs)
            #20;
            en = 1;

        end
 
        $display("PRNG Verification Complete.");
        $finish;

    end

endmodule
 