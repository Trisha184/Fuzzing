class transaction;
    rand bit [31:0] hwdata;
    logic [31:0] hrdata;
    logic [32:0] random_output;
    logic [32:0] mutated_output;
    logic ack_rand, ack_mut;
    constraint c1 {hwdata[1:0] inside {[0:2]};}
    function void display();
        $display("hwdata = %b, hrdata = %h, random_output = %h, mutated_output = %h", hwdata, hrdata, random_output, mutated_output);
    endfunction
endclass


class Generator;
    
    mailbox driver_gen;
    event driverdone;
 
    function new(mailbox _driver_gen, event _driverdone);
        driver_gen = _driver_gen;
        driverdone = _driverdone;
    endfunction  // new

    task gen();
        transaction tr;
        forever begin
            tr = new;
            tr.randomize();
            tr.display();
            $display("[GENERATOR] block is excuted and Randomized");
            driver_gen.put(tr);
            /*fork
                @(driverdone);
                begin
                    #500ns;
                    $display("ERROR: Timeout waiting for driverdone event!");
                    $finish;
                end
            join_any
            disable fork;*/
            @(driverdone);
            //wait(driverdone.triggered);
            $display("see you here");
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
        transaction tr = new();
        forever begin
            $display("DRIVER it is here now");
            driver_gen.get(tr);
            vif.hsel   <= 1;
            vif.hwrite <= 1;
            vif.hwdata <= tr.hwdata; // Mode selection in lower 2 bits
            @(posedge vif.clk);
            
            //@(posedge vif.clk iff(vif.ack_rand == 1'b1 || vif.ack_mut == 1'b1));
            fork
                begin
                    $display("[Driver] waiting for this");
                    @(posedge vif.clk iff(vif.ack_rand == 1'b1 || vif.ack_mut == 1'b1));
                    -> driverdone;
                    $display("[Driver] dones");
                end
                begin
                    #500ns;  // Timeout for debug
                    $display("ERROR: No ack_rand or ack_mut received!");
                    $finish;
                end                    
            join_any
            disable fork;
            
            //$display("it is not executed");
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
        forever begin
        transaction tr = new();
        @(posedge vif.clk iff(vif.ack_rand == 1'b1 || vif.ack_mut == 1'b1));
        tr.random_output = vif.random_output;
        tr.mutated_output = vif.mutated_output;
        $display("[MONITOR] HRDATA: %h | Random Output: %h | Mutated Output: %h", vif.hrdata, vif.random_output, vif.mutated_output);
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
            $display("[SCOREBOARD] Recieved items are Random Output: %h | Mutated Output: %h", tr.random_output, tr.mutated_output);
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
        driver_gen = new;
        mon_scor = new;
        gen = new(driver_gen,driverdone);
        drv = new(vif,driver_gen,driverdone);
        mon = new(vif,mon_scor);
        scb = new(mon_scor);
        //gen.driver_gen = driver_gen;
        //gen.driverdone = driverdone;
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


interface tb_if();
    logic clk;
    logic rst_n;
    logic hsel;
    logic hwrite;
    logic [31:0] hwdata;
    logic [31:0] hrdata;
    logic [32:0] random_output;
    logic [32:0] mutated_output;
    logic ack_rand;
    logic ack_mut;

endinterface


`timescale 1ns / 1ps

module tb_satellite_fuzzer_wrapper;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter BUFFER_DEPTH = 8;

    // Instantiate Interface
    tb_if tb_interface();

    // Instantiate DUT
    satellite_fuzzer_wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH)
    ) dut (
        .clk(tb_interface.clk),
        .rst_n(tb_interface.rst_n),
        .hsel(tb_interface.hsel),
        .hwrite(tb_interface.hwrite),
        .hwdata(tb_interface.hwdata),
        .hrdata(tb_interface.hrdata),
        .random_output(tb_interface.random_output),
        .mutated_output(tb_interface.mutated_output),
        .ack_rand(tb_interface.ack_rand),
        .ack_mut(tb_interface.ack_mut)
    );

    // Clock Generation
    always #5 tb_interface.clk <= ~tb_interface.clk;

    // Reset Task
    task reset(virtual interface tb_if _if);
        _if.rst_n <= 0;
        #20;
        @(negedge _if.clk);
        _if.rst_n <= 1;
    endtask



    

    initial begin
        env _env = new(tb_interface);
        //$dumpfile("tb_satellite_fuzzer_wrapper.vcd");
        //$dumpvars(0, tb_satellite_fuzzer_wrapper);
        
        tb_interface.clk <= 0;

        reset(tb_interface);
        @(posedge tb_interface.clk);
        _env.run();
        
        
        $finish;
    end

endmodule
