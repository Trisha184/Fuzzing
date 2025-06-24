`timescale 1ns / 1ps

interface tb_if();
    logic clk;
    logic rst_n;

    // External Slave Interface (Central ? Satellite)
    logic ext_slave_we;
    logic [31:0] ext_slave_addr_write;
    logic [255:0] ext_slave_rdata;
    logic ext_slave_write_done;
    logic ext_slave_read_done;
    logic [31:0] ext_slave_addr_read;
    logic [255:0] ext_slave_wdata;

    // External Master Interface (Satellite ? Central)
    logic ext_master_req;
    logic ext_master_we;
    logic [31:0] ext_master_addr_read;
    logic [31:0] ext_master_addr_write;
    logic [255:0] ext_master_wdata;
    logic [255:0] ext_master_rdata;
    logic ext_master_read_done;
    logic ext_master_write_done;

    // ACK signals from fuzzers
    logic ack_rand;
    logic ack_mut;
endinterface


class transaction;
    rand bit [1:0] fuzz_mode;
    bit [31:0] addr;

    constraint fuzz_c { fuzz_mode inside {2'b01, 2'b10}; }

    function void display();
        $display("[TRANSACTION] Writing fuzz_mode = %b to address = %h", fuzz_mode, addr);
    endfunction
endclass


class Generator;
    mailbox driver_gen;
    event driverdone;

    function new(mailbox _driver_gen, event _driverdone);
        driver_gen = _driver_gen;
        driverdone = _driverdone;
    endfunction

    task gen();
        transaction tr;
        forever begin
            tr = new;
            tr.randomize();
            tr.addr = 32'h00000000;
            tr.display();
            driver_gen.put(tr);
            @(driverdone);
        end
    endtask
endclass


class Driver;
    mailbox driver_gen;
    event driverdone;
    virtual interface tb_if vif;

    function new(virtual interface tb_if vif, mailbox _driver_gen, event _driverdone);
        this.vif = vif;
        driver_gen = _driver_gen;
        driverdone = _driverdone;
    endfunction

    task drive();
        transaction tr;
        forever begin
            driver_gen.get(tr);
            $display("[DRIVER] Driving fuzz_mode = %b to addr %h", tr.fuzz_mode, tr.addr);

            vif.ext_slave_addr_write <= tr.addr;
            vif.ext_slave_rdata <= {{254{1'b0}}, tr.fuzz_mode};
            vif.ext_slave_we <= 1;
            vif.ext_slave_write_done <= 1;

            @(posedge vif.clk);
            vif.ext_slave_we <= 0;
            vif.ext_slave_write_done <= 0;

            fork
                begin
                    $display("[DRIVER] Waiting for ack...");
                    @(posedge vif.clk iff (vif.ack_rand || vif.ack_mut));
                    -> driverdone;
                    $display("[DRIVER] Ack received!");
                end
                begin
                    #500ns;
                    $display("[ERROR] No ack_rand or ack_mut received!");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask
endclass


class Monitor;
    virtual interface tb_if vif;
    mailbox mon_scor;

    function new(virtual interface tb_if vif, mailbox _mon_scor);
        this.vif = vif;
        mon_scor = _mon_scor;
    endfunction

    task monitor();
        transaction tr;
        forever begin
            @(posedge vif.clk iff (vif.ack_rand || vif.ack_mut));
            tr = new();
            $display("[MONITOR] Ack observed on fuzzers");
            mon_scor.put(tr);
        end
    endtask
endclass


class Scoreboard;
    mailbox mon_scor;
    function new(mailbox _mon_scor);
        mon_scor = _mon_scor;
    endfunction

    task check();
        transaction tr;
        for (int i = 0; i < 5; i++) begin
            mon_scor.get(tr);
            $display("[SCOREBOARD] Received transaction triggered by fuzzing event.");
        end
    endtask
endclass


class env;
    Generator gen;
    Driver drv;
    Monitor mon;
    Scoreboard scb;
    mailbox driver_gen;
    mailbox mon_scor;
    event driverdone;
    virtual interface tb_if vif;

    function new(virtual interface tb_if vif);
        this.vif = vif;
        driver_gen = new();
        mon_scor = new();
        gen = new(driver_gen, driverdone);
        drv = new(vif, driver_gen, driverdone);
        mon = new(vif, mon_scor);
        scb = new(mon_scor);
    endfunction

    virtual task run();
        fork
            gen.gen();
            drv.drive();
            mon.monitor();
            scb.check();
        join_any
    endtask
endclass


module tb_satellite_fuzzer_wrapper;

    parameter DATA_WIDTH      = 32;
    parameter READ_DATA_WIDTH = 64;
    parameter BUFFER_DEPTH    = 8;
    parameter MAX_WAIT_CYCLES = 100;
    parameter TEST_PATTERN    = 15;
    parameter ADDR_WIDTH      = 32;
    parameter EXT_RW_WIDTH    = 256;
    parameter MUTATION_WIDTH  = 8;

    tb_if tb_interface();

    satellite_fuzzer_wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .READ_DATA_WIDTH(READ_DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH),
        .MAX_WAIT_CYCLES(MAX_WAIT_CYCLES),
        .TEST_PATTERN(TEST_PATTERN),
        .ADDR_WIDTH(ADDR_WIDTH),
        .EXT_RW_WIDTH(EXT_RW_WIDTH),
        .MUTATION_WIDTH(MUTATION_WIDTH)
    ) dut (
        .clk(tb_interface.clk),
        .rst_n(tb_interface.rst_n),
        .ext_master_req(tb_interface.ext_master_req),
        .ext_master_we(tb_interface.ext_master_we),
        .ext_master_addr_read(tb_interface.ext_master_addr_read),
        .ext_master_addr_write(tb_interface.ext_master_addr_write),
        .ext_master_wdata(tb_interface.ext_master_wdata),
        .ext_master_rdata(tb_interface.ext_master_rdata),
        .ext_master_read_done(tb_interface.ext_master_read_done),
        .ext_master_write_done(tb_interface.ext_master_write_done),
        .ext_slave_we(tb_interface.ext_slave_we),
        .ext_slave_addr_read(tb_interface.ext_slave_addr_read),
        .ext_slave_addr_write(tb_interface.ext_slave_addr_write),
        .ext_slave_rdata(tb_interface.ext_slave_rdata),
        .ext_slave_wdata(tb_interface.ext_slave_wdata),
        .ext_slave_read_done(tb_interface.ext_slave_read_done),
        .ext_slave_write_done(tb_interface.ext_slave_write_done),
        .ack_rand(tb_interface.ack_rand),
        .ack_mut(tb_interface.ack_mut)
    );

    // Clock generation
    always #5 tb_interface.clk = ~tb_interface.clk;

    // Reset task
    task reset(virtual interface tb_if _if);
        _if.rst_n = 0;
        #20;
        @(negedge _if.clk);
        _if.rst_n = 1;
    endtask

    initial begin
        env e = new(tb_interface);
        tb_interface.clk = 0;
        reset(tb_interface);
        @(posedge tb_interface.clk);
        e.run();
        $finish;
    end
endmodule
