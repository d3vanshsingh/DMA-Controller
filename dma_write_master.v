module dma_write_master (
    input  wire          clk,
    input  wire          rst_n,

    // Control Pins
    input  wire [31:0]   dst_addr,
    output reg           done,

    // AXI AW Channel (Address)
    output reg  [31:0]   m_axi_awaddr,
    output reg           m_axi_awvalid,
    input  wire          m_axi_awready,
    output wire [7:0]    m_axi_awlen,

    // AXI W Channel (Data)
    output wire [31:0]   m_axi_wdata,
    output wire          m_axi_wvalid,
    input  wire          m_axi_wready,
    output wire          m_axi_wlast,

    // AXI B Channel (Response)
    input  wire          m_axi_bvalid,
    output wire          m_axi_bready,

    // Interface to FIFO
    input  wire          fifo_empty,
    output wire          fifo_rd_en,
    input  wire [31:0]   fifo_dout,
    input  wire [4:0]    fifo_count // Hum check karenge ki 16 beats hain ya nahi
);

    assign m_axi_awlen = 8'd15;
    assign m_axi_bready = 1'b1; // Hamesha ready response ke liye

    // Logic: FIFO se data tabhi nikalenge jab AXI bhej sake aur FIFO empty na ho
    assign m_axi_wvalid = !fifo_empty && (state == WRITE_DATA);
    assign fifo_rd_en   = m_axi_wvalid && m_axi_wready;
    assign m_axi_wdata  = fifo_dout;

    localparam IDLE = 2'd0, SEND_ADDR = 2'd1, WRITE_DATA = 2'd2, WAIT_RESP = 2'd3;
    reg [1:0] state;
    reg [3:0] beat_cnt;

    assign m_axi_wlast = (beat_cnt == 4'd15) && m_axi_wvalid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m_axi_awvalid <= 0;
            beat_cnt <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    // Hum tabhi shuru karenge jab FIFO mein pura burst (16 beats) aa jaye
                    if (fifo_count >= 5'd16) begin
                        m_axi_awaddr  <= dst_addr;
                        m_axi_awvalid <= 1;
                        state         <= SEND_ADDR;
                    end
                end
                SEND_ADDR: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 0;
                        state         <= WRITE_DATA;
                    end
                end
                WRITE_DATA: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (beat_cnt == 4'd15) begin
                            beat_cnt <= 0;
                            state    <= WAIT_RESP;
                        end else begin
                            beat_cnt <= beat_cnt + 1;
                        end
                    end
                end
                WAIT_RESP: begin
                    if (m_axi_bvalid) begin
                        done  <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
