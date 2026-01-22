module trng #(
    parameter OUTPUT_WIDTH = 256
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     en,      // Enable generation
    output logic [OUTPUT_WIDTH-1:0] data_o,
    output logic                     valid_o
);
 
    // 64-bit maximal length polynomial: x^64 + x^63 + x^61 + x^60 + 1

    logic [63:0] lfsr_reg;
    logic [OUTPUT_WIDTH-1:0] shift_reg;
    logic [$clog2(OUTPUT_WIDTH):0] bit_cnt;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg   <= $urandom_range(1, 64'hFFFFFFFFFFFFFFFF);
            bit_cnt    <= 0;
            valid_o    <= 0;
            data_o     <= 0;
            shift_reg  <= 0;
        end else if (en) begin
            if (valid_o) begin
                // Acknowledge: Clear valid and start next block immediately
                valid_o <= 0;
                bit_cnt <= 0;
            end else begin
                // LFSR Taps
                lfsr_reg <= {lfsr_reg[62:0], lfsr_reg[63] ^ lfsr_reg[62] ^ lfsr_reg[60] ^ lfsr_reg[59]};
                shift_reg <= {shift_reg[OUTPUT_WIDTH-2:0], lfsr_reg[0]};
 
                if (bit_cnt == OUTPUT_WIDTH - 1) begin
                    data_o  <= {shift_reg[OUTPUT_WIDTH-2:0], lfsr_reg[0]};
                    valid_o <= 1;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end

endmodule
 