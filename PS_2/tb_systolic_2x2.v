// ============================================================
// tb_systolic_2x2.v  —  Self-Checking Testbench  N=2
//
// FIXES vs previous version:
//  1. Ports use packed buses: reg [N*DATA_W-1:0] inp_west/north
//  2. Bus slice helper task packs/unpacks individual lanes
//  3. capture_outputs uses fixed-index hierarchical paths
//     (ModelSim 2020 forbids variable generate-block indices)
// ============================================================
`timescale 1ns/1ps
`include "systolic_array_top.v"

module tb_systolic_2x2;

    // ----------------------------------------------------------
    localparam N            = 2;
    localparam DATA_W       = 32;
    localparam ACCUM_W      = 64;
    localparam STREAM_CYCLES = 2*N - 1;
    // ----------------------------------------------------------

    reg  clk, rst;

    // Flat packed buses  (lane i = bits [(N-1-i)*DATA_W +: DATA_W])
    reg  [N*DATA_W-1:0]  inp_west;
    reg  [N*DATA_W-1:0]  inp_north;
    wire                 done;

    systolic_array_top #(.N(N),.DATA_W(DATA_W),.ACCUM_W(ACCUM_W)) uut (
        .clk      (clk),
        .rst      (rst),
        .inp_west (inp_west),
        .inp_north(inp_north),
        .done     (done)
    );

    // ---- Clock ------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // ---- Matrices & storage -----------------------------------
    reg [DATA_W-1:0]  A      [0:N-1][0:N-1];
    reg [DATA_W-1:0]  B      [0:N-1][0:N-1];
    reg [ACCUM_W-1:0] GOLDEN [0:N-1][0:N-1];
    reg [ACCUM_W-1:0] DUT_R  [0:N-1][0:N-1];

    integer i, j, k, ti;
    integer total, passed, failed;
    integer grand_total, grand_passed, grand_failed;
    integer seed;
    real    t_start_ns, t_done_ns, latency_ns;

    // ----------------------------------------------------------
    // Helper: set one lane of inp_west / inp_north
    //   lane i -> bits [(N-1-i)*DATA_W +: DATA_W]
    // ----------------------------------------------------------
    task set_west;
        input integer lane;
        input [DATA_W-1:0] val;
    begin
        inp_west[ (N-1-lane)*DATA_W +: DATA_W ] = val;
    end
    endtask

    task set_north;
        input integer lane;
        input [DATA_W-1:0] val;
    begin
        inp_north[ (N-1-lane)*DATA_W +: DATA_W ] = val;
    end
    endtask

    // ----------------------------------------------------------
    // TASK: reset_dut
    // ----------------------------------------------------------
    task reset_dut;
    begin
        @(negedge clk);
        rst       = 1;
        inp_west  = {(N*DATA_W){1'b0}};
        inp_north = {(N*DATA_W){1'b0}};
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
    end
    endtask

    // ----------------------------------------------------------
    // TASK: compute_golden
    // ----------------------------------------------------------
    task compute_golden;
    begin
        for (i=0;i<N;i=i+1)
            for (j=0;j<N;j=j+1) begin
                GOLDEN[i][j] = 0;
                for (k=0;k<N;k=k+1)
                    GOLDEN[i][j] = GOLDEN[i][j] + A[i][k]*B[k][j];
            end
    end
    endtask

    // ----------------------------------------------------------
    // TASK: apply_skewed_stream
    // Cycle t: West[row] = A[row][t-row], North[col] = B[t-col][col]
    // ----------------------------------------------------------
    task apply_skewed_stream;
        integer ar, bc, row, col;
    begin
        t_start_ns = $realtime;
        for (ti=0; ti<STREAM_CYCLES; ti=ti+1) begin
            @(negedge clk);
            inp_west  = {(N*DATA_W){1'b0}};
            inp_north = {(N*DATA_W){1'b0}};
            for (row=0; row<N; row=row+1) begin
                ar = ti - row;
                if (ar >= 0 && ar < N)
                    set_west(row, A[row][ar]);
            end
            for (col=0; col<N; col=col+1) begin
                bc = ti - col;
                if (bc >= 0 && bc < N)
                    set_north(col, B[bc][col]);
            end
        end
        // flush
        @(negedge clk);
        inp_west  = {(N*DATA_W){1'b0}};
        inp_north = {(N*DATA_W){1'b0}};
    end
    endtask

    // ----------------------------------------------------------
    // TASK: capture_outputs
    // Fixed-index hierarchical paths only (ModelSim 2020 rule).
    // ----------------------------------------------------------
    task capture_outputs;
    begin
        DUT_R[0][0] = uut.pe_row[0].pe_col[0].u_pe.sum_out;
        DUT_R[0][1] = uut.pe_row[0].pe_col[1].u_pe.sum_out;
        DUT_R[1][0] = uut.pe_row[1].pe_col[0].u_pe.sum_out;
        DUT_R[1][1] = uut.pe_row[1].pe_col[1].u_pe.sum_out;
    end
    endtask

    // ----------------------------------------------------------
    // TASK: check_results
    // ----------------------------------------------------------
    task check_results;
        input [255:0] label;
    begin
        $display("\n====== SCOREBOARD [N=%0d] : %s ======", N, label);
        total = 0; passed = 0;
        for (i=0;i<N;i=i+1)
            for (j=0;j<N;j=j+1) begin
                total = total + 1;
                if (DUT_R[i][j] === GOLDEN[i][j]) begin
                    passed = passed + 1;
                    $display("  PASS  C[%0d][%0d] = %0d", i, j, DUT_R[i][j]);
                end else
                    $display("  FAIL  C[%0d][%0d] | DUT=%0d  EXPECTED=%0d",
                             i, j, DUT_R[i][j], GOLDEN[i][j]);
            end
        failed = total - passed;
        $display("  ----------------------------------------");
        $display("  TOTAL: %0d  PASSED: %0d  FAILED: %0d  ACCURACY: %0.2f%%",
                 total, passed, failed, (passed*100.0)/total);
        grand_total  = grand_total  + total;
        grand_passed = grand_passed + passed;
        grand_failed = grand_failed + failed;
    end
    endtask

    // ----------------------------------------------------------
    // TASK: run_test
    // ----------------------------------------------------------
    task run_test;
        input [255:0] label;
    begin
        compute_golden();
        reset_dut();
        apply_skewed_stream();
        wait (done === 1'b1);
        t_done_ns  = $realtime;
        latency_ns = t_done_ns - t_start_ns;
        repeat(4) @(posedge clk);
        capture_outputs();
        check_results(label);
        $display("  Latency: %0.1f ns  (%0d cycles @ 10ns)",
                 latency_ns, $rtoi(latency_ns/10.0));
    end
    endtask

    // ----------------------------------------------------------
    // MAIN
    // ----------------------------------------------------------
    initial begin
        grand_total = 0; grand_passed = 0; grand_failed = 0;
        seed = 17;

        // Test 1: Small integers
        A[0][0]=1; A[0][1]=2;
        A[1][0]=3; A[1][1]=4;
        B[0][0]=5; B[0][1]=6;
        B[1][0]=7; B[1][1]=8;
        run_test("Small integers");

        // Test 2: Zero
        for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin
            A[i][j]=0; B[i][j]=0; end
        run_test("Zero matrix");

        // Test 3: Identity
        for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin
            A[i][j]=(i==j)?1:0; B[i][j]=(i==j)?1:0; end
        run_test("Identity x Identity");

        // Test 4: Max value
        for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin
            A[i][j]=32'hFF; B[i][j]=32'hFF; end
        run_test("Max value (0xFF)");

        // Tests 5-9: Random
        repeat(5) begin
            for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin
                A[i][j] = $random(seed) & 32'hFF;
                B[i][j] = $random(seed) & 32'hFF;
            end
            run_test("Random stress");
        end

        // Grand summary
        $display("\n+=========================================+");
        $display("|   GRAND SUMMARY  N = %0d                  |", N);
        $display("+=========================================+");
        $display("|   TOTAL   : %4d                         |", grand_total);
        $display("|   PASSED  : %4d                         |", grand_passed);
        $display("|   FAILED  : %4d                         |", grand_failed);
        $display("|   ACCURACY: %0.2f%%                     |",
                 (grand_passed*100.0)/grand_total);
        $display("+=========================================+\n");

        #50 $finish;
    end

    initial begin
        $dumpfile("wave_2x2.vcd");
        $dumpvars(0, tb_systolic_2x2);
    end

endmodule