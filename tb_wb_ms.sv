module tb_wishbone_dual;
 
  parameter ADDR_WIDTH   = 32;
  parameter DATA_WIDTH   = 32;
  parameter EXT_RW_WIDTH = 256;
 
  logic clk = 0;
  logic rst;
 
  // Wishbone Slave interface signals
  logic wbs_cyc_i, wbs_stb_i, wbs_we_i;
  logic [ADDR_WIDTH-1:0] wbs_adr_i;
  logic [DATA_WIDTH-1:0] wbs_dat_i;
  logic [DATA_WIDTH/8-1:0] wbs_sel_i;
  logic [2:0] wbs_cti_i;
  logic [1:0] wbs_bte_i;
  logic [DATA_WIDTH-1:0] wbs_dat_o;
  logic wbs_ack_o;
 
  // Wishbone Master interface signals
  logic wbm_cyc_o, wbm_stb_o, wbm_we_o;
  logic [ADDR_WIDTH-1:0] wbm_adr_o;
  logic [DATA_WIDTH-1:0] wbm_dat_o;
  logic [DATA_WIDTH/8-1:0] wbm_sel_o;
  logic [2:0] wbm_cti_o;
  logic [1:0] wbm_bte_o;
  logic [DATA_WIDTH-1:0] wbm_dat_i;
  logic wbm_ack_i;
 
  // External interface (fuzzer)
  logic ext_master_req, ext_master_we, ext_master_read_done, ext_master_write_done;
  logic [ADDR_WIDTH-1:0] ext_master_addr_read, ext_master_addr_write;
  logic [EXT_RW_WIDTH-1:0] ext_master_wdata, ext_master_rdata;
 
  logic [EXT_RW_WIDTH-1:0] ext_slave_wdata, ext_slave_rdata;
  logic ext_slave_we, ext_slave_read_done, ext_slave_write_done;
  logic [ADDR_WIDTH-1:0] ext_slave_addr_read, ext_slave_addr_write;

 
 
  // Instantiate the DUT
  wishbone_dual #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .EXT_RW_WIDTH(EXT_RW_WIDTH)
  ) dut (
    .* 
  );
 
  initial begin :generate_clock
      while (1)
          #5 clk = ~clk;
  end 


  logic [DATA_WIDTH-1:0] array_bus_read [0:(EXT_RW_WIDTH/DATA_WIDTH)-1];

  task initialize_array_bus_read();
    for (int i =0; i < (EXT_RW_WIDTH / DATA_WIDTH); i++) begin 
        array_bus_read[i] = 32'ha0000000 + i;
    end 
  endtask 

  always @(posedge clk) begin
    if (wbm_cyc_o && wbm_stb_o) begin
      wbm_ack_i <= 1;
    end
    else begin
      wbm_ack_i <= 0;
    end
  end


  // this portion is emulating data on the bus that master interface is trying to read
  integer k = 0;
  always @(posedge clk) begin
      if (wbm_cyc_o && wbm_stb_o) begin
          wbm_dat_i <= array_bus_read[k];
          // $displayh("Read address: ", wbm_adr_o, " & Read Data: ", wbm_dat_i);
          k <= k + 1;
      end
  end
  // ends here

  always @(posedge clk) begin
    if (wbm_cyc_o && wbm_stb_o && wbm_ack_i) begin
      // $displayh("write address: ", wbm_adr_o, "  write data: ", wbm_dat_o);
    end
  end

 
  initial begin
        $dumpfile("wishbone.vcd");
        $dumpvars(0, tb_wishbone_dual);
        initialize_array_bus_read();
        ext_master_wdata = {
                  32'hCAFEBABE,
                  32'hDEADBEEF,
                  32'hBEEF1234,
                  32'hFACEB00C,
                  32'h00112233,
                  32'h44556677,
                  32'h8899AABB,
                  32'hCCDDEEFF
              };

        ext_slave_wdata = {
                  32'hAB123456,
                  32'hBC567832,
                  32'hADB6743C,
                  32'hCACB4321,
                  32'hDADB3457,
                  32'h091243BC,
                  32'h13AD27BD,
                  32'hBA69B24A
              };

        rst = 1;
        ext_master_req = 0;
        ext_master_we  = 0;
        wbs_we_i = 0;
        wbs_cyc_i = 0;
        wbs_stb_i = 0;
        wbs_sel_i = '1;
        ext_master_addr_read = 32'h1000;
        ext_master_addr_write = 32'h2000;
        wbs_adr_i = 32'h3000;

        repeat(5) @(posedge clk);

        rst = 0;
        @(posedge clk);

        ////////////////////////////////////////////// Master interface is reading from the bus//////////////////////////////////////////
        $display("Triggering Read via master interface");

        ext_master_req = 1;
        ext_master_we = 0;
        @(posedge clk);
        ext_master_req = 0;


        wait (ext_master_read_done == 1);

        $display("Master Read Complete");

        $displayh("Read data from the bus ",ext_master_rdata);


         ////////////////////////////////////////////// Master interface is writing on the bus//////////////////////////////////////////

        $display("Triggering Write via master interface");

        ext_master_req = 1;
        ext_master_we = 1;
        repeat(5) @(posedge clk);
        ext_master_req = 0;

        while (!ext_master_write_done) begin
            @(posedge clk);
        end

        $display("Master Write Complete");


         ////////////////////////////////////////////// Slave interface is reading from the bus//////////////////////////////////////////

        $display("Triggering read via slave interface");

        wbs_cyc_i = 1;
        // wbs_stb_i = 1;
        wbs_we_i = 1;

        @(posedge clk);
        // @(posedge clk);

        for (int i = 0; i < 8; i++) begin
          wbs_stb_i = 1;
          wbs_adr_i = 32'h3000 + (i * 4);
          wbs_dat_i = array_bus_read[i]; // emulated data on the bus

           @(posedge clk);

          while (!wbs_ack_o) begin
            @(posedge clk);
          end

           $displayh("Read address: ", wbs_adr_i, " & Read Data: ", wbs_dat_i);

           wbs_stb_i = 0;
           @(posedge clk);
        
        end

        wbs_cyc_i = 0;

        while (!ext_slave_read_done) begin
          @(posedge clk);
        end

        $display("Slave read complete");

        $displayh("Read data via slave interface: ", ext_slave_rdata);


        ////////////////////////////////////////////// Slave interface is writing on the bus//////////////////////////////////////////

        $display("Triggering a write via slave interface");

        wbs_cyc_i = 1;
        wbs_we_i = 0;


        for (int i = 0; i < 8; i++) begin
          wbs_stb_i = 1;
          wbs_adr_i = 32'h4000 + (i * 4);


          while (!wbs_ack_o) begin
            @(posedge clk);
          end

           $displayh("Write address: ", wbs_adr_i, " & Write Data: ", wbs_dat_o);

           wbs_stb_i = 0;
           @(posedge clk);
        end
        
        wbs_cyc_i = 0;

        while (!ext_slave_write_done) begin
          @(posedge clk);
        end

        $display("Slave interface write complete");


        $finish;

      end


endmodule