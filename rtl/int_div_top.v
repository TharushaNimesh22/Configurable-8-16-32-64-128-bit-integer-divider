module int_div_top #(
    parameter WIDTH          = 32,
    parameter ARCH           = 0,
    parameter ROWS_PER_STAGE = 1
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             in_valid,
    output wire             in_ready,
    input  wire [WIDTH-1:0] n,          // dividend
    input  wire [WIDTH-1:0] d,          // divisor
    output wire             out_valid,
    output wire [WIDTH-1:0] q,          // quotient
    output wire [WIDTH-1:0] r           // remainder
);
    generate
        // iterative cores
        if (ARCH == 0 || ARCH == 1 || ARCH == 2 || ARCH == 5) begin : g_seq
            wire busy, done;
            if (ARCH == 0) begin : g_rest
                div_restoring_seq    #(.WIDTH(WIDTH)) u_core (
                    .clk(clk), .rst_n(rst_n), .start(in_valid), .n(n), .d(d),
                    .busy(busy), .done(done), .q(q), .r(r));
            end else if (ARCH == 1) begin : g_nrest
                div_nonrestoring_seq #(.WIDTH(WIDTH)) u_core (
                    .clk(clk), .rst_n(rst_n), .start(in_valid), .n(n), .d(d),
                    .busy(busy), .done(done), .q(q), .r(r));
            end else if (ARCH == 2) begin : g_r4
                div_radix4_seq       #(.WIDTH(WIDTH)) u_core (
                    .clk(clk), .rst_n(rst_n), .start(in_valid), .n(n), .d(d),
                    .busy(busy), .done(done), .q(q), .r(r));
            end else begin : g_nr
                div_newton_raphson   #(.WIDTH(WIDTH)) u_core (
                    .clk(clk), .rst_n(rst_n), .start(in_valid), .n(n), .d(d),
                    .busy(busy), .done(done), .q(q), .r(r));
            end
            assign in_ready  = ~busy;
            assign out_valid = done;

        // pipelined core
        end else if (ARCH == 4) begin : g_pipe
            div_array_pipe #(.WIDTH(WIDTH), .ROWS_PER_STAGE(ROWS_PER_STAGE)) u_core (
                .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .n(n), .d(d),
                .out_valid(out_valid), .q(q), .r(r));
            assign in_ready = 1'b1;

        // combinational core
        end else begin : g_comb
            reg  [WIDTH-1:0] n_r, d_r, q_r, r_r;
            reg              v1, v2;
            wire [WIDTH-1:0] q_c, r_c;

            div_array_comb #(.WIDTH(WIDTH)) u_core (
                .n(n_r), .d(d_r), .q(q_c), .r(r_c));

            always @(posedge clk) begin
                n_r <= n;  d_r <= d;  q_r <= q_c;  r_r <= r_c;
            end
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin v1 <= 1'b0; v2 <= 1'b0; end
                else        begin v1 <= in_valid; v2 <= v1; end
            end
            assign q         = q_r;
            assign r         = r_r;
            assign out_valid = v2;
            assign in_ready  = 1'b1;
        end
    endgenerate
endmodule
