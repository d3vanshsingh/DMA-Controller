module dma_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4  // fifo ke har slot/register ka address batane ke liye kyunki 16 ki depth hai toh 2^4 mein bata skte hain
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Write Port (from Read Master)
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  din,
    output wire                   full,

    // Read Port (to Write Master)
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  dout,
    output wire                   empty,

    // Status
    output reg [ADDR_WIDTH:0]     count
);

    // 1. fifo ke 32bits wide 16 registers
    reg [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    // 2. Pointers (The "Workers")
    reg [ADDR_WIDTH-1:0] wptr;
    reg [ADDR_WIDTH-1:0] rptr;

    // 3. Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0;
        end else if (wr_en && !full) begin
            fifo_mem[wptr] <= din;  //din wahan jayega fif_mem mein jahan wptr point kar raha hai
            wptr <= wptr + 1;
        end
    end

    // 4. Read Logic
    assign dout = fifo_mem[rptr]; // Combinational read

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rptr <= 0;
        end else if (rd_en && !empty) begin
            rptr <= rptr + 1;
        end
    end

    // 5. Status Count Logic (How many items are inside?)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})  //ye concatenation hai jo check krega ki case bann kaunsa raha hai
                2'b10: count <= count + 1; // Write only
                2'b01: count <= count - 1; // Read only
                2'b11: count <= count;     // Both (no change)
                default: count <= count;
            endcase
        end
    end

    // 6. Generate Flags
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

endmodule
