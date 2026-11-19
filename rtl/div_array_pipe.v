module div_array_pipe #(
    parameter WIDTH          = 8,
    parameter ROWS_PER_STAGE = 1 // #restoring stages between two sets of pipeline registers
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             in_valid,
    input  wire [WIDTH-1:0] n,
    input  wire [WIDTH-1:0] d,
    output wire             out_valid,
    output wire [WIDTH-1:0] q,
    output wire [WIDTH-1:0] r
);
    localparam NS  = (WIDTH + ROWS_PER_STAGE - 1) / ROWS_PER_STAGE; // pipeline stages
    localparam LAT = NS + 1;                                        // + input reg

    // signals entering each row (carry the information between restoring rows)
    wire [WIDTH-1:0] rem [0:WIDTH];
    wire [WIDTH-1:0] nq  [0:WIDTH];
    wire [WIDTH-1:0] dd  [0:WIDTH];     //	Divisor associated with that division
    // Propagate the divisor through the pipeline, so that each stage has the correct divisor for its division operation

    // input register
    reg [WIDTH-1:0] n_r, d_r;
    always @(posedge clk) begin n_r <= n; d_r <= d; end

    assign rem[0] = {WIDTH{1'b0}};
    assign nq[0]  = n_r;
    assign dd[0]  = d_r;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : g_row
            wire [WIDTH-1:0] rem_o, nq_o;
            div_restoring_step #(.WIDTH(WIDTH)) u_step (
                .rem_in(rem[i]), .nq_in(nq[i]), .d(dd[i]),
                .rem_out(rem_o), .nq_out(nq_o));

            // register after this row if it ends a stage (or is the last row)
            if (((i + 1) % ROWS_PER_STAGE == 0) || (i == WIDTH-1)) begin : g_reg
                reg [WIDTH-1:0] rem_r, nq_r, d_rr;  // Put pipeline registers
                always @(posedge clk) begin
                    rem_r <= rem_o;  nq_r <= nq_o;  d_rr <= dd[i];
                end
                assign rem[i+1] = rem_r;
                assign nq[i+1]  = nq_r;
                assign dd[i+1]  = d_rr;
            end else begin : g_wire
                // If not the last row of a stage, just wire the outputs to the next row
                assign rem[i+1] = rem_o;
                assign nq[i+1]  = nq_o;
                assign dd[i+1]  = dd[i];
            end
        end
    endgenerate

    assign q = nq[WIDTH];
    assign r = rem[WIDTH];

    reg [LAT-1:0] vpipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vpipe <= {LAT{1'b0}};
        
        // shifts the validity information along with the corresponding data
        else        vpipe <= {vpipe[LAT-2:0], in_valid};
    end
    assign out_valid = vpipe[LAT-1];
endmodule
