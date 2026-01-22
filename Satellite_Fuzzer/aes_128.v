/*
 * Copyright 2012, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// assumes input does not change between start going high and out_valid

module aes_128(clk, start, state, key, out, out_valid);
input          clk;
input          start;
input  [127:0] state, key;
output [127:0] out;
output         out_valid;
reg    [127:0] s0, k0;
wire   [127:0] s1, s2, s3, s4, s5, s6, s7, s8, s9,
       k1, k2, k3, k4, k5, k6, k7, k8, k9,
       k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8b, k9b;

reg start_r;
always @(posedge clk)
    begin
        start_r <= start;
    end

wire start_posedge = start & ~start_r;
reg [4:0] validCounter;

always @ (posedge clk)
    begin
        if(start_posedge)
            begin
                s0 <= state ^ key;
                k0 <= key;
                validCounter <= 21;
            end
        else if(~out_valid)
            begin
                validCounter <= validCounter - 1;
            end
    end

assign out_valid = (validCounter == 0);

expand_key_128
     a1 (.clk(clk), .in(k0), .out_1(k1),  .out_2(k0b), .rcon(8'h01)),
    a2 (.clk(clk), .in(k1), .out_1(k2),  .out_2(k1b), .rcon(8'h02)),
    a3 (.clk(clk), .in(k2), .out_1(k3),  .out_2(k2b), .rcon(8'h04)),
    a4 (.clk(clk), .in(k3), .out_1(k4),  .out_2(k3b), .rcon(8'h08)),
    a5 (.clk(clk), .in(k4), .out_1(k5),  .out_2(k4b), .rcon(8'h10)),
    a6 (.clk(clk), .in(k5), .out_1(k6),  .out_2(k5b), .rcon(8'h20)),
    a7 (.clk(clk), .in(k6), .out_1(k7),  .out_2(k6b), .rcon(8'h40)),
    a8 (.clk(clk), .in(k7), .out_1(k8),  .out_2(k7b), .rcon(8'h80)),
    a9 (.clk(clk), .in(k8), .out_1(k9),  .out_2(k8b), .rcon(8'h1b)),
    a10(.clk(clk), .in(k9), .out_1(),    .out_2(k9b), .rcon(8'h36)); 

one_round
    r1 (.clk(clk), .rst(1'b0), .state_in(s0), .key(k0b), .state_out(s1)),
    r2 (.clk(clk), .rst(1'b0), .state_in(s1), .key(k1b), .state_out(s2)),
    r3 (.clk(clk), .rst(1'b0), .state_in(s2), .key(k2b), .state_out(s3)),
    r4 (.clk(clk), .rst(1'b0), .state_in(s3), .key(k3b), .state_out(s4)),
    r5 (.clk(clk), .rst(1'b0), .state_in(s4), .key(k4b), .state_out(s5)),
    r6 (.clk(clk), .rst(1'b0), .state_in(s5), .key(k5b), .state_out(s6)),
    r7 (.clk(clk), .rst(1'b0), .state_in(s6), .key(k6b), .state_out(s7)),
    r8 (.clk(clk), .rst(1'b0), .state_in(s7), .key(k7b), .state_out(s8)),
    r9 (.clk(clk), .rst(1'b0), .state_in(s8), .key(k8b), .state_out(s9));

final_round
    rf (.clk(clk), .rst(1'b0), .state_in(s9), .key_in(k9b), .state_out(out));
endmodule


module expand_key_128(clk, in, out_1, out_2, rcon);
input           clk;
input   [127:0] in;       
input   [7:0]   rcon;     
output reg [127:0] out_1; 
output     [127:0] out_2; 


wire [31:0] w0, w1, w2, w3;
assign {w0, w1, w2, w3} = in;


wire [31:0] w4, w5, w6, w7;


wire [31:0] rot_w3;
wire [31:0] sub_w3;
wire [31:0] rcon_word = {rcon, 24'b0};
wire [31:0] temp;


assign rot_w3 = {w3[23:0], w3[31:24]};


S4 sbox_stage (
    .clk(clk),
    .rst(1'b0),
    .in(rot_w3),
    .out(sub_w3)
);


assign temp = sub_w3 ^ rcon_word;


assign w4 = w0 ^ temp;
assign w5 = w1 ^ w4;
assign w6 = w2 ^ w5;
assign w7 = w3 ^ w6;


assign out_2 = {w4, w5, w6, w7};

always @(posedge clk) begin
    out_1 <= {w4, w5, w6, w7};
end

endmodule