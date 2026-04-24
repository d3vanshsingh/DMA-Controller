`timescale 1ns/1ps

// 1. Interface: Signals ka bundle
interface dma_if(input logic clk);
    logic rst_n;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic arvalid, arready, rvalid, rready, rlast;
    logic [4:0] fifo_count; // For coverage
endinterface

// 2. Scoreboard for Data Integrity
class scoreboard;
    logic [31:0] scb_queue[$]; 

    function void store_expected(logic [31:0] data);
        scb_queue.push_back(data);
    endfunction

    function void check_data(logic [31:0] actual_data);
        if(scb_queue.size() > 0) begin
            logic [31:0] expected = scb_queue.pop_front();
            if(actual_data == expected)
                $display("[PASS] %t: Data Integrity Match! Value: %h", $time, actual_data);
            else
                $error("[FAIL] %t: Mismatch! Exp: %h, Got: %h", $time, expected, actual_data);
        end
    endfunction
endclass

// 3. Functional Coverage Class
class dma_coverage;
    logic [31:0] addr;
    logic [4:0] count;

    covergroup cg_dma;
        cp_addr: coverpoint addr {
            bins low = {[32'h0000:32'h7FFF]};
            bins high = {[32'h8000:32'hFFFF]};
        }
        cp_fifo: coverpoint count {
            bins empty = {0};
            bins full = {16};
            bins partial = {[1:15]};
        }
    endgroup

    function new(); cg_dma = new(); endfunction
    
    function void sample(logic [31:0] a, logic [4:0] c);
        this.addr = a;
        this.count = c;
        cg_dma.sample();
    endfunction
endclass

// 4. Main Testbench Module
module dma_tb;
    bit clk;
    always #5 clk = ~clk; // 100MHz clock

    dma_if tif(clk);
    scoreboard scb = new();
    dma_coverage cov = new();

    // Instantiate DUT (Device Under Test)
    dma_top dut (
        .clk(clk), .rst_n(tif.rst_n),
        .s_axi_awaddr(tif.awaddr), .s_axi_awvalid(tif.awvalid), .s_axi_awready(tif.awready),
        .s_axi_wdata(tif.wdata), .s_axi_wvalid(tif.wvalid), .s_axi_wready(tif.wready),
        .s_axi_bvalid(tif.bvalid), .s_axi_bready(tif.bready),
        // ... Baki saare connections tif se jhor do
        .m_axi_rdata(tif.rdata), .m_axi_rvalid(tif.rvalid), .m_axi_rready(tif.rready)
    );

    initial begin
        tif.rst_n = 0;
        #20 tif.rst_n = 1;

        // Simulate a Write to DMA Registers
        @(posedge clk);
        tif.awaddr = 32'h04; // SRC_ADDR offset
        tif.wdata = 32'h1234_5678;
        tif.awvalid = 1; tif.wvalid = 1;
        scb.store_expected(32'h1234_5678); // Predict
        @(posedge clk);
        tif.awvalid = 0; tif.wvalid = 0;

        // Sample Coverage
        cov.sample(tif.awaddr, 5'd0);

        #100;
        $display("Simulation Finished!");
        $finish;
    end
endmodule
