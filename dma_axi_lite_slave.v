module dma_axi_lite_slave (
    input  wire        clk,
    input  wire        rst_n,

    // --- AXI-Lite Write Address Channel ---
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    // --- AXI-Lite Write Data Channel ---
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb, // Byte strobes (usually 4'hF)
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    // --- AXI-Lite Write Response Channel ---
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // --- AXI-Lite Read Address Channel ---
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    // --- AXI-Lite Read Data Channel ---
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // --- Internal Interface (To Read/Write Masters) ---
    output reg [31:0]  src_addr_reg,
    output reg [31:0]  dst_addr_reg,
    output reg [31:0]  xfer_len_reg,
    output reg         dma_start_pulse, 
    input  wire        dma_busy_stat,
    input  wire        dma_done_stat
);

    // Register Offsets (Addressing [4:2] for 4-byte alignment)
    localparam ADDR_CTRL = 3'd0, // 0x00
               ADDR_SRC  = 3'd1, // 0x04
               ADDR_DST  = 3'd2, // 0x08
               ADDR_LEN  = 3'd3, // 0x0C
               ADDR_STAT = 3'd4; // 0x10

    // 1. Write Handshake & Register Update Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr_reg    <= 32'h0;
            dst_addr_reg    <= 32'h0;
            xfer_len_reg    <= 32'h0;
            dma_start_pulse <= 1'b0;
            s_axi_awready   <= 1'b1; // Always ready to take address
            s_axi_wready    <= 1'b1; // Always ready to take data
        end else begin
            // Handshake Logic: AWVALID && WVALID (Address + Data both ready)
            if (s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready) begin
                case (s_axi_awaddr[4:2])
                    ADDR_CTRL: dma_start_pulse <= s_axi_wdata[0]; // Start Bit
                    ADDR_SRC:  src_addr_reg    <= s_axi_wdata;
                    ADDR_DST:  dst_addr_reg    <= s_axi_wdata;
                    ADDR_LEN:  xfer_len_reg    <= s_axi_wdata;
                    default:   ; // Do nothing for read-only or invalid
                endcase
            end else begin
                dma_start_pulse <= 1'b0; // Auto-clear start pulse for hardware
            end
        end
    end

    // 2. Write Response Logic (B Channel)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00; // OKAY
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid)
                s_axi_bvalid <= 1'b1;
            else if (s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // 3. Read Logic (CPU checking DMA status)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr[4:2])
                    ADDR_CTRL: s_axi_rdata <= 32'h0; // Write only usually
                    ADDR_SRC:  s_axi_rdata <= src_addr_reg;
                    ADDR_DST:  s_axi_rdata <= dst_addr_reg;
                    ADDR_LEN:  s_axi_rdata <= xfer_len_reg;
                    ADDR_STAT: s_axi_rdata <= {30'h0, dma_done_stat, dma_busy_stat};
                    default:   s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
