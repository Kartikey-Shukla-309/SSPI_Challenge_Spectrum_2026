// ============================================================
// systolic_array_top.v  —  Parameterized N×N Systolic Array
//                          Verilog-2001 / ModelSim compatible
//
// FIX: Ports use FLAT PACKED BUSES instead of array ports.
//   Verilog-2001 does NOT allow:  input [31:0] inp_west [0:N-1]
//   Correct form:                 input [N*DATA_W-1:0] inp_west
//
// Slicing convention (row/col index i, 0-indexed from MSB end):
//   inp_west  [ (N-1-i)*DATA_W +: DATA_W ]  = west  input for row i
//   inp_north [ (N-1-j)*DATA_W +: DATA_W ]  = north input for col j
//
// Internal wires / result access:
//   uut.pe_row[i].pe_col[j].u_pe.sum_out
// ============================================================

`include "pe.v"

module systolic_array_top #(
    parameter N       = 2,
    parameter DATA_W  = 32,
    parameter ACCUM_W = 64
)(
    input  wire                     clk,
    input  wire                     rst,
    // Flat packed buses: N lanes × DATA_W bits
    input  wire [N*DATA_W-1:0]      inp_west,    // A rows
    input  wire [N*DATA_W-1:0]      inp_north,   // B cols
    output reg                      done
);
    // Internal wiring for horizontal (A) and vertical (B) data movement
    wire [DATA_W-1:0] wire_a [0:N-1][0:N];
    wire [DATA_W-1:0] wire_b [0:N][0:N-1];

    // 1. Connect external inputs to the boundary wires
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : input_mapping
            // West inputs feed into the first column of wires
            assign wire_a[i][0] = inp_west[(N-1-i)*DATA_W +: DATA_W];
            // North inputs feed into the first row of wires
            assign wire_b[0][i] = inp_north[(N-1-i)*DATA_W +: DATA_W];
        end
    endgenerate

    // 2. Instantiate the NxN Grid of PEs
    generate
        for (i = 0; i < N; i = i + 1) begin : pe_row
            for (j = 0; j < N; j = j + 1) begin : pe_col
                pe #(
                    .DATA_W(DATA_W),
                    .ACCUM_W(ACCUM_W)
                ) u_pe (
                    .clk(clk),
                    .rst(rst),
                    .a_in(wire_a[i][j]),
                    .b_in(wire_b[i][j]),
                    .a_out(wire_a[i][j+1]),
                    .b_out(wire_b[i+1][j]),
                    .sum_out() // sum_out accessed via hierarchy by TB
                );
            end
        end
    endgenerate

    // 3. Simple Done Logic
    // In a systolic array, the result is ready after 3N-2 cycles. 
    // For this hackathon, 'done' timing depends on your pipeline latency[cite: 36].
    reg [7:0] cycle_count;
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 8'd0;
            done <= 1'b0;
        end else begin
            if (cycle_count < (3*N)) begin
                cycle_count <= cycle_count + 1'b1;
                done <= 1'b0;
            end else begin
                done <= 1'b1;
            end
        end
    end
endmodule