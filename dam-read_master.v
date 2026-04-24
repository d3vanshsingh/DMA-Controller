module dma_read_master (
    input  wire          clk,
    input  wire          rst_n,

    // Control Pins
    input  wire          start,
    input  wire [31:0]   src_addr,
    output reg           done,

    // AXI AR Channel (Address)
    output reg  [31:0]   m_axi_araddr,
    output reg           m_axi_arvalid,
    input  wire          m_axi_arready,
    output wire [7:0]    m_axi_arlen,   // Fixed to 15 (16 beats)

    // AXI R Channel (Data)
    input  wire [31:0]   m_axi_rdata,
    input  wire          m_axi_rvalid,
    output wire          m_axi_rready,
    input  wire          m_axi_rlast,

    // Interface to FIFO
    output wire          fifo_wr_en,
    output wire [31:0]   fifo_din,
    input  wire          fifo_full
);

    assign m_axi_arlen = 8'd15; // 16 beats
    
    // Handshake: Data FIFO mein tabhi jayega jab AXI pe valid ho aur FIFO full na ho
    assign m_axi_rready = !fifo_full;
    assign fifo_wr_en   = m_axi_rvalid && m_axi_rready;
    assign fifo_din     = m_axi_rdata;

    localparam IDLE = 2'd0, SEND_ADDR = 2'd1, READ_DATA = 2'd2;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m_axi_arvalid <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        m_axi_araddr  <= src_addr;
                        m_axi_arvalid <= 1;
                        state         <= SEND_ADDR;
                    end
                end
                SEND_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 0;
                        state         <= READ_DATA;
                    end
                end
                READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                        done  <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
