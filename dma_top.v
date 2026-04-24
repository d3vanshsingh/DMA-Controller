module dma_top (
    input  wire        clk,
    input  wire        rst_n,

    // --- AXI-Lite Slave Interface (CPU/Brain) ---
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // --- AXI-Full Master Read Interface (Source Memory) ---
    output wire [31:0] m_axi_araddr,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire        m_axi_rlast,

    // --- AXI-Full Master Write Interface (Destination Memory) ---
    output wire [31:0] m_axi_awaddr,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire        m_axi_wlast,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready
);

    // --- Internal Wires (The "Nerves") ---
    wire [31:0] src_addr, dst_addr, xfer_len;
    wire        start_pulse, rm_done, wm_done;
    
    // FIFO Wires
    wire [31:0] fifo_din, fifo_dout;
    wire        fifo_wr_en, fifo_rd_en;
    wire        fifo_full, fifo_empty;
    wire [4:0]  fifo_count;

    // --- 1. The Brain (AXI-Lite Slave) ---
    dma_axi_lite_slave brain (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        
        .src_addr_reg(src_addr), .dst_addr_reg(dst_addr), .xfer_len_reg(xfer_len),
        .dma_start_pulse(start_pulse),
        .dma_done_stat(wm_done) // Status bit
    );

    // --- 2. The Storage (FIFO) ---
    dma_fifo #(.DATA_WIDTH(32), .DEPTH(16)) buffer (
        .clk(clk), .rst_n(rst_n),
        .din(fifo_din), .wr_en(fifo_wr_en),
        .dout(fifo_dout), .rd_en(fifo_rd_en),
        .full(fifo_full), .empty(fifo_empty),
        .count(fifo_count)
    );

    // --- 3. The Fetcher (Read Master) ---
    dma_read_master rm (
        .clk(clk), .rst_n(rst_n),
        .start(start_pulse), .src_addr(src_addr), .done(rm_done),
        
        .m_axi_araddr(m_axi_araddr), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
        .m_axi_rlast(m_axi_rlast),
        
        .fifo_wr_en(fifo_wr_en), .fifo_din(fifo_din), .fifo_full(fifo_full)
    );

    // --- 4. The Pusher (Write Master) ---
    dma_write_master wm (
        .clk(clk), .rst_n(rst_n),
        .dst_addr(dst_addr), .done(wm_done),
        
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_wlast(m_axi_wlast), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        
        .fifo_empty(fifo_empty), .fifo_rd_en(fifo_rd_en), .fifo_dout(fifo_dout), .fifo_count(fifo_count)
    );

endmodule
