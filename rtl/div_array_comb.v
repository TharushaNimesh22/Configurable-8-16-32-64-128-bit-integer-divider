module div_array_comb #(
    parameter WIDTH = 8
)(
    input  wire [WIDTH-1:0] n,
    input  wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q,
    output wire [WIDTH-1:0] r
);
    // arrays of wires used to connect consecutive restoring stages
    wire [WIDTH-1:0] rem [0:WIDTH];
    wire [WIDTH-1:0] nq  [0:WIDTH];

    assign rem[0] = {WIDTH{1'b0}};
    assign nq[0]  = n;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : g_row
            div_restoring_step #(.WIDTH(WIDTH)) u_step (
                .rem_in(rem[i]), .nq_in(nq[i]), .d(d),
                .rem_out(rem[i+1]), .nq_out(nq[i+1]));
        end
    endgenerate

    assign q = nq[WIDTH];
    assign r = rem[WIDTH];
endmodule
