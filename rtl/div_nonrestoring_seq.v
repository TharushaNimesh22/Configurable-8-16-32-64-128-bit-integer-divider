module div_nonrestoring_seq #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] n,
    input  wire [WIDTH-1:0] d,
    output reg              busy,
    output reg              done,
    output wire [WIDTH-1:0] q,
    output wire [WIDTH-1:0] r
);
    localparam RW = WIDTH + 2;                    // signed remainder width
    localparam CW = $clog2(WIDTH + 2);

    reg  [RW-1:0]    rem;                         // two's complement
    reg  [WIDTH-1:0] nq, d_r;
    reg  [CW-1:0]    cnt;
    reg              fix;                         // 1 = correction cycle

    wire [RW-1:0] dx     = {2'b00, d_r};         // Extending teh divisor
    wire [RW-1:0] rem_sh = {rem[RW-2:0], nq[WIDTH-1]};  // Shifting the partial remainder
    wire          neg    = rem[RW-1];
    // subtract when positive, add when negative
    wire [RW-1:0] rem_nx = neg ? (rem_sh + dx) : (rem_sh - dx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rem <= 0; nq <= 0; d_r <= 0; cnt <= 0; fix <= 1'b0;
            busy <= 1'b0; done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin   // Start new division operation
                rem <= 0; nq <= n; d_r <= d; cnt <= 0; fix <= 1'b0;
                busy <= 1'b1;
            end else if (busy && !fix) begin
                rem <= rem_nx;
                nq  <= {nq[WIDTH-2:0], ~rem_nx[RW-1]};
                cnt <= cnt + 1'b1;
                if (cnt == WIDTH-1) fix <= 1'b1;
            end else if (busy && fix) begin
                if (neg) rem <= rem + dx;         // final remainder correction
                fix  <= 1'b0;
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end

    assign q = nq;
    assign r = rem[WIDTH-1:0];
endmodule
