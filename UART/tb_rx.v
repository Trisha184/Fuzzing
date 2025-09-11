//
// Module: tb
//
// Notes:
// - Top level simulation testbench.
//

// `timescale 1ns/1ns
`define WAVES_FILE "./work/waves-rx.vcd"

module tb;

reg         clk          ; // Top level system clock input.
reg         resetn       ;
reg         uart_rxd     ; // UART Recieve pin.

reg         uart_rx_en   ; // Recieve enable
wire        uart_rx_break; // Did we get a BREAK message?
wire        uart_rx_valid; // Valid data recieved and available.
wire [7:0]  uart_rx_data ; // The recieved data.

//
// Bit rate of the UART line we are testing.
localparam BIT_RATE = 115200;
localparam BIT_P    = (1000000000/BIT_RATE);

//
// Period and frequency of the system clock.
localparam CLK_HZ   = 50000000;
localparam CLK_P    = 1000000000 / CLK_HZ;


//
// Make the clock tick.
// CORRECTED: Use standard clock generation.
initial clk = 1'b0;
always #(CLK_P/2) clk = ~clk;


//
// Sends a single byte down the UART line.
task send_byte;
    input [7:0] to_send;
    integer i;
    begin
        // Send Start Bit
        #BIT_P; uart_rxd = 1'b0;

        // Send 8 Data Bits (LSB first)
        for(i=0; i < 8; i = i+1) begin
            #BIT_P; uart_rxd = to_send[i];
        end

        // Send Stop Bit
        #BIT_P; uart_rxd = 1'b1;

        // Idle time between bytes
        #1000;
    end
endtask

//
// Checks that the output of the UART is the value we expect.
integer passes = 0;
integer fails  = 0;
task check_byte;
    input [7:0] expected_value;
    begin
        if(uart_rx_data == expected_value) begin
            passes = passes + 1;
            $display("%d/%d/%d [PASS] Expected %b and got %b",
                     passes,fails,passes+fails,
                     expected_value, uart_rx_data);
        end else begin
            fails  = fails  + 1;
            $display("%d/%d/%d [FAIL] Expected %b and got %b",
                     passes,fails,passes+fails,
                     expected_value, uart_rx_data);
        end
    end
endtask

//
// Run the test sequence.
reg [7:0] to_send;
initial begin
    // Initial Conditions
    resetn   = 1'b0;
    uart_rxd = 1'b1; // UART idle is high
    #40;
    resetn   = 1'b1;

    // VCD Waveform Dumping
    $dumpfile(`WAVES_FILE);
    $dumpvars(0,tb);

    // Enable the receiver
    uart_rx_en = 1'b1;
    #1000;

    // Test Loop
    repeat(10) begin
        to_send = $random;
        send_byte(to_send);
        // CORRECTED: Wait for the valid signal to avoid race condition
        @(posedge uart_rx_valid);
        check_byte(to_send);
    end

    $display("\n--- Simulation Summary ---");
    $display("BIT RATE      : %d b/s", BIT_RATE );
    $display("CLK PERIOD    : %d ns" , CLK_P    );
    $display("CYCLES/BIT    : %d"   , i_uart_rx.CYCLES_PER_BIT);
    $display("SAMPLE PERIOD : %d ns", CLK_P * i_uart_rx.CYCLES_PER_BIT);
    $display("BIT PERIOD    : %d ns" , BIT_P    );

    $display("\n--- Test Results ---");
    $display("  PASSES: %d", passes);
    $display("  FAILS : %d", fails);

    $display("\nFinish simulation at time %t", $time);
    $finish();
end


//
// Instance of the DUT
uart_rx #(
    .BIT_RATE(BIT_RATE),
    .CLK_HZ  (CLK_HZ  )
) i_uart_rx(
    .clk          (clk          ),
    .resetn       (resetn       ),
    .uart_rxd     (uart_rxd     ),
    .uart_rx_en   (uart_rx_en   ),
    .uart_rx_break(uart_rx_break),
    .uart_rx_valid(uart_rx_valid),
    .uart_rx_data (uart_rx_data )
);

endmodule