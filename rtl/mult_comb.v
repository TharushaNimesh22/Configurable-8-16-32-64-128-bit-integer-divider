// Combinational shift-and-add multiplier
// Replace this with Booth + wallace multipler
module mult_comb #(
    parameter WA = 8,
    parameter WB = 8
)(
    input  wire [WA-1:0]    a,
    input  wire [WB-1:0]    b,
    output wire [WA+WB-1:0] p
);
    // Accumulator array
    wire [WA+WB-1:0] acc [0:WB];
    assign acc[0] = {(WA+WB){1'b0}};

    genvar i;
    generate
        for (i = 0; i < WB; i = i + 1) begin : g_pp
            wire [WA+WB-1:0] pp = b[i] ? ({{WB{1'b0}}, a} << i) : {(WA+WB){1'b0}};
            assign acc[i+1] = acc[i] + pp;
        end
    endgenerate

    assign p = acc[WB];
endmodule
