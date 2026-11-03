// =============================================================================
//  phys_lfsr.v  --  Random number generator
// -----------------------------------------------------------------------------
//  OWNER: PERSON 2  (Physics Engine)
//
//  A 32-bit Galois linear-feedback shift register. Every clock it produces a
//  new pseudo-random 32-bit value. The physics uses it everywhere:
//  which way a grain slides, whether a reaction fires this step, the
//  speckle shade of a new grain...
//
//  Different SEEDs make the three screens behave independently.
// =============================================================================
`default_nettype none

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

`default_nettype wire
