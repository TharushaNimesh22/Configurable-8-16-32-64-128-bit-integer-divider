module div_restoring_step #(
    parameter WIDTH = 8
)(
    input  wire [WIDTH-1:0] rem_in,   // Partial remainder entering this iteration
    input  wire [WIDTH-1:0] nq_in,    // Remaining dividend bits / partially constructed quotient
    input  wire [WIDTH-1:0] d,        // Divisor
    output wire [WIDTH-1:0] rem_out,  // Partial remainder leaving this iteration
    output wire [WIDTH-1:0] nq_out    // Partially constructed quotient leaving this iteration
);
    wire [WIDTH:0]   rem_sh = {rem_in, nq_in[WIDTH-1]};
    wire [WIDTH+1:0] diff   = {1'b0, rem_sh} - {2'b00, d};
    wire             qbit   = ~diff[WIDTH+1];          // 1 = no borrow

    assign rem_out = qbit ? diff[WIDTH-1:0] : rem_sh[WIDTH-1:0];
    assign nq_out  = {nq_in[WIDTH-2:0], qbit};  // update quotient with new bit
endmodule


