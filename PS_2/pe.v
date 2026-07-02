// ============================================================
// pe.v  —  Processing Element  (Verilog-2001 compatible)
// MAC: sum_out <= sum_out + (a_in * b_in)
// ============================================================
module pe #(
    parameter DATA_W  = 32,
    parameter ACCUM_W = 64
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire [DATA_W-1:0]    a_in,
    input  wire [DATA_W-1:0]    b_in,
    output reg  [DATA_W-1:0]    a_out,
    output reg  [DATA_W-1:0]    b_out,
    output reg  [ACCUM_W-1:0]   sum_out
);
    // Sequential logic for MAC and Pipeline Registers
    always @(posedge clk) begin
        if (rst) begin
            // Reset all registers to zero 
            a_out   <= {DATA_W{1'b0}};
            b_out   <= {DATA_W{1'b0}};
            sum_out <= {ACCUM_W{1'b0}};
        end else begin
            // 1. Pass data to neighbors (Pipelining) [cite: 13, 34]
            a_out   <= a_in;
            b_out   <= b_in;

            // 2. Perform Multiply-Accumulate (MAC) 
            // sum_out (acc) = sum_out + (a_in * b_in)
            sum_out <= sum_out + (a_in * b_in);
        end
    end
endmodule