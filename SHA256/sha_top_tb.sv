// `timescale 1 ns / 100 ps

module sha_top_tb;


logic [511:0] block;
logic clk = 0;
logic rst;
logic init;
logic next;
logic sel;
logic [255:0] digest;
logic ready;
logic digest_valid;
logic [255:0] pufout;


integer       input_file;
integer       output_file;
logic         is_first_block = 1;

sha_top sha (.*); 

	initial begin :generate_clock
		while (1)
			#5 clk = ~clk;
	end	



initial begin : drive; 

    input_file = $fopen("input.txt", "r");
    if (input_file == 0) begin
        $display("ERROR: Could not open input.txt for reading.");
        $finish;
    end

    output_file = $fopen("output.txt", "w");
    if (output_file == 0) begin
        $display("ERROR: Could not open output.txt for writing.");
        $finish;
    end


    sel = 1; 
    rst = 1;
    block = 0;
    init = 0;
    next = 0;
    for (int i = 0; i < 10; i++) begin
        @(posedge clk); 
    end 

    rst = 0; 
    @(posedge clk);

    while (!$feof(input_file)) begin
        if ($fscanf(input_file, "%h\n", block) != 1) continue;
            $display("Processing block: %h", block);
        if (is_first_block) begin
            // For first 512 bits chunk init = 1, next = 0
            init = 1;
            next = 0;
        end else begin
            // For subsequent 512 bits chunks init = 0, next = 1
            init = 0;
            next = 1;
        end

        @(posedge clk);

        init = 0;
        next = 0;
        @(posedge clk);

        wait (digest_valid == 1);
        
        $displayh("  -> Hashed Value = ", digest);
        $fdisplayh(output_file, digest);
        
        is_first_block = 0; 
        
        @(posedge clk); 
    end

    $display("Finished processing all blocks from file.");
    $fclose(input_file);
    $fclose(output_file);
    $finish;
end 


endmodule 