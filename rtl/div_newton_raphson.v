module div_newton_raphson #(
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
    localparam N  = WIDTH;
    localparam XW = N + 2;          // reciprocal width
    localparam MW = 2*N + 2;        // multiplier operand width
    localparam RW = 2*N + 4;        // signed remainder width
    localparam SW = $clog2(N);

    // iterations: smallest K with 3 * 2^K >= N + 2
    function integer nr_iters(input integer w);
        integer k, bits;
        begin
            k = 1; bits = 6;
            while (bits < w + 2) begin bits = bits * 2; k = k + 1; end
            nr_iters = k;
        end
    endfunction
    localparam K  = nr_iters(N);
    localparam KW = $clog2(K + 1);

    // leading zero count (priority encoder)
    // counts the number of zeros before the first 1, starting from the MSB
    function [SW:0] lzc(input [N-1:0] v);
        integer i;
        reg found;
        begin
            lzc = 0; found = 1'b0;
            for (i = N-1; i >= 0; i = i - 1)
                if (!found) begin
                    if (v[i]) found = 1'b1;
                    else      lzc   = lzc + 1'b1;
                end
        end
    endfunction

    // States of the FSM
    localparam S_IDLE = 3'd0, S_NORM = 3'd1, S_ITA = 3'd2, S_ITB = 3'd3,
               S_QEST = 3'd4, S_REM  = 3'd5, S_CORR = 3'd6;

    reg  [2:0]      state;
    reg  [N-1:0]    n_r, d_r, dn;
    reg  [SW:0]     s;
    reg  [XW-1:0]   x;
    reg  [MW-1:0]   t;
    reg  [N+1:0]    qe;             // quotient estimate (2 spare bits)
    reg  [RW-1:0]   rem;            // signed remainder
    reg  [KW-1:0]   it;

    // shared multiplier with operand mux
    reg  [MW-1:0]   ma, mb;
    wire [2*MW-1:0] mp;   // multiplier product
    mult_comb #(.WA(MW), .WB(MW)) u_mul (.a(ma), .b(mb), .p(mp));

    // choose multiplier operands based on the FSM state
    always @(*) begin
        case (state)
            S_ITA:   begin ma = dn;  mb = x;   end   // D * X
            S_ITB:   begin ma = x;   mb = t;   end   // X * (2 - D*X)
            S_QEST:  begin ma = n_r; mb = x;   end   // n * X
            default: begin ma = qe;  mb = d_r; end   // q * d
        endcase
    end

    // normalisation and initial guess (combinational) 
    wire [SW:0]   s_w  = lzc(d_r);
    wire [N-1:0]  dn_w = d_r << s_w; // normalised divisor
    // initial guess: X0 = 3 - 2D
    wire [XW-1:0] x0_w = ({2'b11, {N{1'b0}}}) - {1'b0, dn_w, 1'b0}; 

    wire [RW-1:0] dx   = {{(RW-N){1'b0}}, d_r};
    wire [MW:0]   TWO  = {1'b1, {(2*N+1){1'b0}}};                   // 2.0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; busy <= 1'b0; done <= 1'b0;
            n_r <= 0; d_r <= 0; dn <= 0; s <= 0; x <= 0; t <= 0;
            qe <= 0; rem <= 0; it <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: if (start) begin
                    n_r  <= n;  d_r <= d;  busy <= 1'b1;
                    if (d == 0) begin                 // divide by zero
                        qe   <= {(N+2){1'b1}};
                        rem  <= {{(RW-N){1'b0}}, n};
                        busy <= 1'b0;  done <= 1'b1;
                    end else
                        state <= S_NORM;
                end
                S_NORM: begin
                    s <= s_w;  dn <= dn_w;  x <= x0_w;  it <= 0;
                    state <= S_ITA;
                end
                // Need 2 states to compute the next iteration of Newton-Raphson
                // (2 multiplications are involved, and we only have one multiplier)
                S_ITA: begin                           // t = 2 - D*X
                    t     <= TWO - mp[MW:0];
                    state <= S_ITB;
                end
                S_ITB: begin                           // X = X * t
                    x     <= mp[2*N +: XW];
                    it    <= it + 1'b1;
                    state <= (it == K-1) ? S_QEST : S_ITA;
                end
                S_QEST: begin       // Estimate the quotient: q = (n*X) >> (2N - s)
                    qe    <= mp >> (2*N - s);
                    state <= S_REM;
                end
                S_REM: begin       // Estimate the remainder: r = n - q*d
                    rem   <= {{(RW-N){1'b0}}, n_r} - mp[RW-1:0];
                    state <= S_CORR;
                end
                S_CORR: begin                          // fix small errors
                    if (rem[RW-1]) begin               // r < 0
                        qe <= qe - 1'b1;  rem <= rem + dx;
                    end else if (rem >= dx) begin      // r >= d
                        qe <= qe + 1'b1;  rem <= rem - dx;
                    end else begin
                        busy  <= 1'b0;  done <= 1'b1;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign q = qe[N-1:0];
    assign r = rem[N-1:0];
endmodule
