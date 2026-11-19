module div_restoring_seq #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,      // accepted when !busy
    input  wire [WIDTH-1:0] n,          // dividend
    input  wire [WIDTH-1:0] d,          // divisor
    output reg              busy,
    output reg              done,       // 1 cycle pulse, q/r valid while done=1
    output wire [WIDTH-1:0] q,
    output wire [WIDTH-1:0] r
);
    localparam CW = $clog2(WIDTH + 1);   // Counter width

    reg  [WIDTH-1:0] rem, nq, d_r;
    reg  [CW-1:0]    cnt;
    wire [WIDTH-1:0] rem_nx, nq_nx;

    div_restoring_step #(.WIDTH(WIDTH)) u_step (
        .rem_in(rem), .nq_in(nq), .d(d_r), .rem_out(rem_nx), .nq_out(nq_nx));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rem <= 0; nq <= 0; d_r <= 0; cnt <= 0; busy <= 1'b0; done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                rem <= 0; nq <= n; d_r <= d; cnt <= 0; busy <= 1'b1;
            end else if (busy) begin
                // Update remainder and quotient for next iteration
                rem <= rem_nx;
                nq  <= nq_nx;
                cnt <= cnt + 1'b1;
                if (cnt == WIDTH-1) begin busy <= 1'b0; done <= 1'b1; end
            end
        end
    end

    assign q = nq;
    assign r = rem;
endmodule
