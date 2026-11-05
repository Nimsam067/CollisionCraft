// 32 bit LFSR random number generator. Gives a new pseudo random value every
// clock. Each screen uses a different SEED so they don't behave the same.

// Owner: Aadi (Physics Engine)

module phys_lfsr #(
    parameter [31:0] SEED = 32'hACE1_2468
)(
    input  wire        clk,
    output reg  [31:0] rnd = SEED
);

    // taps for x^32 + x^22 + x^2 + x + 1 (maximal length)
    always @(posedge clk)
        rnd <= (rnd >> 1) ^ (rnd[0] ? 32'h8020_0003 : 32'h0);

endmodule
