module div_radix4_seq #(
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
    localparam N2 = WIDTH + (WIDTH % 2);     // round up to an even width
    localparam ND = N2 / 2;                  // number of radix-4 iterations
    localparam RW = WIDTH + 2;               // remainder after shift < 4d
    localparam CW = $clog2(ND + 2);

    reg  [WIDTH-1:0] rem;
    reg  [N2-1:0]    nq;
    reg  [RW-1:0]    d1, d2, d3;             // d, 2d, 3d
    reg  [CW-1:0]    cnt;
    reg              init;                   // 1 = cycle that computes 3d

    wire [RW-1:0] rem_sh = {rem, nq[N2-1:N2-2]};  // Shifted current partial remainder left(2 bits)
    
    // Trail subtraction to find the largest digit that can be subtracted from the shifted remainder
    wire [RW:0]   t1 = {1'b0, rem_sh} - {1'b0, d1};
    wire [RW:0]   t2 = {1'b0, rem_sh} - {1'b0, d2};
    wire [RW:0]   t3 = {1'b0, rem_sh} - {1'b0, d3};

    // Check if the subtraction results are non negative
    wire ok1 = ~t1[RW], ok2 = ~t2[RW], ok3 = ~t3[RW];  

    reg [1:0]       digit;
    reg [WIDTH-1:0] rem_nx;

    // Quotient digit selection
    always @(*) begin
        if      (ok3) begin digit = 2'd3; rem_nx = t3[WIDTH-1:0]; end
        else if (ok2) begin digit = 2'd2; rem_nx = t2[WIDTH-1:0]; end
        else if (ok1) begin digit = 2'd1; rem_nx = t1[WIDTH-1:0]; end
        else          begin digit = 2'd0; rem_nx = rem_sh[WIDTH-1:0]; end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rem <= 0; nq <= 0; d1 <= 0; d2 <= 0; d3 <= 0; cnt <= 0;
            init <= 1'b0; busy <= 1'b0; done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                rem  <= 0;
                nq   <= {{(N2-WIDTH){1'b0}}, n};
                d1   <= {2'b00, d};
                d2   <= {1'b0, d, 1'b0};
                cnt  <= 0;
                init <= 1'b1;
                busy <= 1'b1;
            end else if (busy && init) begin
                d3   <= d1 + d2;                 // 3d = d + 2d (one adder)
                init <= 1'b0;
            end else if (busy) begin
                rem <= rem_nx;
                nq  <= {nq[N2-3:0], digit};
                cnt <= cnt + 1'b1;
                if (cnt == ND-1) begin busy <= 1'b0; done <= 1'b1; end
            end
        end
    end

    assign q = nq[WIDTH-1:0];
    assign r = rem;
endmodule
